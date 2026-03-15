"""
ElderHarmony – Health Records Tool Functions
===============================================
Passive data integration tools: medication interactions, lab summaries,
visit prep checklists, and family dashboard view.

In production these would call pharmacy/doctor portal APIs.
Uses a static interaction list and data-driven logic for hackathon demo.

To add a new health records tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import json
import logging
import railtracks as rt

logger = logging.getLogger(__name__)

# Common drug interaction pairs (simplified for demo)
KNOWN_INTERACTIONS = [
    ({"blood pressure", "lisinopril", "amlodipine", "losartan"}, {"nsaid", "ibuprofen", "naproxen"},
     "ACE inhibitors / ARBs + NSAIDs may reduce blood pressure control and increase kidney risk."),
    ({"warfarin", "coumadin"}, {"aspirin", "ibuprofen", "naproxen"},
     "Warfarin + NSAIDs increases bleeding risk significantly."),
    ({"metformin"}, {"alcohol"},
     "Metformin + alcohol increases risk of lactic acidosis."),
    ({"lisinopril", "enalapril"}, {"potassium", "spironolactone"},
     "ACE inhibitors + potassium-sparing diuretics may cause hyperkalemia."),
]


@rt.function_node
def get_medication_interactions(medications: str) -> dict:
    """Check for known drug-drug interactions from a static list.

    Args:
        medications: Comma-separated list of medication names.

    Returns:
        dict with medications list and interactions found.
    """
    meds = [m.strip().lower() for m in medications.split(",")]
    med_set = set(meds)
    interactions = []

    for group_a, group_b, warning in KNOWN_INTERACTIONS:
        match_a = med_set & group_a
        match_b = med_set & group_b
        if match_a and match_b:
            interactions.append({
                "drug_a": list(match_a),
                "drug_b": list(match_b),
                "warning": warning,
            })

    return {
        "medications": meds,
        "interactions": interactions,
        "interaction_count": len(interactions),
        "note": "No known interactions found." if not interactions else f"{len(interactions)} interaction(s) detected.",
    }


@rt.function_node
def get_lab_summary(user_id: str) -> dict:
    """Get a summary of recent lab results for the patient.

    Stub for demo — returns synthetic lab data based on user_id.

    Args:
        user_id: Patient identifier.

    Returns:
        dict with user_id, last_updated, and lab results summary.
    """
    # Synthetic lab data per user for demo
    lab_data = {
        "senior_001": {"a1c": "6.2%", "cholesterol": "195 mg/dL", "bp_avg": "128/78", "note": "All within range."},
        "senior_002": {"a1c": "7.1%", "cholesterol": "220 mg/dL", "bp_avg": "142/88", "note": "A1C slightly elevated. Discuss diet."},
        "senior_003": {"a1c": "5.8%", "cholesterol": "180 mg/dL", "bp_avg": "118/72", "note": "Excellent lab results."},
    }
    results = lab_data.get(user_id, {"note": "No lab results on file."})

    return {
        "user_id": user_id,
        "last_updated": "2026-03-01",
        "results": results,
        "summary": results.get("note", "No summary available."),
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
def get_visit_prep_from_health(health_json: str) -> dict:
    """Generate a data-driven doctor visit preparation checklist based on health data.

    Adds condition-specific items when fall risk, HRV, or sleep issues exist.

    Args:
        health_json: JSON string of the complete health payload data.

    Returns:
        dict with user_id and a dynamic checklist.
    """
    data = json.loads(health_json)
    checklist = [
        "Bring your blood pressure log.",
        "Bring current medication list.",
        "List any symptoms since last visit.",
    ]

    if data.get("fall_detected"):
        checklist.append("Discuss recent fall event and fall prevention strategies.")
    if data.get("hrv_percent") is not None and data["hrv_percent"] < 40:
        checklist.append("Discuss low HRV — possible infection or stress.")
    if data.get("sleep_hours", 7) < 4:
        checklist.append("Discuss persistent poor sleep.")
    if data.get("mood_score") is not None and data["mood_score"] < 3:
        checklist.append("Discuss low mood and mental health support options.")
    if data.get("pill_count", 10) < 3:
        checklist.append("Request medication refill during visit.")
    if data.get("doses_missed_consecutive_days", 0) >= 3:
        checklist.append("Discuss medication adherence challenges.")

    return {
        "user_id": data.get("user_id", "unknown"),
        "checklist": checklist,
    }


@rt.function_node
def build_family_dashboard(health_json: str) -> dict:
    """Build a dashboard view of patient health for family members.

    Parses the full health payload and extracts key metrics into a
    family-friendly summary view.

    Args:
        health_json: JSON string of the complete health payload data.

    Returns:
        dict with vitals_24h, medication info, pill_count, alerts, and next_checkup.
    """
    data = json.loads(health_json)

    hr = data.get("heart_rate_avg_24h") or data.get("heart_rate", 0)
    spo2_val = data.get("spo2_avg_24h") or data.get("spo2", 0)
    hrv = data.get("hrv_percent")

    # Generate active alerts
    alerts = []
    if data.get("fall_detected"):
        alerts.append({"type": "emergency", "message": "Fall detected — emergency protocol activated."})
    if hr > 120 or hr < 50:
        alerts.append({"type": "warning", "message": f"Abnormal heart rate: {hr} bpm."})
    if spo2_val < 92:
        alerts.append({"type": "warning", "message": f"Low blood oxygen: {spo2_val}%."})
    if data.get("mood_score") is not None and data["mood_score"] < 3:
        alerts.append({"type": "info", "message": f"Low mood reported ({data['mood_score']}/5)."})
    if data.get("pill_count", 10) < 3:
        alerts.append({"type": "info", "message": f"Medication running low ({data.get('pill_count')} pills)."})

    return {
        "user_id": data.get("user_id", "unknown"),
        "vitals_24h": {
            "heart_rate": hr,
            "spo2": spo2_val,
            "hrv_percent": hrv,
        },
        "sleep_hours": data.get("sleep_hours", 0),
        "steps": data.get("steps", 0),
        "medication": data.get("medication_name", "Blood Pressure"),
        "pill_count": data.get("pill_count", 0),
        "alerts": alerts,
        "alert_count": len(alerts),
        "next_checkup": "Mar 20 (stub — use calendar API)",
    }
