"""
ElderHarmony – Scenario Contract Tests
========================================
Validates every JSON file under data/synthetic/scenarios/ against
HealthPayload requirements: required fields, field types, and value ranges.

Usage
-----
    cd seniorcare-cloud
    python -m pytest tests/test_scenario_contracts.py -v
    # or directly:
    python tests/test_scenario_contracts.py
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

SCENARIOS_DIR = Path(PROJECT_ROOT) / "data" / "synthetic" / "scenarios"

# Required fields that every scenario's health_data must include
REQUIRED_FIELDS = [
    "heart_rate", "spo2", "steps", "sleep_hours",
    "pill_count", "last_movement_minutes",
]


def _load_all_scenarios():
    """Load all .json files from the scenarios directory."""
    if not SCENARIOS_DIR.exists():
        return []
    scenarios = []
    for path in sorted(SCENARIOS_DIR.glob("*.json")):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        scenarios.append((path.stem, data, path))
    return scenarios


class TestScenarioContracts(unittest.TestCase):
    """Validate all scenario JSON files against the HealthPayload contract."""

    scenarios = _load_all_scenarios()

    def test_scenarios_exist(self):
        """At least one scenario file should exist."""
        self.assertGreater(len(self.scenarios), 0, "No scenario files found in scenarios/")

    def test_all_scenarios_have_health_data(self):
        """Each scenario should have a health_data or days key."""
        for name, data, path in self.scenarios:
            with self.subTest(scenario=name):
                has_data = "health_data" in data or "days" in data
                self.assertTrue(has_data, f"{name}: missing 'health_data' or 'days' key")

    def test_required_fields_present(self):
        """Each scenario's health_data should include all required fields."""
        for name, data, path in self.scenarios:
            health = data.get("health_data")
            if health is None:
                continue  # Multi-day scenarios use 'days'
            with self.subTest(scenario=name):
                for field in REQUIRED_FIELDS:
                    self.assertIn(field, health, f"{name}: missing required field '{field}'")

    def test_payload_parses(self):
        """Each scenario should be parseable by HealthPayload.from_event()."""
        for name, data, path in self.scenarios:
            health = data.get("health_data")
            if health is None:
                continue  # Skip multi-day for now
            with self.subTest(scenario=name):
                # Add user_id if not present (scenarios are mixed with SyntheticHealthDB)
                body = {**health, "user_id": health.get("user_id", f"test_{name}")}
                try:
                    payload = HealthPayload.from_event({"body": json.dumps(body)})
                    self.assertIsNotNone(payload.user_id)
                except Exception as exc:
                    self.fail(f"{name}: HealthPayload.from_event() failed: {exc}")

    def test_field_ranges(self):
        """Each scenario's values should be within valid clinical ranges."""
        for name, data, path in self.scenarios:
            health = data.get("health_data")
            if health is None:
                continue
            with self.subTest(scenario=name):
                body = {**health, "user_id": health.get("user_id", f"test_{name}")}
                payload = HealthPayload.from_event({"body": json.dumps(body)})
                errors = payload.validate_ranges()
                self.assertEqual(errors, [], f"{name}: range violations: {errors}")

    def test_invalid_spo2_rejected(self):
        """A payload with SpO2=200 should fail range validation."""
        body = {
            "user_id": "test_invalid",
            "heart_rate": 72, "spo2": 200, "steps": 5000,
            "sleep_hours": 7, "pill_count": 10, "last_movement_minutes": 30,
        }
        payload = HealthPayload.from_event({"body": json.dumps(body)})
        errors = payload.validate_ranges()
        self.assertTrue(any("spo2" in e for e in errors), "Expected spo2 range error")

    def test_invalid_heart_rate_rejected(self):
        """A payload with heart_rate=0 should fail range validation."""
        body = {
            "user_id": "test_invalid",
            "heart_rate": 0, "spo2": 97, "steps": 5000,
            "sleep_hours": 7, "pill_count": 10, "last_movement_minutes": 30,
        }
        payload = HealthPayload.from_event({"body": json.dumps(body)})
        errors = payload.validate_ranges()
        self.assertTrue(any("heart_rate" in e for e in errors), "Expected heart_rate range error")

    def test_missing_required_field_raises(self):
        """A payload missing user_id should raise ValueError."""
        body = {"heart_rate": 72, "spo2": 97, "steps": 5000,
                "sleep_hours": 7, "pill_count": 10, "last_movement_minutes": 30}
        with self.assertRaises(ValueError):
            HealthPayload.from_event({"body": json.dumps(body)})


if __name__ == "__main__":
    print(f"\n{'=' * 60}")
    print("  ElderHarmony – Scenario Contract Tests")
    print(f"  Scenarios dir: {SCENARIOS_DIR}")
    print(f"  Found {len(TestScenarioContracts.scenarios)} scenario files")
    print(f"{'=' * 60}\n")
    unittest.main(verbosity=2)
