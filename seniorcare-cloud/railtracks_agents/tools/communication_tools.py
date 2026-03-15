"""
ElderHarmony – Communication Tool Functions
==============================================
Wraps services/twilio_service.py for voice calls, SMS alerts, and emergency
escalation. Includes smart family contact rotation logic.

To add a new communication tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import json
import logging
import os
import railtracks as rt

logger = logging.getLogger(__name__)

# Fallback phone numbers from .env when payload doesn't include them
_DEFAULT_SENIOR_NUMBER = os.getenv("SENIOR_PHONE_NUMBER", "")
_DEFAULT_FAMILY_NUMBER = os.getenv("FAMILY_PHONE_NUMBER", "")


@rt.function_node
def call_senior(to_number: str, message: str) -> dict:
    """Place an outbound voice call to the senior with a spoken message.

    Uses Twilio Programmable Voice. Falls back to simulation when
    credentials are not configured.

    Args:
        to_number: Senior's phone number in E.164 format (e.g. '+14155551234').
        message: The message to speak during the call.

    Returns:
        dict with call_sid, status, and to number.
    """
    number = to_number or _DEFAULT_SENIOR_NUMBER
    if not number:
        logger.warning("call_senior: no phone number provided and SENIOR_PHONE_NUMBER not set")
        return {"call_sid": None, "status": "skipped", "reason": "no_senior_number"}

    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.call_senior(number, message)
    logger.info("call_senior result: %s", result.get("status"))
    return result


@rt.function_node
def alert_family_sms(message: str, family_number: str) -> dict:
    """Send an SMS alert to a family member.

    Args:
        message: Alert text content.
        family_number: Family member's phone number in E.164 format.

    Returns:
        dict with message_sid, status, and to number.
    """
    number = family_number or _DEFAULT_FAMILY_NUMBER
    if not number:
        logger.warning("alert_family_sms: no family number provided and FAMILY_PHONE_NUMBER not set")
        return {"message_sid": None, "status": "skipped", "reason": "no_family_number"}

    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.alert_family(message, number)
    logger.info("alert_family_sms result: %s", result.get("status"))
    return result


@rt.function_node
def emergency_escalation(senior_number: str, family_number: str, reason: str) -> dict:
    """Trigger emergency escalation: call the senior AND SMS the family simultaneously.

    Args:
        senior_number: Senior's phone number in E.164 format.
        family_number: Family member's phone number in E.164 format.
        reason: Reason for the emergency (e.g. 'Fall detected').

    Returns:
        dict with call result and sms result.
    """
    senior = senior_number or _DEFAULT_SENIOR_NUMBER
    family = family_number or _DEFAULT_FAMILY_NUMBER
    if not senior and not family:
        logger.warning("emergency_escalation: no phone numbers available")
        return {"call": {"status": "skipped"}, "sms": {"status": "skipped"}, "reason": "no_phone_numbers"}

    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.emergency_escalation(
        senior_number=senior,
        family_number=family,
        reason=reason,
    )
    logger.info("emergency_escalation result: call=%s sms=%s",
                result.get("call", {}).get("status"),
                result.get("sms", {}).get("status"))
    return result


@rt.function_node
def pick_family_contact(family_contacts_json: str) -> dict:
    """Pick the best family contact using smart rotation (least-contacted first).

    Parses a JSON list of family contacts with last_contact timestamps and
    returns the one who was contacted least recently, enabling fair rotation.

    Args:
        family_contacts_json: JSON string of list like [{"name": "Sarah", "phone": "+1...", "last_contact_iso": "2026-03-10T10:00:00Z"}, ...].

    Returns:
        dict with chosen contact's name, phone, and last_contact_iso. Returns
        name=None if no valid contacts found.
    """
    contacts = json.loads(family_contacts_json)

    if not contacts or not isinstance(contacts, list):
        return {"name": None, "phone": None, "reason": "no valid contacts provided"}

    with_phone = [c for c in contacts if isinstance(c, dict) and c.get("phone")]
    if not with_phone:
        return {"name": None, "phone": None, "reason": "no contacts with phone numbers"}

    # Sort by last_contact_iso ascending (oldest/least-contacted first)
    with_phone.sort(key=lambda c: c.get("last_contact_iso") or "")
    chosen = with_phone[0]

    return {
        "name": chosen.get("name"),
        "phone": chosen.get("phone"),
        "last_contact_iso": chosen.get("last_contact_iso"),
        "reason": "least recently contacted",
    }
