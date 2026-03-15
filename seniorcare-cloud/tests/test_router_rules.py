"""
ElderHarmony – Router Rules Tests
====================================
Pure deterministic assertions: given a scenario payload, verify that
HealthAnalyzer and event_router produce expected risk levels and agent routes.

No LLM calls. No network. Fast.

Usage
-----
    cd seniorcare-cloud
    python -m pytest tests/test_router_rules.py -v
    # or directly:
    python tests/test_router_rules.py
"""

from __future__ import annotations

import json
import os
import sys
import unittest
from pathlib import Path

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from models.health_payload import HealthPayload
from services.health_analyzer import HealthAnalyzer
from utils.event_router import determine_routes

SCENARIOS_DIR = Path(PROJECT_ROOT) / "data" / "synthetic" / "scenarios"

# Scenarios with expected_risk and expected_agents metadata
ANNOTATED_SCENARIOS = [
    "normal_day",
    "sleep_deficit",
    "low_mood_trigger_call",
    "critical_vitals",
    "fall_detected",
    "low_pills_refill",
]


def _load_scenario(name: str) -> dict:
    path = SCENARIOS_DIR / f"{name}.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _make_payload(scenario_data: dict, user_id: str = "test_user") -> HealthPayload:
    health = scenario_data.get("health_data", {})
    body = {**health, "user_id": health.get("user_id", user_id)}
    return HealthPayload.from_event({"body": json.dumps(body)})


class TestHealthAnalyzerRules(unittest.TestCase):
    """Test HealthAnalyzer.full_assessment() against expected risk levels."""

    def test_normal_day_is_low_risk(self):
        payload = _make_payload(_load_scenario("normal_day"))
        report = HealthAnalyzer.full_assessment(payload)
        self.assertEqual(report["overall_risk"], "low")
        self.assertEqual(report["critical_flags"], [])

    def test_sleep_deficit_is_medium_risk(self):
        scenario = _load_scenario("sleep_deficit")
        payload = _make_payload(scenario)
        report = HealthAnalyzer.full_assessment(payload)
        # Low HRV is a critical flag, sleep < 4 would be poor
        self.assertIn(report["overall_risk"], ("medium", "high"))

    def test_critical_vitals_is_high_risk(self):
        payload = _make_payload(_load_scenario("critical_vitals"))
        report = HealthAnalyzer.full_assessment(payload)
        self.assertEqual(report["overall_risk"], "high")
        self.assertTrue(len(report["critical_flags"]) >= 2)

    def test_fall_detected_is_high_risk(self):
        payload = _make_payload(_load_scenario("fall_detected"))
        report = HealthAnalyzer.full_assessment(payload)
        self.assertEqual(report["overall_risk"], "high")
        self.assertIn("fall", report["critical_flags"])

    def test_low_mood_triggers_mood_flag(self):
        payload = _make_payload(_load_scenario("low_mood_trigger_call"))
        report = HealthAnalyzer.full_assessment(payload)
        self.assertIn("mood", report["critical_flags"])

    def test_low_pills_triggers_medication_flag(self):
        payload = _make_payload(_load_scenario("low_pills_refill"))
        report = HealthAnalyzer.full_assessment(payload)
        # pill_count=2 → "low" status, doses_missed=3 → refill_3day_miss
        med_assessment = next(a for a in report["assessments"] if a["category"] == "medication")
        self.assertEqual(med_assessment["status"], "low")
        self.assertTrue(med_assessment["refill_needed"])
        self.assertTrue(med_assessment["refill_3day_miss"])


