"""
ElderHarmony – Local Test Script
=================================
Runs orchestration + 5 agents locally (VitalSync, Medicine, EmoCare, Calling, HealthRecords).
Vitals = 24hr period.

Usage
-----
    cd seniorcare-cloud
    pip install -r requirements.txt
    python tests/test_local.py
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

DIVIDER = "=" * 70


def make_api_gateway_event(payload: dict) -> dict:
    return {
        "resource": "/health-data",
        "path": "/health-data",
        "httpMethod": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
        "requestContext": {"stage": "test", "requestId": "local-test", "requestTime": datetime.now(timezone.utc).isoformat()},
        "isBase64Encoded": False,
    }


# ── Scenarios: 24hr vitals, HRV, mood, fall ───────────────────
SCENARIOS = [
    {
        "name": "1. Normal / Healthy (24hr vitals)",
        "data": {
            "user_id": "senior_001",
            "heart_rate": 72,
            "spo2": 97,
            "steps": 6500,
            "sleep_hours": 7.5,
            "pill_count": 15,
            "last_movement_minutes": 30,
            "hrv_percent": 68,
            "mood_score": 4.0,
        },
    },
    {
        "name": "2. Sleep deficit + low HRV",
        "data": {
            "user_id": "senior_002",
            "heart_rate": 68,
            "spo2": 95,
            "steps": 3200,
            "sleep_hours": 4.0,
            "pill_count": 10,
            "last_movement_minutes": 60,
            "hrv_percent": 35,
            "mood_score": 3.5,
        },
    },
    {
        "name": "3. Inactivity (5h no movement)",
        "data": {
            "user_id": "senior_003",
            "heart_rate": 75,
            "spo2": 96,
            "steps": 800,
            "sleep_hours": 6.5,
            "pill_count": 8,
            "last_movement_minutes": 300,
            "hrv_percent": 55,
        },
    },
    {
        "name": "4. Low pills + 3-day miss → refill",
        "data": {
            "user_id": "senior_004",
            "heart_rate": 70,
            "spo2": 97,
            "steps": 5000,
            "sleep_hours": 7.0,
            "pill_count": 2,
            "last_movement_minutes": 45,
            "medication_name": "Blood Pressure",
            "doses_missed_consecutive_days": 3,
        },
    },
    {
        "name": "5. Critical vitals (24h) + Calling",
        "data": {
            "user_id": "senior_005",
            "heart_rate": 135,
            "spo2": 88,
            "steps": 1200,
            "sleep_hours": 5.5,
            "pill_count": 6,
            "last_movement_minutes": 90,
            "emergency_contact": "+1234567890",
        },
    },
    {
        "name": "6. EmoCare low mood → trigger call",
        "data": {
            "user_id": "senior_006",
            "heart_rate": 72,
            "spo2": 96,
            "steps": 2000,
            "sleep_hours": 6.0,
            "pill_count": 12,
            "last_movement_minutes": 60,
            "mood_score": 2.0,
            "family_contacts": [{"name": "Sarah", "phone": "+1987654321", "last_contact_iso": "2026-03-10T10:00:00Z"}],
        },
    },
    {
        "name": "7. FALL DETECTED → emergency",
        "data": {
            "user_id": "senior_007",
            "heart_rate": 85,
            "spo2": 95,
            "steps": 100,
            "sleep_hours": 6.0,
            "pill_count": 8,
            "last_movement_minutes": 15,
            "fall_detected": True,
            "emergency_contact": "+1234567890",
        },
    },
]


def run_orchestrator_test(scenario: dict) -> None:
    print(f"\n{DIVIDER}\n  SCENARIO: {scenario['name']}\n{DIVIDER}")
    print(f"  Input: {json.dumps(scenario['data'], indent=2)}\n")

    from lambdas.orchestrator.lambda_function import lambda_handler

    event = make_api_gateway_event(scenario["data"])
    try:
        response = lambda_handler(event, None)
        status = response.get("statusCode", "?")
        body = json.loads(response.get("body", "{}"))
        print(f"  ✅ Status: {status}")
        print(f"  Risk (deterministic): {body.get('deterministic_report', {}).get('overall_risk', 'N/A')}")
        print(f"  Risk (AI): {body.get('ai_analysis', {}).get('risk_level', 'N/A')}")
        print("  Agents invoked:")
        for agent in body.get("agents_invoked", []):
            print(f"     → {agent['agent_name']}: {agent['reason'][:60]}...")
    except Exception as exc:
        print(f"  ❌ Error: {exc}")
        import traceback
        traceback.print_exc()


def run_individual_agent_tests() -> None:
    print(f"\n{'#' * 70}\n  INDIVIDUAL AGENT TESTS (ElderHarmony 5)\n{'#' * 70}")

    # VitalSync
    from lambdas.vital_sync_agent.lambda_function import lambda_handler as vital_handler
    print(f"\n{DIVIDER}\n  VitalSync Agent (24hr vitals, HRV)\n{DIVIDER}")
    data = {**SCENARIOS[0]["data"], "hrv_percent": 68}
    result = vital_handler(data, None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Daily message: {body.get('daily_message', 'N/A')[:80]}...")
    print(f"  Severity: {body.get('severity', 'N/A')}")

    # Medicine
    from lambdas.medicine_agent.lambda_function import lambda_handler as med_handler
    print(f"\n{DIVIDER}\n  Medicine Agent (schedule 8/12/18/21)\n{DIVIDER}")
    result = med_handler(SCENARIOS[3]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Reminder: {body.get('reminder', {}).get('message', 'N/A')[:80]}...")
    print(f"  Refill requested: {body.get('refill_requested', 'N/A')}")

    # EmoCare
    from lambdas.emo_care_agent.lambda_function import lambda_handler as emo_handler
    print(f"\n{DIVIDER}\n  EmoCare Agent (mood 2/5)\n{DIVIDER}")
    result = emo_handler(SCENARIOS[5]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Trigger call: {body.get('trigger_call', 'N/A')}")
    print(f"  Insight: {body.get('insight', 'N/A')[:60]}...")

    # Calling (with family rotation)
    from lambdas.calling_agent.lambda_function import lambda_handler as call_handler
    print(f"\n{DIVIDER}\n  Calling Agent (risk=high)\n{DIVIDER}")
    event_with_risk = {**SCENARIOS[4]["data"], "risk_level": "high", "recommended_action": "call"}
    result = call_handler(event_with_risk, None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Action: {body.get('action_taken', 'N/A')}")

    # HealthRecords
    from lambdas.health_records_agent.lambda_function import lambda_handler as records_handler
    print(f"\n{DIVIDER}\n  HealthRecords Agent\n{DIVIDER}")
    result = records_handler(SCENARIOS[0]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Family view: {list(body.get('family_view', {}).keys())}")


if __name__ == "__main__":
    print("\n╔══════════════════════════════════════════════════════════════════╗")
    print("║           ElderHarmony – Local Integration Test                 ║")
    print("║           Orchestrator + VitalSync, Medicine, EmoCare,            ║")
    print("║           Calling, HealthRecords (24hr vitals)                   ║")
    print("╚══════════════════════════════════════════════════════════════════╝")

    print(f"\n{'#' * 70}\n  ORCHESTRATOR END-TO-END\n{'#' * 70}")
    for scenario in SCENARIOS:
        run_orchestrator_test(scenario)

    run_individual_agent_tests()
    print(f"\n{DIVIDER}\n  ✅ All local tests completed.\n{DIVIDER}")
