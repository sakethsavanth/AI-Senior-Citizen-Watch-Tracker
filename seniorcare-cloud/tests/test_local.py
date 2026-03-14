"""
SeniorCare AI – Local Test Script
====================================
Simulates incoming health data and exercises the full orchestration
pipeline locally, without deploying to AWS.

Usage
-----
    cd seniorcare-cloud
    pip install -r requirements.txt
    python tests/test_local.py

The script runs multiple scenarios:
  1. Normal / healthy data  →  expect minimal agent triggers
  2. Sleep deficit           →  triggers Sleep Agent
  3. Inactivity alert        →  triggers Activity Agent
  4. Low pill count          →  triggers Refill Agent
  5. Critical vitals         →  triggers Calling Agent
  6. Combined emergency      →  triggers multiple agents
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone

# ── Ensure project root is on the path ─────────
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

# ── Separator for readability ──────────────────
DIVIDER = "=" * 70


def make_api_gateway_event(payload: dict) -> dict:
    """Wrap a health payload in an API Gateway proxy-integration event."""
    return {
        "resource": "/health-data",
        "path": "/health-data",
        "httpMethod": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
        "requestContext": {
            "stage": "test",
            "requestId": "local-test",
            "requestTime": datetime.now(timezone.utc).isoformat(),
        },
        "isBase64Encoded": False,
    }


# ==============================================================
#  TEST SCENARIOS
# ==============================================================
SCENARIOS = [
    {
        "name": "1️⃣  Normal / Healthy",
        "data": {
            "user_id": "senior_001",
            "heart_rate": 72,
            "spo2": 97,
            "steps": 6500,
            "sleep_hours": 7.5,
            "pill_count": 15,
            "last_movement_minutes": 30,
        },
    },
    {
        "name": "2️⃣  Sleep Deficit",
        "data": {
            "user_id": "senior_002",
            "heart_rate": 68,
            "spo2": 95,
            "steps": 3200,
            "sleep_hours": 4.0,
            "pill_count": 10,
            "last_movement_minutes": 60,
        },
    },
    {
        "name": "3️⃣  Inactivity Alert (5 hours no movement)",
        "data": {
            "user_id": "senior_003",
            "heart_rate": 75,
            "spo2": 96,
            "steps": 800,
            "sleep_hours": 6.5,
            "pill_count": 8,
            "last_movement_minutes": 300,
        },
    },
    {
        "name": "4️⃣  Low Pill Count (refill needed)",
        "data": {
            "user_id": "senior_004",
            "heart_rate": 70,
            "spo2": 97,
            "steps": 5000,
            "sleep_hours": 7.0,
            "pill_count": 2,
            "last_movement_minutes": 45,
            "medication_name": "Blood Pressure",
        },
    },
    {
        "name": "5️⃣  Critical Vitals (abnormal HR + low SpO2)",
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
        "name": "6️⃣  Combined Emergency (everything bad)",
        "data": {
            "user_id": "senior_006",
            "heart_rate": 42,
            "spo2": 85,
            "steps": 100,
            "sleep_hours": 2.0,
            "pill_count": 0,
            "last_movement_minutes": 480,
            "emergency_contact": "+1234567890",
        },
    },
]


def run_orchestrator_test(scenario: dict) -> None:
    """Run a single scenario through the Orchestrator Lambda."""
    print(f"\n{DIVIDER}")
    print(f"  SCENARIO: {scenario['name']}")
    print(DIVIDER)
    print(f"  Input: {json.dumps(scenario['data'], indent=2)}")
    print()

    # Import here so env vars are loaded first
    from lambdas.orchestrator.lambda_function import lambda_handler

    event = make_api_gateway_event(scenario["data"])

    try:
        response = lambda_handler(event, None)
        status = response.get("statusCode", "?")
        body = json.loads(response.get("body", "{}"))

        print(f"  ✅ Status: {status}")
        print(f"  Risk (deterministic): {body.get('deterministic_report', {}).get('overall_risk', 'N/A')}")
        print(f"  Risk (AI):            {body.get('ai_analysis', {}).get('risk_level', 'N/A')}")
        print(f"  Agents invoked:")
        for agent in body.get("agents_invoked", []):
            print(f"     → {agent['agent_name']}: {agent['reason']}")
        print()

    except Exception as exc:
        print(f"  ❌ Error: {exc}")
        import traceback
        traceback.print_exc()


def run_individual_agent_tests() -> None:
    """Directly test each agent Lambda with sample data."""
    print(f"\n{'#' * 70}")
    print("  INDIVIDUAL AGENT TESTS")
    print(f"{'#' * 70}")

    # Sleep Agent
    from lambdas.sleep_agent.lambda_function import lambda_handler as sleep_handler
    print(f"\n{DIVIDER}\n  Sleep Agent (sleep_hours=4.0)\n{DIVIDER}")
    result = sleep_handler(SCENARIOS[1]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Quality: {body.get('deterministic_report', {}).get('quality', 'N/A')}")
    print(f"  Recs: {body.get('recommendations', [])}")

    # Activity Agent
    from lambdas.activity_agent.lambda_function import lambda_handler as activity_handler
    print(f"\n{DIVIDER}\n  Activity Agent (idle=300 min)\n{DIVIDER}")
    result = activity_handler(SCENARIOS[2]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Severity: {body.get('severity', 'N/A')}")
    print(f"  Alert Family: {body.get('alert_family', 'N/A')}")

    # Medication Agent
    from lambdas.medication_agent.lambda_function import lambda_handler as med_handler
    print(f"\n{DIVIDER}\n  Medication Agent\n{DIVIDER}")
    result = med_handler(SCENARIOS[0]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Reminder: {body.get('reminder', {}).get('message', 'N/A')}")

    # Refill Agent
    from lambdas.refill_agent.lambda_function import lambda_handler as refill_handler
    print(f"\n{DIVIDER}\n  Refill Agent (pill_count=2)\n{DIVIDER}")
    result = refill_handler(SCENARIOS[3]["data"], None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Action: {body.get('action', 'N/A')}")
    print(f"  Pharmacy: {body.get('pharmacy_response', {})}")

    # Calling Agent
    from lambdas.calling_agent.lambda_function import lambda_handler as call_handler
    print(f"\n{DIVIDER}\n  Calling Agent (critical vitals)\n{DIVIDER}")
    event_with_risk = {**SCENARIOS[4]["data"], "risk_level": "high", "recommended_action": "call"}
    result = call_handler(event_with_risk, None)
    body = json.loads(result.get("body", "{}"))
    print(f"  Action Taken: {body.get('action_taken', 'N/A')}")
    print(f"  Twilio Result: {body.get('twilio_result', {})}")


# ==============================================================
#  MAIN
# ==============================================================
if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║           SeniorCare AI – Local Integration Test               ║")
    print("║           Testing Orchestrator + All Agents                    ║")
    print("╚══════════════════════════════════════════════════════════════════╝")

    # --- Part 1: Orchestrator end-to-end ---
    print(f"\n{'#' * 70}")
    print("  ORCHESTRATOR END-TO-END TESTS")
    print(f"{'#' * 70}")

    for scenario in SCENARIOS:
        run_orchestrator_test(scenario)

    # --- Part 2: Individual agent tests ---
    run_individual_agent_tests()

    print(f"\n{DIVIDER}")
    print("  ✅ All local tests completed.")
    print(DIVIDER)
