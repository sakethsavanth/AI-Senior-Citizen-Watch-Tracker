"""
ElderHarmony – VitalSync Agent (Continuous Guardian)
=====================================================
Uses 24hr-period vitals (HR, SpO2, HRV), sleep, activity. Whoop-style
hourly/daily summary. 7AM walk reminder, 9PM sleep message. HRV < 40% →
doctor visit alert. Fall detected → emergency.
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


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    VitalSync: 24hr vitals + daily guardian. Vitals = 24hr period.
    """
    logger.info("❤️ VitalSync Agent invoked.")

    try:
        health = HealthPayload.from_event(event)
        logger.info("VitalSync received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Deterministic: vitals (24h), HRV, fall, sleep, activity ─
    vitals_report = HealthAnalyzer.assess_vitals(health)
    hrv_report = HealthAnalyzer.assess_hrv(health)
    fall_report = HealthAnalyzer.assess_fall(health)
    sleep_report = HealthAnalyzer.assess_sleep(health)
    activity_report = HealthAnalyzer.assess_activity(health)

    # ── Fall → emergency (orchestrator will also trigger Calling) ─
    if health.fall_detected:
        result = _build_result(
            health,
            vitals_report, hrv_report, fall_report, sleep_report, activity_report,
            ai_analysis={"emergency": "fall_detected", "message": "EMERGENCY – calling ambulance + family"},
            daily_message="Fall detected. Emergency protocol activated.",
            severity="critical",
        )
        logger.info("❤️ VitalSync: FALL – emergency.")
        return {"statusCode": 200, "body": json.dumps(result, default=str)}

    # ── Bedrock: 24hr vitals interpretation + daily message ─
    try:
        ai_analysis = bedrock.analyze_vitals_24h(health.to_dict())
    except Exception as exc:
        logger.warning("Bedrock vitals analysis failed: %s", exc)
        ai_analysis = {
            "vital_status": vitals_report.get("status", "normal"),
            "daily_message": _default_daily_message(health),
            "recommendations": [],
        }

    # ── Daily message by time (7AM walk, 9PM sleep) ─
    now = datetime.now(timezone.utc)
    hour = now.hour
    if 6 <= hour < 10:
        daily_message = ai_analysis.get("daily_message") or "Good morning! A 10-minute walk today can help."
    elif 20 <= hour or hour < 2:
        daily_message = ai_analysis.get("daily_message") or "HRV looks normal. Sleep well!"
    else:
        daily_message = ai_analysis.get("daily_message") or "Vitals within normal range for the last 24 hours."

    if health.is_hrv_low:
        daily_message += f" ⚠️ HRV is {health.hrv_percent}% of normal – consider a doctor visit."

    severity = "critical" if health.fall_detected else ("high" if health.is_hrv_low else "low")

    result = _build_result(
        health,
        vitals_report, hrv_report, fall_report, sleep_report, activity_report,
        ai_analysis=ai_analysis,
        daily_message=daily_message,
        severity=severity,
    )
    logger.info("❤️ VitalSync complete. Severity=%s", severity)
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


def _default_daily_message(health: HealthPayload) -> str:
    if health.is_hrv_low:
        return f"HRV below 40% ({health.hrv_percent}%). Possible infection – doctor visit?"
    if health.sleep_hours < 6:
        return "Sleep was short. Try a regular bedtime tonight."
    return "Vitals normal for 24hr period."


def _build_result(
    health: HealthPayload,
    vitals: Dict[str, Any],
    hrv: Dict[str, Any],
    fall: Dict[str, Any],
    sleep: Dict[str, Any],
    activity: Dict[str, Any],
    ai_analysis: Dict[str, Any],
    daily_message: str,
    severity: str,
) -> Dict[str, Any]:
    return {
        "agent": "vital_sync_agent",
        "user_id": health.user_id,
        "period": "24h",
        "heart_rate_24h": health.heart_rate_24h,
        "spo2_24h": health.spo2_24h,
        "hrv_percent": health.hrv_percent,
        "fall_detected": health.fall_detected,
        "deterministic": {
            "vitals": vitals,
            "hrv": hrv,
            "fall": fall,
            "sleep": sleep,
            "activity": activity,
        },
        "ai_analysis": ai_analysis,
        "daily_message": daily_message,
        "severity": severity,
        "alert_family": severity in ("critical", "high"),
    }
