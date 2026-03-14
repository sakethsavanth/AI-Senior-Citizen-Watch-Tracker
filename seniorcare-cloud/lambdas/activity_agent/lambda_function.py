"""
SeniorCare AI – Activity Agent Lambda
=======================================
Monitors physical activity and detects prolonged inactivity in seniors.
Triggers alerts when no movement is detected for dangerous periods,
which may indicate a fall or medical emergency.

Trigger : Invoked asynchronously by the Orchestrator Lambda.
Runtime : Python 3.11
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
from services.bedrock_client import BedrockClient
from services.health_analyzer import HealthAnalyzer

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = BedrockClient()


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Activity Agent entry point.

    Responsibilities
    ----------------
    - Analyse step count and movement patterns
    - Detect dangerous inactivity (> 4 hours)
    - Assess fall risk based on mobility profile
    - Generate AI-powered activity recommendations

    Parameters
    ----------
    event : dict – Health payload forwarded by the Orchestrator.
    """
    logger.info("🏃 Activity Agent invoked.")

    # ── Parse payload ──────────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Activity Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Deterministic activity assessment ──────
    activity_report = HealthAnalyzer.assess_activity(health)
    logger.info("Activity status: %s (idle=%d min)", activity_report["status"], health.last_movement_minutes)

    # ── Bedrock AI activity analysis ───────────
    try:
        ai_analysis = bedrock.analyze_activity(health.to_dict())
        logger.info("Bedrock activity analysis: %s", ai_analysis)
    except Exception as exc:
        logger.warning("Bedrock activity analysis failed: %s", exc)
        ai_analysis = {
            "mobility_status": activity_report["status"],
            "fall_risk": "high" if activity_report["status"] == "critical" else "low",
            "recommendations": ["Continue monitoring movement patterns."],
        }

    # ── Determine alert severity ───────────────
    severity = _determine_severity(health, activity_report, ai_analysis)

    # ── Build recommendations ──────────────────
    recommendations = _build_recommendations(health, activity_report, ai_analysis)

    # ── Compose result ─────────────────────────
    result = {
        "agent": "activity_agent",
        "user_id": health.user_id,
        "steps": health.steps,
        "last_movement_minutes": health.last_movement_minutes,
        "deterministic_report": activity_report,
        "ai_analysis": ai_analysis,
        "severity": severity,
        "recommendations": recommendations,
        "alert_family": severity in ("critical", "high"),
        "trigger_call": severity == "critical",
    }

    logger.info("🏃 Activity Agent complete. Severity=%s", severity)
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


# ==============================================================
#  HELPERS
# ==============================================================
def _determine_severity(
    health: HealthPayload,
    report: Dict[str, Any],
    ai: Dict[str, Any],
) -> str:
    """Map activity data to alert severity."""
    if health.last_movement_minutes > 360:
        return "critical"  # 6+ hours – possible fall / emergency
    if health.last_movement_minutes > 240:
        return "high"      # 4+ hours
    if health.steps < 500:
        return "medium"    # Very low daily steps
    return "low"


def _build_recommendations(
    health: HealthPayload,
    report: Dict[str, Any],
    ai: Dict[str, Any],
) -> list:
    """Merge rule-based and AI recommendations."""
    recs = []

    if health.last_movement_minutes > 360:
        recs.append("🚨 CRITICAL: No movement for 6+ hours. Initiating welfare check call.")
    elif health.last_movement_minutes > 240:
        recs.append("⚠️ No movement for 4+ hours. Sending alert to family dashboard.")

    if health.steps < 1000:
        recs.append("🚶 Very low step count today. Gentle exercise is recommended.")

    # AI-based
    ai_recs = ai.get("recommendations", [])
    if isinstance(ai_recs, list):
        recs.extend(ai_recs)

    return recs
