"""
SeniorCare AI – Calling Agent Lambda
======================================
Handles voice/video intervention when Bedrock AI determines
the senior is at risk.  Uses Twilio to place welfare-check calls
to the senior and send SMS alerts to their family.

Trigger : Invoked asynchronously by the Orchestrator Lambda
          when risk_level is "high" or recommended_action is "call".
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
from services.twilio_service import TwilioService

logger = logging.getLogger()
logger.setLevel(logging.INFO)

twilio_svc = TwilioService()

# ── Contact numbers (loaded from .env or event) ───
SENIOR_PHONE = os.getenv("SENIOR_PHONE_NUMBER", "")
FAMILY_PHONE = os.getenv("FAMILY_PHONE_NUMBER", "")


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Calling Agent entry point.

    Responsibilities
    ----------------
    - Place an outbound welfare-check voice call to the senior
    - Send SMS alert to the family contact
    - Log call results for the family dashboard
    - Support emergency escalation for critical risk

    Parameters
    ----------
    event : dict – Health payload + risk metadata from the Orchestrator.
                   May include extra keys: risk_level, recommended_action.
    """
    logger.info("📞 Calling Agent invoked.")

    # ── Parse payload ──────────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Calling Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Extract risk metadata ──────────────────
    risk_level = event.get("risk_level", "unknown")
    recommended_action = event.get("recommended_action", "call")
    logger.info("Risk level: %s | Recommended action: %s", risk_level, recommended_action)

    # ── Determine contact numbers ──────────────
    senior_number = health.emergency_contact or SENIOR_PHONE
    family_number = FAMILY_PHONE

    if not senior_number:
        logger.warning("No senior phone number available. Cannot place call.")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "agent": "calling_agent",
                "status": "skipped",
                "reason": "no_senior_phone_number",
            }),
        }

    # ── Build spoken message ───────────────────
    call_message = _build_call_message(health, risk_level)
    family_message = _build_family_alert(health, risk_level)

    # ── Execute call / SMS based on severity ───
    if risk_level == "high" or recommended_action == "call":
        # Full emergency escalation: call senior + SMS family
        logger.info("Executing EMERGENCY ESCALATION.")
        escalation_result = twilio_svc.emergency_escalation(
            senior_number=senior_number,
            family_number=family_number,
            reason=call_message,
        )
        action_taken = "emergency_escalation"
    elif recommended_action == "alert":
        # SMS alert only (no voice call)
        logger.info("Sending family ALERT only.")
        escalation_result = {
            "call": {"status": "not_needed"},
            "sms": twilio_svc.alert_family(family_message, family_number),
        }
        action_taken = "family_alert"
    else:
        # Welfare check call only
        logger.info("Placing WELFARE CHECK call.")
        escalation_result = {
            "call": twilio_svc.call_senior(senior_number, call_message),
            "sms": {"status": "not_needed"},
        }
        action_taken = "welfare_call"

    # ── Compose result ─────────────────────────
    result = {
        "agent": "calling_agent",
        "user_id": health.user_id,
        "risk_level": risk_level,
        "recommended_action": recommended_action,
        "action_taken": action_taken,
        "call_message": call_message,
        "family_message": family_message,
        "twilio_result": escalation_result,
    }

    logger.info("📞 Calling Agent complete. Action=%s", action_taken)
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


# ==============================================================
#  HELPERS: Message builders
# ==============================================================
def _build_call_message(health: HealthPayload, risk_level: str) -> str:
    """Build the spoken message for the welfare check call."""
    parts = [
        "Hello, this is SeniorCare AI conducting a wellness check."
    ]

    if health.is_heart_rate_abnormal:
        parts.append(f"We noticed your heart rate is {health.heart_rate} BPM, which is outside the normal range.")

    if health.is_spo2_low:
        parts.append(f"Your blood oxygen level is {health.spo2}%, which is below normal.")

    if health.is_inactive:
        parts.append(f"We haven't detected movement for {health.last_movement_minutes} minutes.")

    if risk_level == "high":
        parts.append("This is a priority alert. Please confirm you are okay by pressing 1.")
    else:
        parts.append("Please let us know if you need any assistance.")

    return " ".join(parts)


def _build_family_alert(health: HealthPayload, risk_level: str) -> str:
    """Build the SMS alert message for the family contact."""
    emoji = "🚨" if risk_level == "high" else "⚠️"
    lines = [
        f"{emoji} SeniorCare AI Alert for patient {health.user_id}",
        f"Risk Level: {risk_level.upper()}",
    ]

    if health.is_heart_rate_abnormal:
        lines.append(f"• Heart Rate: {health.heart_rate} BPM (abnormal)")
    if health.is_spo2_low:
        lines.append(f"• SpO2: {health.spo2}% (low)")
    if health.is_inactive:
        lines.append(f"• Inactive: {health.last_movement_minutes} min")

    lines.append("A welfare call has been placed. Please check on your loved one.")
    return "\n".join(lines)
