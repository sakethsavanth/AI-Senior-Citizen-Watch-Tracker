"""
SeniorCare AI – Medication Agent Lambda
=========================================
Manages medication reminders and adherence tracking.  Analyses whether
the senior is on schedule with their medication and generates
personalised reminder messages.

Trigger : Invoked asynchronously by the Orchestrator Lambda.
Runtime : Python 3.11
"""

from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Dict, Any

from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv()

from models.health_payload import HealthPayload
from services.bedrock_client import BedrockClient
from services.health_analyzer import HealthAnalyzer

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = BedrockClient()

# ── Medication schedule (could be DynamoDB in production) ──────
MEDICATION_SCHEDULE = {
    "morning":   {"hour_start": 7,  "hour_end": 10, "label": "Morning medication"},
    "afternoon": {"hour_start": 12, "hour_end": 14, "label": "Afternoon medication"},
    "evening":   {"hour_start": 18, "hour_end": 21, "label": "Evening medication"},
}


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Medication Agent entry point.

    Responsibilities
    ----------------
    - Check if current time falls within a medication window
    - Track medication adherence patterns
    - Generate AI-powered adherence recommendations
    - Send reminders when pills are due

    Parameters
    ----------
    event : dict – Health payload forwarded by the Orchestrator.
    """
    logger.info("💊 Medication Agent invoked.")

    # ── Parse payload ──────────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Medication Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Deterministic medication assessment ────
    med_report = HealthAnalyzer.assess_medication(health)
    logger.info("Medication status: %s (pills=%d)", med_report["status"], health.pill_count)

    # ── Check medication window ────────────────
    current_window = _get_current_medication_window()

    # ── Bedrock AI adherence analysis ──────────
    try:
        ai_analysis = bedrock.analyze_medication({
            **health.to_dict(),
            "current_medication_window": current_window,
            "medication_schedule": MEDICATION_SCHEDULE,
        })
        logger.info("Bedrock medication analysis: %s", ai_analysis)
    except Exception as exc:
        logger.warning("Bedrock medication analysis failed: %s", exc)
        ai_analysis = {
            "adherence_status": "at_risk" if health.pill_count < 3 else "on_track",
            "next_reminder": current_window.get("label", "Next scheduled dose") if current_window else "No active window",
            "recommendations": ["Take medication as prescribed."],
        }

    # ── Build reminder message ─────────────────
    reminder = _build_reminder(health, current_window, ai_analysis)

    # ── Compose result ─────────────────────────
    result = {
        "agent": "medication_agent",
        "user_id": health.user_id,
        "pill_count": health.pill_count,
        "medication_name": health.medication_name,
        "current_window": current_window,
        "deterministic_report": med_report,
        "ai_analysis": ai_analysis,
        "reminder": reminder,
        "refill_needed": health.is_pill_low,
    }

    logger.info("💊 Medication Agent complete. Adherence=%s",
                ai_analysis.get("adherence_status", "unknown"))
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


# ==============================================================
#  HELPERS
# ==============================================================
def _get_current_medication_window() -> Dict[str, Any] | None:
    """Check if the current UTC hour falls within any medication window."""
    now = datetime.now(timezone.utc)
    current_hour = now.hour

    for window_name, window in MEDICATION_SCHEDULE.items():
        if window["hour_start"] <= current_hour < window["hour_end"]:
            return {
                "window": window_name,
                "label": window["label"],
                "hour_start": window["hour_start"],
                "hour_end": window["hour_end"],
                "current_hour": current_hour,
            }

    return None


def _build_reminder(
    health: HealthPayload,
    window: Dict[str, Any] | None,
    ai_analysis: Dict[str, Any],
) -> Dict[str, str]:
    """Build a personalised medication reminder message."""
    if window:
        message = (
            f"Hi! This is your {window['label']} reminder. "
            f"Please take your {health.medication_name} medication. "
            f"You have {health.pill_count} pills remaining."
        )
        urgency = "active"
    else:
        message = (
            f"No medication window is currently active. "
            f"Your next dose will be at the scheduled time. "
            f"You have {health.pill_count} pills remaining."
        )
        urgency = "informational"

    if health.is_pill_low:
        message += " ⚠️ Your supply is running low – a refill has been requested."
        urgency = "high"

    return {
        "message": message,
        "urgency": urgency,
        "medication": health.medication_name or "Unknown",
    }
