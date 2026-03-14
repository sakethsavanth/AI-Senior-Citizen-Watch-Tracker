"""
SeniorCare AI – Twilio Voice / Video Service
==============================================
Handles outbound calls and SMS alerts to seniors and their families
via the Twilio Programmable Voice API.

Usage
-----
    from services.twilio_service import TwilioService
    svc = TwilioService()
    svc.call_senior("+1234567890", "Please take your medication.")
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from dotenv import load_dotenv
from twilio.rest import Client as TwilioClient

load_dotenv()

logger = logging.getLogger(__name__)

# ── Twilio credentials (loaded from .env) ─────
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", "")
FAMILY_PHONE_NUMBER = os.getenv("FAMILY_PHONE_NUMBER", "")


class TwilioService:
    """Encapsulates all Twilio interactions for SeniorCare AI."""

    def __init__(self):
        if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]):
            logger.warning("Twilio credentials not fully configured – calls will be simulated.")
            self.client = None
        else:
            self.client = TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
            logger.info("TwilioService initialised (from=%s)", TWILIO_PHONE_NUMBER)

    # ──────────────────────────────────────────────
    # Voice call to senior
    # ──────────────────────────────────────────────
    def call_senior(self, to_number: str, message: str) -> dict:
        """
        Place an outbound voice call to the senior with a TwiML <Say> message.

        Parameters
        ----------
        to_number : str   – E.164 phone number, e.g. "+14155551234"
        message   : str   – Spoken message content.

        Returns
        -------
        dict with call_sid and status.
        """
        twiml = (
            f'<Response><Say voice="alice">{message}</Say>'
            f'<Pause length="2"/>'
            f'<Say voice="alice">If you need help, press 1 or stay on the line.</Say>'
            f'</Response>'
        )

        if self.client is None:
            logger.info("[SIMULATED CALL] to=%s message=%s", to_number, message[:80])
            return {"call_sid": "SIMULATED", "status": "simulated", "to": to_number}

        try:
            call = self.client.calls.create(
                to=to_number,
                from_=TWILIO_PHONE_NUMBER,
                twiml=twiml,
            )
            logger.info("Call placed: sid=%s to=%s", call.sid, to_number)
            return {"call_sid": call.sid, "status": call.status, "to": to_number}
        except Exception as exc:
            logger.error("Twilio call failed: %s", exc, exc_info=True)
            return {"call_sid": None, "status": "failed", "error": str(exc)}

    # ──────────────────────────────────────────────
    # SMS alert to family
    # ──────────────────────────────────────────────
    def alert_family(self, message: str, family_number: Optional[str] = None) -> dict:
        """
        Send an SMS alert to the senior's family contact.

        Parameters
        ----------
        message        : str – Alert text.
        family_number  : str – Override number; defaults to FAMILY_PHONE_NUMBER env var.
        """
        to_number = family_number or FAMILY_PHONE_NUMBER
        if not to_number:
            logger.warning("No family number configured; skipping SMS.")
            return {"status": "skipped", "reason": "no_family_number"}

        if self.client is None:
            logger.info("[SIMULATED SMS] to=%s body=%s", to_number, message[:80])
            return {"message_sid": "SIMULATED", "status": "simulated", "to": to_number}

        try:
            msg = self.client.messages.create(
                to=to_number,
                from_=TWILIO_PHONE_NUMBER,
                body=message,
            )
            logger.info("SMS sent: sid=%s to=%s", msg.sid, to_number)
            return {"message_sid": msg.sid, "status": msg.status, "to": to_number}
        except Exception as exc:
            logger.error("Twilio SMS failed: %s", exc, exc_info=True)
            return {"message_sid": None, "status": "failed", "error": str(exc)}

    # ──────────────────────────────────────────────
    # Emergency escalation (call + SMS)
    # ──────────────────────────────────────────────
    def emergency_escalation(self, senior_number: str, family_number: Optional[str] = None,
                             reason: str = "Health anomaly detected") -> dict:
        """Call the senior AND alert the family simultaneously."""
        call_result = self.call_senior(
            senior_number,
            f"Hello, this is SeniorCare AI. {reason}. Please confirm you are okay.",
        )
        sms_result = self.alert_family(
            f"🚨 SeniorCare Alert: {reason}. We have placed a welfare call. "
            f"Please check on your loved one.",
            family_number,
        )
        return {"call": call_result, "sms": sms_result}
