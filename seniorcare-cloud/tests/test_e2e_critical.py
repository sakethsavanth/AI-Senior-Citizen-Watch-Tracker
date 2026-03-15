"""
ElderHarmony – End-to-End Critical Path Tests
================================================
Tests the full lambda_handler pipeline (validation → triage → flow → response)
for critical scenarios. Mocks the Railtracks flow to avoid LLM calls.

Usage
-----
    cd seniorcare-cloud
    python -m pytest tests/test_e2e_critical.py -v
    # or directly:
    python tests/test_e2e_critical.py
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

# Mock the railtracks SDK before importing lambda_handler (it's not installed locally)
_mock_rt = MagicMock()
sys.modules["railtracks"] = _mock_rt

import railtracks_agents.lambda_handler  # noqa: E402
from railtracks_agents.lambda_handler import lambda_handler  # noqa: E402

SCENARIOS_DIR = Path(PROJECT_ROOT) / "data" / "synthetic" / "scenarios"


def _load_scenario(name: str) -> dict:
    path = SCENARIOS_DIR / f"{name}.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _make_api_event(health_data: dict, user_id: str = "test_user") -> dict:
    body = {**health_data, "user_id": health_data.get("user_id", user_id)}
    return {
        "resource": "/health-data",
        "path": "/health-data",
        "httpMethod": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
        "requestContext": {"stage": "test"},
        "isBase64Encoded": False,
    }


def _mock_flow_result(risk="high", agents=None, summary="Test summary"):
    """Create a mock Railtracks flow result."""
    result_json = json.dumps({
        "overall_risk": risk,
        "agents_invoked": agents or [],
        "summary": summary,
    })
    mock_result = MagicMock()
    mock_result.text = result_json
    return mock_result


class TestE2ECriticalPath(unittest.TestCase):
    """End-to-end tests for critical scenarios (fall, critical vitals)."""

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_fall_detected_returns_high_risk(self, mock_flow_cls):
        """Fall scenario should return high risk and include calling_agent."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.return_value = _mock_flow_result(
            risk="high", agents=["vital_sync_agent", "calling_agent"], summary="Fall detected")
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("fall_detected")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertEqual(body["overall_risk"], "high")
        # Deterministic report should also show high risk
        self.assertEqual(body["deterministic_report"]["overall_risk"], "high")
        self.assertIn("fall", body["deterministic_report"]["critical_flags"])
        # Calling agent should be in the invoked list
        agent_names = [a["agent_name"] for a in body["agents_invoked"]]
        self.assertIn("calling_agent", agent_names)

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_critical_vitals_returns_high_risk(self, mock_flow_cls):
        """Critical vitals (HR=135, SpO2=88) should return high risk."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.return_value = _mock_flow_result(
            risk="high", agents=["vital_sync_agent", "calling_agent"], summary="Critical vitals")
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("critical_vitals")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertEqual(body["overall_risk"], "high")
        agent_names = [a["agent_name"] for a in body["agents_invoked"]]
        self.assertIn("calling_agent", agent_names)

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_normal_day_returns_low_risk(self, mock_flow_cls):
        """Normal day should return low risk, no emergency agents."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.return_value = _mock_flow_result(
            risk="low", agents=["vital_sync_agent"], summary="All normal")
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("normal_day")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertEqual(body["overall_risk"], "low")
        agent_names = [a["agent_name"] for a in body["agents_invoked"]]
        self.assertNotIn("calling_agent", agent_names)

    def test_invalid_payload_returns_400(self):
        """Missing required fields should return 400."""

        event = {
            "body": json.dumps({"user_id": "test", "heart_rate": 72}),
        }
        response = lambda_handler(event, None)
        self.assertEqual(response["statusCode"], 400)
        body = json.loads(response["body"])
        self.assertIn("error", body)

    def test_out_of_range_returns_400(self):
        """Field values out of range should return 400."""

        event = _make_api_event({
            "heart_rate": 72, "spo2": 200, "steps": 5000,
            "sleep_hours": 7, "pill_count": 10, "last_movement_minutes": 30,
        })
        response = lambda_handler(event, None)
        self.assertEqual(response["statusCode"], 400)
        body = json.loads(response["body"])
        self.assertIn("details", body)

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_flow_failure_returns_fallback(self, mock_flow_cls):
        """When the LLM flow fails, handler should return deterministic triage."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.side_effect = RuntimeError("LLM timeout")
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("fall_detected")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        # Should still return 200 with fallback data
        self.assertEqual(response["statusCode"], 200)
        body = json.loads(response["body"])
        self.assertTrue(body["ai_analysis"].get("fallback"))
        # Deterministic triage should still work
        self.assertEqual(body["deterministic_report"]["overall_risk"], "high")

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_response_structure(self, mock_flow_cls):
        """Verify the response body has all expected keys."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.return_value = _mock_flow_result()
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("normal_day")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        body = json.loads(response["body"])
        expected_keys = ["user_id", "timestamp", "period", "deterministic_report",
                         "agents_invoked", "ai_analysis", "overall_risk", "summary"]
        for key in expected_keys:
            self.assertIn(key, body, f"Response missing key: {key}")

    @patch("railtracks_agents.lambda_handler.rt.Flow")
    def test_low_mood_triggers_emo_care(self, mock_flow_cls):
        """Low mood scenario should include emo_care_agent and calling_agent."""
        mock_flow_instance = MagicMock()
        mock_flow_instance.invoke.return_value = _mock_flow_result(
            risk="medium", agents=["emo_care_agent", "calling_agent"], summary="Low mood")
        mock_flow_cls.return_value = mock_flow_instance


        scenario = _load_scenario("low_mood_trigger_call")
        event = _make_api_event(scenario["health_data"])
        response = lambda_handler(event, None)

        body = json.loads(response["body"])
        agent_names = [a["agent_name"] for a in body["agents_invoked"]]
        self.assertIn("emo_care_agent", agent_names)
        self.assertIn("calling_agent", agent_names)


if __name__ == "__main__":
    print(f"\n{'=' * 60}")
    print("  ElderHarmony – End-to-End Critical Path Tests")
    print(f"{'=' * 60}\n")
    unittest.main(verbosity=2)
