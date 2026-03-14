"""
SeniorCare AI – Refill Agent Lambda
=====================================
Monitors medication inventory and automatically requests refills
from the external Pharmacy API when the pill count drops below
the safety threshold.

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
from services.pharmacy_api import PharmacyAPI
from services.health_analyzer import HealthAnalyzer

logger = logging.getLogger()
logger.setLevel(logging.INFO)

pharmacy = PharmacyAPI()

DEFAULT_REFILL_QUANTITY = int(os.getenv("DEFAULT_REFILL_QTY", "30"))


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Refill Agent entry point.

    Responsibilities
    ----------------
    - Check current pill inventory
    - Determine if a refill is needed (pill_count < 3)
    - Call Pharmacy API to place refill order
    - Log and return order confirmation

    Parameters
    ----------
    event : dict – Health payload forwarded by the Orchestrator.
    """
    logger.info("💊📦 Refill Agent invoked.")

    # ── Parse payload ──────────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Refill Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Deterministic medication assessment ────
    med_report = HealthAnalyzer.assess_medication(health)
    logger.info("Medication inventory: %s (pills=%d)", med_report["status"], health.pill_count)

    # ── Check if refill is needed ──────────────
    if not health.is_pill_low:
        logger.info("Pill count sufficient (%d). No refill needed.", health.pill_count)
        return {
            "statusCode": 200,
            "body": json.dumps({
                "agent": "refill_agent",
                "user_id": health.user_id,
                "action": "no_refill_needed",
                "pill_count": health.pill_count,
                "message": f"Inventory adequate: {health.pill_count} pills remaining.",
            }),
        }

    # ── Request refill from Pharmacy API ───────
    logger.info("Low inventory detected (%d pills). Requesting refill...", health.pill_count)

    refill_result = pharmacy.request_refill(
        user_id=health.user_id,
        medication=health.medication_name or "Blood Pressure",
        quantity=DEFAULT_REFILL_QUANTITY,
    )

    logger.info("Pharmacy response: %s", refill_result)

    # ── Build notification for family dashboard ─
    notification = {
        "type": "refill_ordered",
        "message": (
            f"Medication refill ordered for {health.medication_name}. "
            f"Order: {refill_result.get('order_id', 'N/A')}. "
            f"Estimated delivery: {refill_result.get('estimated_delivery', 'unknown')}."
        ),
        "user_id": health.user_id,
    }

    # ── Compose result ─────────────────────────
    result = {
        "agent": "refill_agent",
        "user_id": health.user_id,
        "pill_count": health.pill_count,
        "medication": health.medication_name,
        "refill_quantity": DEFAULT_REFILL_QUANTITY,
        "pharmacy_response": refill_result,
        "notification": notification,
        "action": "refill_requested",
    }

    logger.info("💊📦 Refill Agent complete. Order=%s", refill_result.get("order_id", "N/A"))
    return {"statusCode": 200, "body": json.dumps(result, default=str)}
