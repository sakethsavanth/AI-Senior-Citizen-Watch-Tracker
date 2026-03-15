"""
ElderHarmony – Medicine Agent (Daily Precision)
================================================
Schedule: 8AM, 12PM, 6PM, 9PM (customizable). Voice reminder + confirmation
(taken yes/no → DynamoDB in production). No answer 3min → SMS family. 
3-day miss pattern → auto-refill via Pharmacy API.
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
from services.pharmacy_api import PharmacyAPI

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = BedrockClient()
pharmacy = PharmacyAPI()

# ElderHarmony schedule: 8, 12, 18, 21 (UTC)
MEDICATION_SCHEDULE = {
    "morning":   {"hour_start": 8,  "hour_end": 10, "label": "Morning medication (8AM)"},
    "noon":      {"hour_start": 12, "hour_end": 14, "label": "Noon medication (12PM)"},
    "evening":   {"hour_start": 18, "hour_end": 20, "label": "Evening medication (6PM)"},
    "night":     {"hour_start": 21, "hour_end": 23, "label": "Night medication (9PM)"},
}

DEFAULT_REFILL_QTY = int(os.getenv("DEFAULT_REFILL_QTY", "30"))


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Medicine Agent: adherence, reminder message, refill on low pills or 3-day miss.
    """
    logger.info("💊 Medicine Agent invoked.")

    try:
        health = HealthPayload.from_event(event)
        logger.info("Medicine Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    med_report = HealthAnalyzer.assess_medication(health)
    current_window = _get_current_window()

    # ── Bedrock adherence ──────────────────────
    try:
        ai_analysis = bedrock.analyze_medication({
            **health.to_dict(),
            "current_medication_window": current_window,
            "medication_schedule": list(MEDICATION_SCHEDULE.keys()),
        })
    except Exception as exc:
        logger.warning("Bedrock medication analysis failed: %s", exc)
        ai_analysis = {
            "adherence_status": "at_risk" if health.pill_count < 3 else "on_track",
            "next_reminder": current_window.get("label", "Next dose") if current_window else "Next scheduled",
            "recommendations": ["Take medication as prescribed."],
        }

    # ── Voice reminder text (e.g. "Mr. Patel, time for Lipitor + water") ─
    reminder = _build_reminder(health, current_window, ai_analysis)

    # ── Refill: low pills or 3-day miss ────────
    refill_result = None
    if health.is_pill_low or health.needs_refill_3day_miss:
        refill_result = pharmacy.request_refill(
            user_id=health.user_id,
            medication=health.medication_name or "Blood Pressure",
            quantity=DEFAULT_REFILL_QTY,
        )
        logger.info("Refill requested: %s", refill_result.get("order_id", "N/A"))

    # ── Family update string: "Dad: 27/28 doses this week (96%)" (stub) ─
    doses_this_week = (health.medication_taken_today or {})
    taken_count = sum(1 for v in doses_this_week.values() if v) if isinstance(doses_this_week, dict) else 0
    total_slots = len(MEDICATION_SCHEDULE) * 7  # 4 slots × 7 days
    family_update = f"Adherence: {taken_count}/{total_slots} doses this week (stub – use DynamoDB for real count)."

    result = {
        "agent": "medicine_agent",
        "user_id": health.user_id,
        "pill_count": health.pill_count,
        "medication_name": health.medication_name,
        "current_window": current_window,
        "deterministic_report": med_report,
        "ai_analysis": ai_analysis,
        "reminder": reminder,
        "refill_requested": refill_result is not None,
        "refill_result": refill_result,
        "family_update": family_update,
        "doses_missed_consecutive_days": health.doses_missed_consecutive_days,
    }
    logger.info("💊 Medicine Agent complete.")
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


def _get_current_window() -> Dict[str, Any] | None:
    now = datetime.now(timezone.utc)
    h = now.hour
    for name, w in MEDICATION_SCHEDULE.items():
        if w["hour_start"] <= h < w["hour_end"]:
            return {"window": name, "label": w["label"], "hour_start": w["hour_start"], "hour_end": w["hour_end"]}
    return None


def _build_reminder(
    health: HealthPayload,
    window: Dict[str, Any] | None,
    ai_analysis: Dict[str, Any],
) -> Dict[str, str]:
    if window:
        message = (
            f"Time for your {window['label']}. "
            f"Please take your {health.medication_name} medication with water. "
            f"You have {health.pill_count} pills remaining. Taken? Yes or No."
        )
        urgency = "active"
    else:
        message = (
            f"Next dose at scheduled time. "
            f"You have {health.pill_count} pills remaining."
        )
        urgency = "informational"
    if health.is_pill_low or health.needs_refill_3day_miss:
        message += " Your supply is low – a refill has been requested."
        urgency = "high"
    return {"message": message, "urgency": urgency, "medication": health.medication_name or "Unknown"}
