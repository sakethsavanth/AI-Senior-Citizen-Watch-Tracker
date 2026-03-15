"""
ElderHarmony – Medication Tool Functions
==========================================
Medication inventory, adherence windows, and pharmacy refill ordering.
Wraps services/pharmacy_api.py for refill requests.

To add a new medication tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import json
import logging
from datetime import datetime, timezone
import railtracks as rt

logger = logging.getLogger(__name__)

# Clinical threshold (mirrored from models/health_payload.py)
PILL_LOW_THRESHOLD = 3
MISSED_DOSES_REFILL_DAYS = 3

# Medication windows used by the medication adherence agent
MEDICATION_WINDOWS = {
    "morning":   {"hour_start": 7,  "hour_end": 10, "label": "Morning medication"},
    "afternoon": {"hour_start": 12, "hour_end": 14, "label": "Afternoon medication"},
    "evening":   {"hour_start": 18, "hour_end": 21, "label": "Evening medication"},
    "night":     {"hour_start": 21, "hour_end": 23, "label": "Night medication"},
}


@rt.function_node
def assess_medication(pill_count: int, doses_missed_consecutive_days: int, medication_name: str) -> dict:
    """Evaluate medication inventory and adherence status.

    Args:
        pill_count: Number of pills remaining.
        doses_missed_consecutive_days: How many consecutive days doses were missed.
        medication_name: Name of the medication (e.g. 'Blood Pressure').

    Returns:
        dict with category, pill_count, status (depleted/low/sufficient),
        refill_needed flag, and refill_3day_miss flag.
    """
    if pill_count == 0:
        status = "depleted"
    elif pill_count < PILL_LOW_THRESHOLD:
        status = "low"
    else:
        status = "sufficient"

    return {
        "category": "medication",
        "pill_count": pill_count,
        "medication_name": medication_name,
        "status": status,
        "refill_needed": pill_count < PILL_LOW_THRESHOLD,
        "refill_3day_miss": doses_missed_consecutive_days >= MISSED_DOSES_REFILL_DAYS,
    }


@rt.function_node
def get_current_med_window() -> dict:
    """Check which medication window is currently active based on UTC time.

    Returns:
        dict with window name, label, hour range, and current_hour. Returns
        window=None if no window is active.
    """
    now = datetime.now(timezone.utc)
    current_hour = now.hour

    for window_name, window in MEDICATION_WINDOWS.items():
        if window["hour_start"] <= current_hour < window["hour_end"]:
            return {
                "window": window_name,
                "label": window["label"],
                "hour_start": window["hour_start"],
                "hour_end": window["hour_end"],
                "current_hour": current_hour,
            }

    return {"window": None, "label": "No active medication window", "current_hour": current_hour}


@rt.function_node
def request_pharmacy_refill(user_id: str, medication: str, quantity: int) -> dict:
    """Request a medication refill from the pharmacy API.

    Wraps PharmacyAPI.request_refill(). Falls back to a simulated response
    if the pharmacy service is unreachable (hackathon mode).

    Args:
        user_id: Patient identifier.
        medication: Medication name (e.g. 'Blood Pressure').
        quantity: Number of pills to order.

    Returns:
        dict with status, order_id, estimated_delivery, and pharmacy response.
    """
    from services.pharmacy_api import PharmacyAPI

    pharmacy = PharmacyAPI()
    result = pharmacy.request_refill(
        user_id=user_id,
        medication=medication,
        quantity=quantity,
    )
    logger.info("Pharmacy refill result: %s", result.get("order_id", "N/A"))
    return result


@rt.function_node
def should_refill(pill_count: int, doses_missed_consecutive_days: int) -> dict:
    """Centralized refill decision used by both Medicine and Refill agents.

    Args:
        pill_count: Number of pills remaining.
        doses_missed_consecutive_days: Consecutive days of missed doses.

    Returns:
        dict with refill_needed (bool), reason (str), and urgency (low/medium/high).
    """
    reasons = []
    if pill_count == 0:
        reasons.append(f"Depleted (0 pills)")
    elif pill_count < PILL_LOW_THRESHOLD:
        reasons.append(f"Low stock ({pill_count} pills < {PILL_LOW_THRESHOLD})")
    if doses_missed_consecutive_days >= MISSED_DOSES_REFILL_DAYS:
        reasons.append(f"{doses_missed_consecutive_days}-day miss streak (>= {MISSED_DOSES_REFILL_DAYS})")

    needed = len(reasons) > 0
    if pill_count == 0:
        urgency = "high"
    elif needed:
        urgency = "medium"
    else:
        urgency = "low"

    return {
        "refill_needed": needed,
        "reason": "; ".join(reasons) if reasons else "Stock sufficient, no missed doses",
        "urgency": urgency,
    }


@rt.function_node
def compute_adherence_today(medication_taken_today_json: str) -> dict:
    """Compute today's adherence from the medication_taken_today dict.

    Args:
        medication_taken_today_json: JSON string like '{"morning": true, "afternoon": false}'.

    Returns:
        dict with taken list, missed list, adherence_pct, and summary text.
    """
    data = json.loads(medication_taken_today_json) if medication_taken_today_json else {}
    taken = [w for w, v in data.items() if v]
    missed = [w for w, v in data.items() if not v]
    total = len(data) if data else 1
    pct = round(len(taken) / total * 100) if data else 0

    summary_parts = []
    if taken:
        summary_parts.append(f"Taken: {', '.join(taken)}")
    if missed:
        summary_parts.append(f"Missed: {', '.join(missed)}")

    return {
        "taken": taken,
        "missed": missed,
        "adherence_pct": pct,
        "summary": ". ".join(summary_parts) if summary_parts else "No medication schedule data",
    }


@rt.function_node
def build_medication_reminder(health_json: str) -> dict:
    """Build a voice/text reminder message for the current medication state.

    Args:
        health_json: JSON string of the complete health payload data.

    Returns:
        dict with message (str), window (str or None), med_name, pill_count.
    """
    data = json.loads(health_json)
    med_name = data.get("medication_name", "your medication")
    pill_count = data.get("pill_count", 0)
    taken_today = data.get("medication_taken_today") or {}

    # Determine current window
    now = datetime.now(timezone.utc)
    current_window = None
    for window_name, window in MEDICATION_WINDOWS.items():
        if window["hour_start"] <= now.hour < window["hour_end"]:
            current_window = window_name
            break

    # Build message
    if current_window and not taken_today.get(current_window, False):
        msg = (f"Hello! It's time for your {current_window} {med_name}. "
               f"You have {pill_count} pills remaining.")
    elif current_window and taken_today.get(current_window, False):
        msg = (f"Great job! You've already taken your {current_window} {med_name}. "
               f"You have {pill_count} pills remaining.")
    else:
        missed = [w for w, v in taken_today.items() if not v]
        if missed:
            msg = (f"Reminder: You missed your {', '.join(missed)} {med_name}. "
                   f"You have {pill_count} pills remaining.")
        else:
            msg = f"All doses taken today for {med_name}. You have {pill_count} pills remaining."

    if pill_count < PILL_LOW_THRESHOLD:
        msg += " Your supply is running low — a refill has been requested."

    return {
        "message": msg,
        "window": current_window,
        "medication_name": med_name,
        "pill_count": pill_count,
    }
