"""
ElderHarmony – Synthetic DB and Whoop Adapter Tests
=====================================================
Validates SyntheticHealthDB and Whoop adapter; ensures all scenario
payloads parse correctly with HealthPayload.
"""

from __future__ import annotations

import json
import os
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from data.synthetic_db import SyntheticHealthDB, whoop_recovery_to_health_data
from data.whoop_adapter import build_health_payload_from_whoop
from models.health_payload import HealthPayload


def test_list_scenarios_and_personas():
    db = SyntheticHealthDB()
    scenarios = db.list_scenarios()
    assert "normal_day" in scenarios
    assert "critical_alert" in scenarios
    assert "fall_detected" in scenarios
    personas = db.list_personas()
    assert len(personas) >= 1
    assert any(p["user_id"] == "senior_001" for p in personas)


def test_get_payload_single_day():
    db = SyntheticHealthDB()
    payload = db.get_payload("senior_001", "normal_day", include_persona=True)
    assert payload["user_id"] == "senior_001"
    assert "heart_rate" in payload
    assert payload["heart_rate"] == 72
    assert payload.get("medication_name") or payload.get("emergency_contact") or payload.get("family_contacts")


def test_get_payload_critical_alert():
    db = SyntheticHealthDB()
    payload = db.get_payload("senior_001", "critical_alert", include_persona=True)
    assert payload["spo2"] == 87
    assert payload["heart_rate"] == 128
    assert payload["last_movement_minutes"] == 380
    assert payload["doses_missed_consecutive_days"] == 2


def test_health_payload_from_synthetic():
    db = SyntheticHealthDB()
    for scenario_id in ["normal_day", "critical_alert", "fall_detected", "low_mood", "refill_needed"]:
        payload = db.get_payload_for_api_event("senior_001", scenario_id)
        event = {"body": json.dumps(payload)}
        health = HealthPayload.from_event(event)
        assert health.user_id == "senior_001"
        assert health.heart_rate >= 0
        assert health.sleep_hours >= 0
        assert health.pill_count >= 0


def test_declining_week():
    db = SyntheticHealthDB()
    week = db.get_week_payloads("senior_001", "declining_week")
    assert len(week) == 7
    # First day better than last
    assert week[0]["hrv_percent"] > week[-1]["hrv_percent"]
    assert week[0]["sleep_hours"] > week[-1]["sleep_hours"]


def test_whoop_adapter():
    payload = build_health_payload_from_whoop(
        user_id="senior_001",
        recovery={"score": {"recovery_score": 55, "resting_heart_rate": 68, "spo2_percentage": 96}},
        sleep={"score": {"total_sleep_time_seconds": 25200}},
        cycle={"average_heart_rate": 72},
        steps=2800,
        last_movement_minutes=90,
        pill_count=8,
    )
    assert payload["user_id"] == "senior_001"
    assert payload["hrv_percent"] == 55
    assert payload["heart_rate"] == 68
    assert payload["spo2"] == 96
    assert payload["sleep_hours"] == 7.0
    assert payload["steps"] == 2800
    health = HealthPayload.from_event({"body": json.dumps(payload)})
    assert health.hrv_percent == 55


def test_whoop_recovery_to_health_data():
    payload = whoop_recovery_to_health_data(
        "senior_001",
        {"score": {"recovery_score": 70, "resting_heart_rate": 65, "spo2_percentage": 98}},
        sleep_hours=7.2,
        steps=3500,
        last_movement_minutes=20,
    )
    assert payload["hrv_percent"] == 70
    assert payload["sleep_hours"] == 7.2
    assert payload["steps"] == 3500


if __name__ == "__main__":
    test_list_scenarios_and_personas()
    test_get_payload_single_day()
    test_get_payload_critical_alert()
    test_health_payload_from_synthetic()
    test_declining_week()
    test_whoop_adapter()
    test_whoop_recovery_to_health_data()
    print("All synthetic DB and Whoop adapter tests passed.")
