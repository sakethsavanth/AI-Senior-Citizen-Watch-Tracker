"""
ElderHarmony – Event Router
============================
Determines which of the 5 agents to invoke: VitalSync, Medicine, EmoCare,
Calling, HealthRecords. Uses 24hr vitals, HRV, fall, mood, and refill rules.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import List, Dict, Any

from models.health_payload import HealthPayload

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# ElderHarmony 5 agents
# ──────────────────────────────────────────────
VITAL_SYNC_AGENT = "vital_sync_agent"
MEDICINE_AGENT = "medicine_agent"
EMO_CARE_AGENT = "emo_care_agent"
CALLING_AGENT = "calling_agent"
HEALTH_RECORDS_AGENT = "health_records_agent"


@dataclass
class RoutingDecision:
    """A single agent invocation instruction."""
    agent_name: str
    reason: str
    payload: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "agent_name": self.agent_name,
            "reason": self.reason,
            "payload": self.payload,
        }


def determine_routes(
    health: HealthPayload,
    llm_analysis: Dict[str, Any] | None = None,
) -> List[RoutingDecision]:
    """
    Route to ElderHarmony agents. Vitals = 24hr period.
    - VitalSync: always (daily guardian); HRV low / fall → alerts
    - Medicine: schedule 8/12/18/21; low pills or 3-day miss → refill
    - EmoCare: when mood_score present; low mood → also trigger Calling
    - Calling: emergency, vital anomaly, fall, or EmoCare low mood
    - HealthRecords: always (passive sync / prep)
    """
    routes: List[RoutingDecision] = []
    payload = health.to_dict()

    # ── 1. VitalSync (Continuous Guardian) ─────
    # Always run for daily summary; 24hr vitals, HRV, fall
    reason_parts = ["24hr vitals + daily guardian"]
    if health.fall_detected:
        reason_parts.append("FALL DETECTED")
    if health.is_hrv_low:
        reason_parts.append(f"HRV low ({health.hrv_percent}%)")
    routes.append(RoutingDecision(
        agent_name=VITAL_SYNC_AGENT,
        reason="; ".join(reason_parts),
        payload=payload,
    ))

    # ── 2. Medicine (8AM, 12PM, 6PM, 9PM) ──────
    # Always run for adherence; refill on low pills or 3-day miss
    reason = "Medication adherence (schedule 8/12/18/21)"
    if health.is_pill_low:
        reason += f"; low pills ({health.pill_count})"
    if health.needs_refill_3day_miss:
        reason += "; 3-day miss → auto-refill"
    routes.append(RoutingDecision(
        agent_name=MEDICINE_AGENT,
        reason=reason,
        payload=payload,
    ))

    # ── 3. EmoCare (Mental Wellness) ───────────
    # When mood_score present; score < 3 → also trigger Calling
    if health.mood_score is not None:
        reason = f"Mood check (score={health.mood_score}/5)"
        if health.is_mood_low:
            reason += " – low mood, trigger Calling"
        routes.append(RoutingDecision(
            agent_name=EMO_CARE_AGENT,
            reason=reason,
            payload=payload,
        ))

    # ── 4. Calling (Social / Emergency) ───────
    # Fall → emergency; HRV low / vitals / AI risk / EmoCare low mood
    call_reason = None
    call_payload = {**payload}

    if health.fall_detected:
        call_reason = "EMERGENCY: Fall detected – ambulance + family"
        call_payload["emergency_type"] = "fall"
    elif health.is_hrv_low:
        call_reason = f"HRV < 40% ({health.hrv_percent}%) – possible infection, doctor visit?"
        call_payload["risk_level"] = "medium"
        call_payload["recommended_action"] = "alert"
    elif health.is_heart_rate_abnormal or health.is_spo2_low:
        call_reason = f"Vital anomaly: HR={health.heart_rate_24h}, SpO2={health.spo2_24h}"
        call_payload["risk_level"] = "medium"
        call_payload["recommended_action"] = "alert"
    elif llm_analysis:
        risk = llm_analysis.get("risk_level", "low")
        action = llm_analysis.get("recommended_action", "monitor")
        if risk == "high" or action in ("call", "alert"):
            call_reason = f"OpenRouter AI: risk={risk}, action={action}"
            call_payload["risk_level"] = risk
            call_payload["recommended_action"] = action
    elif health.is_mood_low:
        call_reason = f"EmoCare: low mood (score={health.mood_score}) – trigger call to family"
        call_payload["risk_level"] = "medium"
        call_payload["recommended_action"] = "call"
        call_payload["trigger"] = "emo_care"

    if call_reason:
        routes.append(RoutingDecision(
            agent_name=CALLING_AGENT,
            reason=call_reason,
            payload=call_payload,
        ))

    # ── 5. HealthRecords (Passive) ─────────────
    routes.append(RoutingDecision(
        agent_name=HEALTH_RECORDS_AGENT,
        reason="Sync pharmacy/doctor; med interaction; visit prep",
        payload=payload,
    ))

    logger.info("ElderHarmony routes: %d agents – %s", len(routes), [r.agent_name for r in routes])
    return routes
