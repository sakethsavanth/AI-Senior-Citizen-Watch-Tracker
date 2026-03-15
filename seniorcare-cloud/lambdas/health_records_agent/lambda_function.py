"""
ElderHarmony – HealthRecords Agent (Medical Intelligence)
==========================================================
Passive monitor: med interaction warnings, lab result summaries,
doctor visit prep. Syncs with pharmacy/doctor portals (mock).
Family view: vitals/doctors/meds centralized.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Dict, Any

from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv()

from models.health_payload import HealthPayload

logger = logging.getLogger()
logger.setLevel(logging.INFO)


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    HealthRecords: passive sync. In production: pharmacy/doctor API.
    Returns med interaction warnings, lab summary, visit prep.
    """
    logger.info("📋 HealthRecords Agent invoked.")

    try:
        health = HealthPayload.from_event(event)
        logger.info("HealthRecords received: %s", health.user_id)
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Mock: med interaction check, lab summary, next visit ─
    med_interactions = _mock_med_interactions(health)
    lab_summary = _mock_lab_summary(health)
    visit_prep = _mock_visit_prep(health)

    result = {
        "agent": "health_records_agent",
        "user_id": health.user_id,
        "medication_interaction_warnings": med_interactions,
        "lab_summary": lab_summary,
        "visit_prep": visit_prep,
        "family_view": {
            "vitals_24h": {"heart_rate": health.heart_rate_24h, "spo2": health.spo2_24h, "hrv_percent": health.hrv_percent},
            "medication": health.medication_name,
            "pill_count": health.pill_count,
            "next_checkup": "Mar 20 (stub – use calendar API)",
        },
    }
    logger.info("📋 HealthRecords complete.")
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


def _mock_med_interactions(health: HealthPayload) -> list:
    """Stub: in production call pharmacy/doctor API."""
    return []  # e.g. ["New prescription may conflict with Lipitor"]


def _mock_lab_summary(health: HealthPayload) -> dict:
    """Stub: e.g. A1C improved to 6.2."""
    return {"last_updated": "stub", "summary": "No new lab results. A1C within range (stub)."}


def _mock_visit_prep(health: HealthPayload) -> list:
    """Stub: bring BP log, med list."""
    return [
        "Bring your blood pressure log.",
        "Bring current medication list.",
        "List any symptoms since last visit.",
    ]