class TestEventRouterRules(unittest.TestCase):
    """Test determine_routes() for expected agent lists."""

    def _get_agent_names(self, scenario_name: str) -> list[str]:
        payload = _make_payload(_load_scenario(scenario_name))
        routes = determine_routes(payload)
        return [r.agent_name for r in routes]

    def test_normal_day_routes(self):
        agents = self._get_agent_names("normal_day")
        # VitalSync and HealthRecords always run; Medicine always runs
        self.assertIn("vital_sync_agent", agents)
        self.assertIn("medicine_agent", agents)
        self.assertIn("health_records_agent", agents)
        # No Calling on a normal day (no fall, no abnormal vitals, no low mood)
        self.assertNotIn("calling_agent", agents)

    def test_fall_triggers_calling(self):
        agents = self._get_agent_names("fall_detected")
        self.assertIn("calling_agent", agents)
        # Verify the reason mentions fall
        payload = _make_payload(_load_scenario("fall_detected"))
        routes = determine_routes(payload)
        calling_route = next(r for r in routes if r.agent_name == "calling_agent")
        self.assertIn("Fall", calling_route.reason)

    def test_low_mood_triggers_emo_care_and_calling(self):
        agents = self._get_agent_names("low_mood_trigger_call")
        self.assertIn("emo_care_agent", agents)
        self.assertIn("calling_agent", agents)

    def test_critical_vitals_triggers_calling(self):
        agents = self._get_agent_names("critical_vitals")
        self.assertIn("calling_agent", agents)

    def test_sleep_deficit_with_low_hrv_triggers_calling(self):
        agents = self._get_agent_names("sleep_deficit")
        # HRV=35 < 40 → calling should trigger
        self.assertIn("calling_agent", agents)

    def test_low_pills_refill_no_emergency(self):
        agents = self._get_agent_names("low_pills_refill")
        self.assertIn("medicine_agent", agents)
        # No emergency calling for just low pills
        self.assertNotIn("calling_agent", agents)

    def test_annotated_expected_agents(self):
        """Verify that all agents in expected_agents are present in routes."""
        for name in ANNOTATED_SCENARIOS:
            scenario = _load_scenario(name)
            expected = scenario.get("expected_agents", [])
            if not expected:
                continue
            with self.subTest(scenario=name):
                agents = self._get_agent_names(name)
                for expected_agent in expected:
                    self.assertIn(expected_agent, agents,
                                  f"{name}: expected {expected_agent} in routes, got {agents}")

    def test_annotated_expected_risk(self):
        """Verify that HealthAnalyzer risk matches scenario expected_risk."""
        for name in ANNOTATED_SCENARIOS:
            scenario = _load_scenario(name)
            expected_risk = scenario.get("expected_risk")
            if not expected_risk:
                continue
            with self.subTest(scenario=name):
                payload = _make_payload(scenario)
                report = HealthAnalyzer.full_assessment(payload)
                self.assertEqual(report["overall_risk"], expected_risk,
                                 f"{name}: expected risk={expected_risk}, got={report['overall_risk']}, flags={report['critical_flags']}")


class TestEdgeCases(unittest.TestCase):
    """Verify edge case routing behavior."""

    def test_no_mood_score_skips_emo_care(self):
        """When mood_score is None, EmoCare agent should NOT be routed."""
        body = {
            "user_id": "test_no_mood", "heart_rate": 72, "spo2": 97,
            "steps": 5000, "sleep_hours": 7, "pill_count": 10,
            "last_movement_minutes": 30,
        }
        payload = HealthPayload.from_event({"body": json.dumps(body)})
        routes = determine_routes(payload)
        agents = [r.agent_name for r in routes]
        self.assertNotIn("emo_care_agent", agents)

    def test_mood_present_triggers_emo_care(self):
        """When mood_score is present (even good mood), EmoCare runs."""
        body = {
            "user_id": "test_good_mood", "heart_rate": 72, "spo2": 97,
            "steps": 5000, "sleep_hours": 7, "pill_count": 10,
            "last_movement_minutes": 30, "mood_score": 4.5,
        }
        payload = HealthPayload.from_event({"body": json.dumps(body)})
        routes = determine_routes(payload)
        agents = [r.agent_name for r in routes]
        self.assertIn("emo_care_agent", agents)
        # But calling should NOT be invoked for good mood
        self.assertNotIn("calling_agent", agents)

    def test_boundary_hrv_40_is_normal(self):
        """HRV exactly at 40% should be normal (not below threshold)."""
        body = {
            "user_id": "test_hrv_40", "heart_rate": 72, "spo2": 97,
            "steps": 5000, "sleep_hours": 7, "pill_count": 10,
            "last_movement_minutes": 30, "hrv_percent": 40,
        }
        payload = HealthPayload.from_event({"body": json.dumps(body)})
        self.assertFalse(payload.is_hrv_low)
        routes = determine_routes(payload)
        agents = [r.agent_name for r in routes]
        self.assertNotIn("calling_agent", agents)


if __name__ == "__main__":
    print(f"\n{'=' * 60}")
    print("  ElderHarmony – Router Rules Tests (deterministic)")
    print(f"{'=' * 60}\n")
    unittest.main(verbosity=2)
