"""
ElderHarmony – Health Records Tool Functions
===============================================
Passive data integration tools: medication interactions, lab summaries,
visit prep checklists, and family dashboard view.

In production these would call pharmacy/doctor portal APIs.
Currently returns stub data for hackathon demo.

To add a new health records tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import json
import logging
import railtracks as rt

logger = logging.getLogger(__name__)


@rt.function_node
def get_medication_interactions(medications: str) -> dict:
    """Check for known drug-drug interactions.

    Stub implementation — in production this would query a pharmacy API.

    Args:
        medications: Comma-separated list of medication names.

    Returns:
        dict with medications list and interactions (currently empty).
    """
    return {
        "medications": [m.strip() for m in medications.split(",")],
        "interactions": [],
        "note": "No known interactions (stub — integrate pharmacy API in production).",
    }


@rt.function_node
def get_lab_summary(user_id: str) -> dict:
    """Get a summary of recent lab results for the patient.

    Stub implementation — in production this would query a health records API.

    Args:
        user_id: Patient identifier.

    Returns:
        dict with user_id, last_updated, and summary text.
    """
    return {
        "user_id": user_id,
        "last_updated": "stub",
        "summary": "No new lab results. A1C within range (stub).",
    }


@rt.function_node
def get_visit_prep(user_id: str) -> dict:
    """Generate a doctor visit preparation checklist.

    Args:
        user_id: Patient identifier.

    Returns:
        dict with user_id and checklist items.
    """
    return {
        "user_id": user_id,
        "checklist": [
            "Bring your blood pressure log.",
            "Bring current medication list.",
            "List any symptoms since last visit.",
        ],
    }


@rt.function_node
def build_family_dashboard(health_json: str) -> dict:
    """Build a dashboard view of patient health for family members.

    Parses the full health payload and extracts key metrics into a
    family-friendly summary view.

    Args:
        health_json: JSON string of the complete health payload data.

    Returns:
        dict with vitals_24h, medication info, pill_count, and next_checkup.
    """
    data = json.loads(health_json)

    hr = data.get("heart_rate_avg_24h") or data.get("heart_rate", 0)
    spo2_val = data.get("spo2_avg_24h") or data.get("spo2", 0)
    hrv = data.get("hrv_percent")

    return {
        "user_id": data.get("user_id", "unknown"),
        "vitals_24h": {
            "heart_rate": hr,
            "spo2": spo2_val,
            "hrv_percent": hrv,
        },
        "medication": data.get("medication_name", "Blood Pressure"),
        "pill_count": data.get("pill_count", 0),
        "next_checkup": "Mar 20 (stub — use calendar API)",
    }
