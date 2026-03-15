"""
ElderHarmony – Deterministic Orchestrator Engine
==================================================
Replaces the LLM-based agents-as-tools orchestration with deterministic
routing + direct tool invocation + LLM text generation.

GPT-OSS 120B does not support OpenAI tool-calling format, so we:
  1. Run full_health_assessment directly (deterministic triage)
  2. Route to agents based on clinical thresholds (same rules as orchestrator.py)
  3. Execute each agent's tools directly (no LLM tool-calling needed)
  4. Use LLM for a single comprehensive text summary (text generation works fine)
"""

import json
import logging
import os
import requests
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# LLM endpoint for text generation (no tool calling)
_LLM_BASE = "https://vjioo4r1vyvcozuj.us-east-2.aws.endpoints.huggingface.cloud/v1"
_LLM_MODEL = "openai/gpt-oss-120b"
_LLM_KEY = os.getenv("OPENAI_API_KEY", "test")


# ---------------------------------------------------------------------------
# Tool imports (all @rt.function_node but still callable as regular functions)
# ---------------------------------------------------------------------------
from railtracks_agents.tools.vitals_tools import (
    full_health_assessment,
    assess_vitals,
    assess_hrv,
    assess_fall,
    assess_sleep,
    assess_activity,
)
from railtracks_agents.tools.medication_tools import (
    assess_medication,
    get_current_med_window,
    request_pharmacy_refill,
)
from railtracks_agents.tools.mood_tools import (
    assess_mood,
    build_mood_recommendations,
)
from railtracks_agents.tools.communication_tools import (
    call_senior,
    alert_family_sms,
    emergency_escalation,
    pick_family_contact,
)
from railtracks_agents.tools.health_records_tools import (
    get_medication_interactions,
    get_lab_summary,
    get_visit_prep,
    build_family_dashboard,
)


# ---------------------------------------------------------------------------
# LLM text generation helper (no tool calling)
# ---------------------------------------------------------------------------
def _llm_generate(system_prompt: str, user_content: str, max_tokens: int = 600) -> str:
    """Call GPT-OSS for plain text generation. Returns empty string on failure."""
    try:
        resp = requests.post(
            f"{_LLM_BASE}/chat/completions",
            headers={
                "Authorization": f"Bearer {_LLM_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": _LLM_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content},
                ],
                "max_tokens": max_tokens,
            },
            timeout=30,
        )
        if resp.status_code == 200:
            data = resp.json()
            return data["choices"][0]["message"].get("content") or ""
    except Exception as exc:
        logger.warning("LLM generation failed: %s", exc)
    return ""


# ---------------------------------------------------------------------------
# Routing logic (mirrors orchestrator.py system prompt)
# ---------------------------------------------------------------------------

def _should_run_activity(data: dict) -> bool:
    return data.get("steps", 5000) < 500 or data.get("last_movement_minutes", 0) > 240


def _should_run_sleep(data: dict) -> bool:
    return data.get("sleep_hours", 7) < 6


def _should_run_refill(data: dict) -> bool:
    return data.get("pill_count", 10) < 3 or data.get("doses_missed_consecutive_days", 0) >= 3


def _should_run_emocare(data: dict) -> bool:
    return data.get("mood_score") is not None


def _should_run_calling(data: dict, triage: dict) -> bool:
    if data.get("fall_detected"):
        return True
    hr = data.get("heart_rate", 72)
    if hr < 50 or hr > 120:
        return True
    if data.get("spo2", 97) < 92:
        return True
    if data.get("hrv_percent") is not None and data["hrv_percent"] < 40:
        return True
    mood = data.get("mood_score")
    if mood is not None and mood < 3:
        return True
    if triage.get("overall_risk") == "high":
        return True
    return False


# ---------------------------------------------------------------------------
# Per-agent execution (direct tool calls)
# ---------------------------------------------------------------------------

