"""
ElderHarmony – Railtracks Local Test Script
=============================================
Mirrors the 7 scenarios from tests/test_local.py but invokes through
the Railtracks agent flow instead of separate Lambda functions.

Usage
-----
    cd seniorcare-cloud
    pip install -r requirements.txt
    python tests/test_railtracks_local.py
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

# ── Scenarios (same as test_local.py) ──────────────────────────
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
        "name": "4. Low pills + 3-day miss -> refill",
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
        "name": "6. EmoCare low mood -> trigger call",
        "data": {
            "user_id": "senior_006",
            "heart_rate": 72,
            "spo2": 96,
            "steps": 2000,
            "sleep_hours": 6.0,
            "pill_count": 12,
            "last_movement_minutes": 60,
            "mood_score": 2.0,
            "family_contacts": [
                {"name": "Sarah", "phone": "+1987654321", "last_contact_iso": "2026-03-10T10:00:00Z"},
            ],
        },
    },
    {
        "name": "7. FALL DETECTED -> emergency",
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


def make_api_gateway_event(payload: dict) -> dict:
    """Wrap payload in an API Gateway proxy event structure."""
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


def run_railtracks_test(scenario: dict) -> None:
    """Run a single scenario through the orchestrator engine."""
    print(f"\n{DIVIDER}\n  SCENARIO: {scenario['name']}\n{DIVIDER}")
    print(f"  Input: {json.dumps(scenario['data'], indent=2)}\n")

    from railtracks_agents.lambda_handler import lambda_handler

    event = make_api_gateway_event(scenario["data"])
    try:
        response = lambda_handler(event, None)
        status = response.get("statusCode", "?")
        body = json.loads(response.get("body", "{}"))

        print(f"  Status: {status}")

        if status == 200:
            risk = body.get("overall_risk", "N/A")
            agents = body.get("agents_invoked", [])
            summary = body.get("summary", "")

            print(f"  Overall Risk: {risk}")
            if agents:
                print("  Agents invoked:")
                for agent in agents:
                    name = agent if isinstance(agent, str) else agent.get("name", str(agent))
                    print(f"     -> {name}")

            # Show agent result highlights
            for agent_name, agent_data in body.get("agent_results", {}).items():
                if isinstance(agent_data, dict):
                    highlights = []
                    if agent_data.get("severity"):
                        highlights.append(f"severity={agent_data['severity']}")
                    if agent_data.get("action_taken"):
                        highlights.append(f"action={agent_data['action_taken']}")
                    if agent_data.get("refill_requested"):
                        highlights.append("refill_requested")
                    if agent_data.get("trigger_call"):
                        highlights.append("trigger_call")
                    if highlights:
                        print(f"     [{agent_name}] {', '.join(highlights)}")

            if summary:
                print(f"\n  Summary: {summary[:300]}...")
        else:
            print(f"  Error: {body.get('error', 'Unknown')}")

    except Exception as exc:
        print(f"  Error: {exc}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    print("\n+--------------------------------------------------------------+")
    print("|         ElderHarmony – Railtracks Local Integration Test      |")
    print("|         Orchestrator + 9 Sub-Agents (agents-as-tools)        |")
    print("+--------------------------------------------------------------+")

    for scenario in SCENARIOS:
        run_railtracks_test(scenario)

    print(f"\n{DIVIDER}\n  All Railtracks local tests completed.\n{DIVIDER}")
