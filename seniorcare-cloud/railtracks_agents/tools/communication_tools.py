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
import railtracks as rt

logger = logging.getLogger(__name__)


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
    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.call_senior(to_number, message)
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
    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.alert_family(message, family_number)
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
    from services.twilio_service import TwilioService

    svc = TwilioService()
    result = svc.emergency_escalation(
        senior_number=senior_number,
        family_number=family_number,
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
