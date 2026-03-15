"""
ElderHarmony – Vitals Tool Functions
======================================
Deterministic health assessments extracted from services/health_analyzer.py.
Each function is a @rt.function_node that accepts primitive types so the
LLM can invoke them directly.

To add a new vitals tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import json
import logging
import railtracks as rt

logger = logging.getLogger(__name__)

# Clinical thresholds (mirrored from models/health_payload.py)
HEART_RATE_LOW = 50
HEART_RATE_HIGH = 120
SPO2_LOW_THRESHOLD = 92
HRV_LOW_PERCENT = 40
SLEEP_LOW_THRESHOLD = 6.0
INACTIVITY_HIGH_THRESHOLD = 240


@rt.function_node
def assess_vitals(heart_rate: float, spo2: float) -> dict:
    """Check heart rate and SpO2 against clinical thresholds.

    Args:
        heart_rate: Heart rate in BPM (24h average or spot reading).
        spo2: Blood oxygen saturation percentage (24h average or spot reading).

    Returns:
        dict with category, heart_rate, spo2, status (critical/normal), and issues list.
    """
    issues = []
    if heart_rate < HEART_RATE_LOW:
        issues.append(f"Bradycardia: HR={heart_rate} bpm (< {HEART_RATE_LOW})")
    elif heart_rate > HEART_RATE_HIGH:
        issues.append(f"Tachycardia: HR={heart_rate} bpm (> {HEART_RATE_HIGH})")
    if spo2 < SPO2_LOW_THRESHOLD:
        issues.append(f"Hypoxemia: SpO2={spo2}% (< {SPO2_LOW_THRESHOLD}%)")
    return {
        "category": "vitals",
        "heart_rate": heart_rate,
        "spo2": spo2,
        "period": "24h",
        "status": "critical" if issues else "normal",
        "issues": issues,
    }


@rt.function_node
def assess_hrv(hrv_percent: float) -> dict:
    """Assess Heart Rate Variability as percentage of normal.

    Args:
        hrv_percent: HRV as percentage of normal baseline (e.g. from Whoop recovery).

    Returns:
        dict with category, hrv_percent, status (low/normal), and below_threshold flag.
    """
    below = hrv_percent < HRV_LOW_PERCENT
    return {
        "category": "hrv",
        "hrv_percent": hrv_percent,
        "status": "low" if below else "normal",
        "below_threshold": below,
    }


@rt.function_node
def assess_fall(fall_detected: bool) -> dict:
    """Check if a fall has been detected — triggers emergency protocol.

    Args:
        fall_detected: Whether the wearable detected a fall event.

    Returns:
        dict with category, fall_detected flag, and status (critical/normal).
    """
    return {
        "category": "fall",
        "fall_detected": fall_detected,
        "status": "critical" if fall_detected else "normal",
    }


@rt.function_node
def assess_sleep(sleep_hours: float) -> dict:
    """Evaluate sleep quality from duration.

    Args:
        sleep_hours: Total hours of sleep in the last 24h period.

    Returns:
        dict with category, sleep_hours, quality (poor/fair/good), and below_threshold flag.
    """
    if sleep_hours < 4:
        quality = "poor"
    elif sleep_hours < SLEEP_LOW_THRESHOLD:
        quality = "fair"
    else:
        quality = "good"
    return {
        "category": "sleep",
        "sleep_hours": sleep_hours,
        "quality": quality,
        "below_threshold": sleep_hours < SLEEP_LOW_THRESHOLD,
    }


@rt.function_node
def assess_activity(steps: int, last_movement_minutes: int) -> dict:
    """Evaluate mobility and inactivity risk.

    Args:
        steps: Step count for the day.
        last_movement_minutes: Minutes since last detected movement.

    Returns:
        dict with category, steps, last_movement_minutes, status (critical/sedentary/active), and inactive_flag.
    """
    if last_movement_minutes > 360:
        status = "critical"
    elif last_movement_minutes > INACTIVITY_HIGH_THRESHOLD:
        status = "sedentary"
    else:
        status = "active"
    return {
        "category": "activity",
        "steps": steps,
        "last_movement_minutes": last_movement_minutes,
        "status": status,
        "inactive_flag": last_movement_minutes > INACTIVITY_HIGH_THRESHOLD,
    }


@rt.function_node
def full_health_assessment(health_json: str) -> dict:
    """Run all deterministic health assessments on a complete health payload.

    This is the primary triage tool. It parses the full health JSON,
    runs vitals, HRV, fall, sleep, activity, medication, and mood checks,
    and returns a composite risk level (low/medium/high) with critical flags.

    Args:
        health_json: JSON string of the complete health payload data.

    Returns:
        dict with user_id, overall_risk (low/medium/high), assessments list, and critical_flags.
    """
    data = json.loads(health_json)

    hr = data.get("heart_rate_avg_24h") or data.get("heart_rate", 72)
    spo2_val = data.get("spo2_avg_24h") or data.get("spo2", 97)
    hrv = data.get("hrv_percent")
    fall = data.get("fall_detected", False)
    sleep_h = data.get("sleep_hours", 7)
    steps_val = data.get("steps", 5000)
    movement = data.get("last_movement_minutes", 30)
    pill_count = data.get("pill_count", 10)
    missed_days = data.get("doses_missed_consecutive_days", 0)
    med_name = data.get("medication_name", "Blood Pressure")
    mood = data.get("mood_score")

    assessments = []

    # Vitals
    vitals_issues = []
    if hr < HEART_RATE_LOW:
        vitals_issues.append(f"Bradycardia: HR={hr} bpm (< {HEART_RATE_LOW})")
    elif hr > HEART_RATE_HIGH:
        vitals_issues.append(f"Tachycardia: HR={hr} bpm (> {HEART_RATE_HIGH})")
    if spo2_val < SPO2_LOW_THRESHOLD:
        vitals_issues.append(f"Hypoxemia: SpO2={spo2_val}% (< {SPO2_LOW_THRESHOLD}%)")
    assessments.append({
        "category": "vitals", "heart_rate": hr, "spo2": spo2_val,
        "period": "24h", "status": "critical" if vitals_issues else "normal",
        "issues": vitals_issues,
    })

    # HRV
    if hrv is not None:
        hrv_low = hrv < HRV_LOW_PERCENT
        assessments.append({"category": "hrv", "hrv_percent": hrv, "status": "low" if hrv_low else "normal", "below_threshold": hrv_low})
    else:
        assessments.append({"category": "hrv", "hrv_percent": None, "status": "unknown", "below_threshold": False})

    # Fall
    assessments.append({"category": "fall", "fall_detected": fall, "status": "critical" if fall else "normal"})

    # Sleep
    if sleep_h < 4:
        sq = "poor"
    elif sleep_h < SLEEP_LOW_THRESHOLD:
        sq = "fair"
    else:
        sq = "good"
    assessments.append({"category": "sleep", "sleep_hours": sleep_h, "quality": sq, "below_threshold": sleep_h < SLEEP_LOW_THRESHOLD})

    # Activity
    if movement > 360:
        act_status = "critical"
    elif movement > INACTIVITY_HIGH_THRESHOLD:
        act_status = "sedentary"
    else:
        act_status = "active"
    assessments.append({"category": "activity", "steps": steps_val, "last_movement_minutes": movement, "status": act_status, "inactive_flag": movement > INACTIVITY_HIGH_THRESHOLD})

    # Medication
    if pill_count == 0:
        med_status = "depleted"
    elif pill_count < 3:
        med_status = "low"
    else:
        med_status = "sufficient"
    assessments.append({"category": "medication", "pill_count": pill_count, "medication_name": med_name, "status": med_status, "refill_needed": pill_count < 3, "refill_3day_miss": missed_days >= 3})

    # Mood
    if mood is not None:
        mood_low = mood < 3.0
        assessments.append({"category": "mood", "mood_score": mood, "status": "low" if mood_low else "ok", "low_mood": mood_low})
    else:
        assessments.append({"category": "mood", "mood_score": None, "status": "unknown", "low_mood": False})

    # Composite risk
    critical_flags = []
    for a in assessments:
        if a.get("category") == "mood" and a.get("low_mood"):
            critical_flags.append("mood")
        elif a.get("status") in ("critical", "poor", "depleted"):
            critical_flags.append(a["category"])
        if a.get("issues"):
            critical_flags.extend(a["issues"])
    if fall:
        critical_flags.append("fall")

    if len(critical_flags) >= 2 or fall:
        overall_risk = "high"
    elif len(critical_flags) == 1:
        overall_risk = "medium"
    else:
        overall_risk = "low"

    logger.info("full_health_assessment: risk=%s flags=%s", overall_risk, critical_flags)
    return {
        "user_id": data.get("user_id", "unknown"),
        "overall_risk": overall_risk,
        "assessments": assessments,
        "critical_flags": critical_flags,
    }