def _run_vital_sync(data: dict, health_json: str) -> dict:
    """VitalSync Agent: 24hr vitals monitoring."""
    hr = data.get("heart_rate_avg_24h") or data.get("heart_rate", 72)
    spo2_val = data.get("spo2_avg_24h") or data.get("spo2", 97)
    results = {"agent": "VitalSync Agent"}

    results["vitals"] = assess_vitals(hr, spo2_val)

    hrv = data.get("hrv_percent")
    if hrv is not None:
        results["hrv"] = assess_hrv(hrv)

    results["fall"] = assess_fall(data.get("fall_detected", False))
    results["sleep"] = assess_sleep(data.get("sleep_hours", 7))
    results["activity"] = assess_activity(
        data.get("steps", 5000),
        data.get("last_movement_minutes", 30),
    )

    # Determine severity
    if data.get("fall_detected"):
        results["severity"] = "critical"
    elif hrv is not None and hrv < 40:
        results["severity"] = "high"
    elif results["vitals"]["status"] == "critical":
        results["severity"] = "high"
    else:
        results["severity"] = "low"

    # Emergency escalation on fall
    if data.get("fall_detected"):
        senior_num = data.get("emergency_contact") or os.getenv("SENIOR_PHONE_NUMBER", "")
        family_num = os.getenv("FAMILY_PHONE_NUMBER", "")
        results["emergency_action"] = emergency_escalation(senior_num, family_num, "Fall detected by VitalSync")

    # Daily message based on time
    hour = datetime.now(timezone.utc).hour
    if 6 <= hour < 10:
        results["daily_message"] = "Good morning! A 10-minute walk today can help maintain your strength."
    elif 20 <= hour or hour < 2:
        hrv_note = ""
        if hrv is not None:
            hrv_note = f" HRV is {'low — consider a doctor visit' if hrv < 40 else 'looking normal'}."
            results["daily_message"] = f"Time to wind down.{hrv_note} Sleep well!"
        else:
            results["daily_message"] = "Time to wind down. Sleep well!"
    else:
        results["daily_message"] = f"Vitals check: HR={hr} bpm, SpO2={spo2_val}%."

    results["alert_family"] = results["severity"] in ("critical", "high")
    return results


def _run_medicine(data: dict) -> dict:
    """Medicine Agent: medication schedule + auto-refill."""
    pill_count = data.get("pill_count", 10)
    missed = data.get("doses_missed_consecutive_days", 0)
    med_name = data.get("medication_name", "Blood Pressure")

    results = {"agent": "Medicine Agent"}
    results["medication"] = assess_medication(pill_count, missed, med_name)
    results["current_window"] = get_current_med_window()

    # Auto-refill when low or 3-day miss
    if pill_count < 3 or missed >= 3:
        qty = int(os.getenv("DEFAULT_REFILL_QTY", "30"))
        results["refill_result"] = request_pharmacy_refill(
            data.get("user_id", "unknown"), med_name, qty,
        )
        results["refill_requested"] = True
    else:
        results["refill_requested"] = False

    return results


def _run_medication(data: dict) -> dict:
    """Medication Agent: adherence tracking."""
    pill_count = data.get("pill_count", 10)
    missed = data.get("doses_missed_consecutive_days", 0)
    med_name = data.get("medication_name", "Blood Pressure")

    results = {"agent": "Medication Agent"}
    results["medication"] = assess_medication(pill_count, missed, med_name)
    results["current_window"] = get_current_med_window()
    return results


def _run_health_records(data: dict, health_json: str) -> dict:
    """HealthRecords Agent: passive sync + family dashboard."""
    results = {"agent": "HealthRecords Agent"}
    med_name = data.get("medication_name", "Blood Pressure")
    results["interactions"] = get_medication_interactions(med_name)
    results["lab_summary"] = get_lab_summary(data.get("user_id", "unknown"))
    results["visit_prep"] = get_visit_prep(data.get("user_id", "unknown"))
    results["family_dashboard"] = build_family_dashboard(health_json)
    return results


