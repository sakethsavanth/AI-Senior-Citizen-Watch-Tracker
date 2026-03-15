"""
ElderHarmony – Calling Agent (Social Lifeline)
===============================================
Smart rotation: family_contacts → least-contacted first. Triggers: EmoCare
low mood, 7-day no-contact (stub), vital anomaly, fall emergency.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Dict, Any, Optional

from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv()

from models.health_payload import HealthPayload
from services.twilio_service import TwilioService

logger = logging.getLogger()
logger.setLevel(logging.INFO)

twilio_svc = TwilioService()

SENIOR_PHONE = os.getenv("SENIOR_PHONE_NUMBER", "")
FAMILY_PHONE = os.getenv("FAMILY_PHONE_NUMBER", "")


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Calling Agent: welfare call to senior, SMS/call family.
    Family rotation: use family_contacts, pick least-contacted first.
    """
    logger.info("📞 Calling Agent invoked.")

    try:
        health = HealthPayload.from_event(event)
        logger.info("Calling Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    risk_level = event.get("risk_level", "unknown")
    recommended_action = event.get("recommended_action", "call")
    trigger = event.get("trigger")  # e.g. "emo_care"
    emergency_type = event.get("emergency_type")  # e.g. "fall"

    # ── Family contact: smart rotation (least-contacted first) ─
    senior_number = health.emergency_contact or SENIOR_PHONE
    family_number, family_name = _pick_family_contact(health, FAMILY_PHONE)

    if not senior_number:
        logger.warning("No senior phone number. Cannot place call.")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "agent": "calling_agent",
                "status": "skipped",
                "reason": "no_senior_phone_number",
            }),
        }

    call_message = _build_call_message(health, risk_level, trigger, emergency_type)
    family_message = _build_family_alert(health, risk_level, trigger, emergency_type, family_name)

    # ── EmoCare trigger: "Hi Sarah, your mom would love to chat!" ─
    if trigger == "emo_care":
        logger.info("EmoCare-triggered call to family: %s", family_name or "primary")
        escalation_result = {
            "call": {"status": "not_needed"},  # or place outbound to family
            "sms": twilio_svc.alert_family(
                f"Hi{f' {family_name}' if family_name else ''}, your loved one ({health.user_id}) would love to chat. Mood check suggested. 💙",
                family_number,
            ) if family_number else {"status": "skipped", "reason": "no_family_number"},
        }
        action_taken = "emo_care_family_alert"
    elif emergency_type == "fall" or risk_level == "high":
        logger.info("EMERGENCY ESCALATION.")
        escalation_result = twilio_svc.emergency_escalation(
            senior_number=senior_number,
            family_number=family_number or "",
            reason=call_message,
        )
        action_taken = "emergency_escalation"
    elif recommended_action == "alert":
        escalation_result = {
            "call": {"status": "not_needed"},
            "sms": twilio_svc.alert_family(family_message, family_number) if family_number else {"status": "skipped"},
        }
        action_taken = "family_alert"
    else:
        escalation_result = {
            "call": twilio_svc.call_senior(senior_number, call_message),
            "sms": {"status": "not_needed"},
        }
        action_taken = "welfare_call"

    result = {
        "agent": "calling_agent",
        "user_id": health.user_id,
        "risk_level": risk_level,
        "recommended_action": recommended_action,
        "trigger": trigger,
        "action_taken": action_taken,
        "call_message": call_message,
        "family_message": family_message,
        "family_contact_used": family_name or "primary",
        "twilio_result": escalation_result,
    }
    logger.info("📞 Calling Agent complete. Action=%s", action_taken)
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


def _pick_family_contact(health: HealthPayload, default_number: str) -> tuple[Optional[str], Optional[str]]:
    """Smart rotation: from family_contacts pick least-contacted first."""
    contacts = health.family_contacts
    if not contacts or not isinstance(contacts, list):
        return (default_number or None, None)

    # Expect [{name, phone, last_contact_iso}, ...]; sort by last_contact (oldest first)
    with_phone = [c for c in contacts if isinstance(c, dict) and c.get("phone")]
    if not with_phone:
        return (default_number or None, None)

    def last_contact_key(c):
        t = c.get("last_contact_iso") or ""
        return t  # oldest first when sorted ascending

    with_phone.sort(key=last_contact_key)
    chosen = with_phone[0]
    return (chosen.get("phone"), chosen.get("name"))


def _build_call_message(
    health: HealthPayload,
    risk_level: str,
    trigger: Optional[str],
    emergency_type: Optional[str],
) -> str:
    parts = ["Hello, this is ElderHarmony conducting a wellness check."]

    if emergency_type == "fall":
        parts.append("We detected a possible fall. Please confirm you are okay by pressing 1. Emergency services have been alerted.")
        return " ".join(parts)

    if health.is_heart_rate_abnormal:
        parts.append(f"Your heart rate over the last 24 hours is {health.heart_rate_24h:.0f} BPM, outside the normal range.")
    if health.is_spo2_low:
        parts.append(f"Blood oxygen over the last 24 hours is {health.spo2_24h:.0f}%, below normal.")
    if health.is_inactive:
        parts.append(f"We haven't detected movement for {health.last_movement_minutes} minutes.")

    if risk_level == "high":
        parts.append("This is a priority alert. Please confirm you are okay by pressing 1.")
    else:
        parts.append("Please let us know if you need any assistance.")
    return " ".join(parts)


def _build_family_alert(
    health: HealthPayload,
    risk_level: str,
    trigger: Optional[str],
    emergency_type: Optional[str],
    family_name: Optional[str],
) -> str:
    if emergency_type == "fall":
        return (
            f"🚨 ElderHarmony FALL ALERT for {health.user_id}. "
            "Possible fall detected. Welfare call placed. Please check on your loved one immediately."
        )
    emoji = "🚨" if risk_level == "high" else "⚠️"
    lines = [f"{emoji} ElderHarmony Alert for patient {health.user_id}", f"Risk Level: {risk_level.upper()}"]
    if health.is_heart_rate_abnormal:
        lines.append(f"• Heart Rate (24h): {health.heart_rate_24h:.0f} BPM (abnormal)")
    if health.is_spo2_low:
        lines.append(f"• SpO2 (24h): {health.spo2_24h:.0f}% (low)")
    if health.is_inactive:
        lines.append(f"• Inactive: {health.last_movement_minutes} min")
    if trigger == "emo_care":
        lines.append("• Low mood – they would love to hear from you.")
    lines.append("Please check on your loved one.")
    return "\n".join(lines)
