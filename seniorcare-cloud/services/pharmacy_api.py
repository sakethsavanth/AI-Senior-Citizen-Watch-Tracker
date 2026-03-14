"""
SeniorCare AI – Pharmacy API Client
=====================================
Communicates with an external Pharmacy REST API to request
medication refills when pill inventory is low.

Usage
-----
    from services.pharmacy_api import PharmacyAPI
    api = PharmacyAPI()
    result = api.request_refill("user_123", "Blood Pressure", quantity=30)
"""

from __future__ import annotations

import logging
import os
from typing import Dict, Any

import requests
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ── Configuration ──────────────────────────────
PHARMACY_API_URL = os.getenv("PHARMACY_API_URL", "https://pharmacy.example.com/api/v1")
PHARMACY_API_KEY = os.getenv("PHARMACY_API_KEY", "")
DEFAULT_REFILL_QTY = int(os.getenv("DEFAULT_REFILL_QTY", "30"))
REQUEST_TIMEOUT = int(os.getenv("PHARMACY_TIMEOUT", "10"))


class PharmacyAPI:
    """Client for the external pharmacy fulfillment service."""

    def __init__(self, base_url: str = PHARMACY_API_URL, api_key: str = PHARMACY_API_KEY):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}" if self.api_key else "",
        })
        logger.info("PharmacyAPI initialised (url=%s)", self.base_url)

    # ──────────────────────────────────────────────
    # Request medication refill
    # ──────────────────────────────────────────────
    def request_refill(
        self,
        user_id: str,
        medication: str,
        quantity: int = DEFAULT_REFILL_QTY,
    ) -> Dict[str, Any]:
        """
        POST /refill to the pharmacy service.

        Parameters
        ----------
        user_id    : str – Patient identifier.
        medication : str – Medication name, e.g. "Blood Pressure".
        quantity   : int – Number of pills to order.

        Returns
        -------
        dict – Pharmacy API response or error payload.
        """
        endpoint = f"{self.base_url}/refill"
        payload = {
            "user_id": user_id,
            "medication": medication,
            "quantity": quantity,
        }

        logger.info("Requesting refill: %s", payload)

        try:
            response = self.session.post(endpoint, json=payload, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            data = response.json()
            logger.info("Refill confirmed: %s", data)
            return {
                "status": "success",
                "order_id": data.get("order_id", "N/A"),
                "estimated_delivery": data.get("estimated_delivery", "unknown"),
                "pharmacy_response": data,
            }
        except requests.exceptions.ConnectionError:
            logger.warning("Pharmacy API unreachable – simulating refill.")
            return self._simulate_refill(user_id, medication, quantity)
        except requests.exceptions.HTTPError as exc:
            logger.error("Pharmacy API HTTP error: %s", exc)
            return {"status": "failed", "error": str(exc)}
        except Exception as exc:
            logger.error("Pharmacy API unexpected error: %s", exc, exc_info=True)
            return {"status": "failed", "error": str(exc)}

    # ──────────────────────────────────────────────
    # Check medication inventory status
    # ──────────────────────────────────────────────
    def check_inventory(self, user_id: str, medication: str) -> Dict[str, Any]:
        """GET /inventory for current stock levels."""
        endpoint = f"{self.base_url}/inventory"
        params = {"user_id": user_id, "medication": medication}

        try:
            response = self.session.get(endpoint, params=params, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            return response.json()
        except Exception as exc:
            logger.error("Inventory check failed: %s", exc)
            return {"status": "error", "error": str(exc)}

    # ──────────────────────────────────────────────
    # Simulation fallback (for hackathon / offline dev)
    # ──────────────────────────────────────────────
    @staticmethod
    def _simulate_refill(user_id: str, medication: str, quantity: int) -> Dict[str, Any]:
        """Return a mock refill response when the real API is unavailable."""
        logger.info("[SIMULATED REFILL] user=%s med=%s qty=%d", user_id, medication, quantity)
        return {
            "status": "simulated",
            "order_id": f"SIM-{user_id}-001",
            "medication": medication,
            "quantity": quantity,
            "estimated_delivery": "2–3 business days",
            "note": "Pharmacy API unreachable – this is a simulated response.",
        }