def _run_activity(data: dict) -> dict:
    """Activity Agent: mobility assessment."""
    results = {"agent": "Activity Agent"}
    results["activity"] = assess_activity(
        data.get("steps", 5000),
        data.get("last_movement_minutes", 30),
    )
    results["fall"] = assess_fall(data.get("fall_detected", False))
    return results


def _run_sleep(data: dict) -> dict:
    """Sleep Agent: sleep quality."""
    results = {"agent": "Sleep Agent"}
    results["sleep"] = assess_sleep(data.get("sleep_hours", 7))
    hr = data.get("heart_rate_avg_24h") or data.get("heart_rate", 72)
    spo2_val = data.get("spo2_avg_24h") or data.get("spo2", 97)
    results["vitals"] = assess_vitals(hr, spo2_val)
    return results


def _run_refill(data: dict) -> dict:
    """Refill Agent: pharmacy refill."""
    pill_count = data.get("pill_count", 10)
    missed = data.get("doses_missed_consecutive_days", 0)
    med_name = data.get("medication_name", "Blood Pressure")

    results = {"agent": "Refill Agent"}
    results["medication"] = assess_medication(pill_count, missed, med_name)

    qty = int(os.getenv("DEFAULT_REFILL_QTY", "30"))
    results["refill_result"] = request_pharmacy_refill(
        data.get("user_id", "unknown"), med_name, qty,
    )
    return results


def _run_emocare(data: dict) -> dict:
    """EmoCare Agent: emotional wellbeing."""
    mood = data.get("mood_score", 3.0)
    results = {"agent": "EmoCare Agent"}
    results["mood"] = assess_mood(mood)
    results["recommendations"] = build_mood_recommendations(
        mood,
        data.get("steps", 5000),
        data.get("sleep_hours", 7),
    )
    results["trigger_call"] = mood < 3.0
    return results


def _run_calling(data: dict, triage: dict) -> dict:
    """Calling Agent: voice calls + SMS alerts based on escalation protocol."""
    results = {"agent": "Calling Agent"}
    senior_num = data.get("emergency_contact") or os.getenv("SENIOR_PHONE_NUMBER", "")
    family_num = os.getenv("FAMILY_PHONE_NUMBER", "")

    # Pick family contact if available
    family_contacts = data.get("family_contacts")
    if family_contacts:
        chosen = pick_family_contact(json.dumps(family_contacts))
        results["family_contact_chosen"] = chosen
        if chosen.get("phone"):
            family_num = chosen["phone"]

    risk = triage.get("overall_risk", "low")

    if data.get("fall_detected"):
        # EMERGENCY: fall detected
        results["action_taken"] = "emergency_escalation"
        results["escalation"] = emergency_escalation(
            senior_num, family_num, "FALL DETECTED — emergency protocol activated",
        )
    elif risk == "high":
        # High risk: call senior + SMS family
        results["action_taken"] = "family_alert"
        msg = f"Health alert: {', '.join(triage.get('critical_flags', ['elevated risk']))}"
        results["call"] = call_senior(senior_num, f"Hello, this is ElderHarmony. {msg}. Please check in.")
        results["sms"] = alert_family_sms(
            f"ElderHarmony Alert: {msg}. Please check on your loved one.",
            family_num,
        )
    elif data.get("mood_score") is not None and data["mood_score"] < 3:
        # Low mood: SMS family for emotional support
        results["action_taken"] = "emo_care_family_alert"
        results["sms"] = alert_family_sms(
            f"ElderHarmony: Your loved one's mood is low ({data['mood_score']}/5). "
            "A quick call could brighten their day.",
            family_num,
        )
    else:
        # Medium risk: welfare call
        results["action_taken"] = "welfare_call"
        results["call"] = call_senior(
            senior_num,
            "Hello, this is ElderHarmony. Just checking in — how are you feeling today?",
        )

    return results


# ---------------------------------------------------------------------------
# Main orchestration entry point
# ---------------------------------------------------------------------------

def run_orchestration(health_data: dict) -> dict:
    """
    Execute the full ElderHarmony orchestration pipeline.

    Args:
        health_data: Parsed health payload as a dict.

    Returns:
        Consolidated response with triage, agent results, and LLM summary.
    """
    health_json = json.dumps(health_data, default=str)
    user_id = health_data.get("user_id", "unknown")

    # ---- Step 1: Deterministic triage ----
    logger.info("Step 1: Running full_health_assessment for %s", user_id)
    triage = full_health_assessment(health_json)
    logger.info("Triage complete: risk=%s flags=%s",
                triage.get("overall_risk"), triage.get("critical_flags"))

    # ---- Step 2: Determine routing ----
    agents_to_run = ["VitalSync", "Medicine", "Medication", "HealthRecords"]  # always

    if _should_run_activity(health_data):
        agents_to_run.append("Activity")
    if _should_run_sleep(health_data):
        agents_to_run.append("Sleep")
    if _should_run_refill(health_data):
        agents_to_run.append("Refill")
    if _should_run_emocare(health_data):
        agents_to_run.append("EmoCare")
    if _should_run_calling(health_data, triage):
        agents_to_run.append("Calling")

    # Emergency: Calling goes first on fall
    if health_data.get("fall_detected") and "Calling" in agents_to_run:
        agents_to_run.remove("Calling")
        agents_to_run.insert(0, "Calling")

    logger.info("Step 2: Routing → %s", agents_to_run)

    # ---- Step 3: Execute agents ----
    agent_results = {}
    _dispatch = {
        "VitalSync":     lambda: _run_vital_sync(health_data, health_json),
        "Medicine":      lambda: _run_medicine(health_data),
        "Medication":    lambda: _run_medication(health_data),
        "HealthRecords": lambda: _run_health_records(health_data, health_json),
        "Activity":      lambda: _run_activity(health_data),
        "Sleep":         lambda: _run_sleep(health_data),
        "Refill":        lambda: _run_refill(health_data),
        "EmoCare":       lambda: _run_emocare(health_data),
        "Calling":       lambda: _run_calling(health_data, triage),
    }

    for agent_name in agents_to_run:
        logger.info("Step 3: Running %s Agent", agent_name)
        try:
            agent_results[agent_name] = _dispatch[agent_name]()
        except Exception as exc:
            logger.error("Agent %s failed: %s", agent_name, exc, exc_info=True)
            agent_results[agent_name] = {"agent": f"{agent_name} Agent", "error": str(exc)}

    # ---- Step 4: LLM summary (text generation only — no tool calling) ----
    logger.info("Step 4: Generating LLM summary")
    summary_prompt = (
        "You are ElderHarmony, a senior care AI. Given the following health triage "
        "and agent results for an elderly patient, write a brief, compassionate, "
        "clinically accurate summary (3-5 sentences). Include the risk level, key "
        "concerns, and actions taken."
    )
    summary_data = json.dumps({
        "triage": triage,
        "agents_invoked": agents_to_run,
        "agent_highlights": {
            k: {key: val for key, val in v.items() if key != "agent"}
            for k, v in agent_results.items()
        },
    }, default=str, indent=2)[:3000]  # truncate to stay within context

    summary = _llm_generate(summary_prompt, summary_data, max_tokens=400)
    if not summary:
        # Fallback: deterministic summary
        flags = triage.get("critical_flags", [])
        risk = triage.get("overall_risk", "unknown")
        summary = (
            f"Patient {user_id}: Overall risk is {risk}. "
            f"{'Critical flags: ' + ', '.join(flags) + '. ' if flags else 'No critical flags. '}"
            f"Agents invoked: {', '.join(agents_to_run)}."
        )

    return {
        "user_id": user_id,
        "overall_risk": triage.get("overall_risk", "unknown"),
        "agents_invoked": agents_to_run,
        "triage_result": triage,
        "agent_results": agent_results,
        "summary": summary,
    }
