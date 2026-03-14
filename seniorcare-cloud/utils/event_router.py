"""
SeniorCare AI – Event Router
==============================
Examines a HealthPayload and determines which downstream agent(s) should
be invoked.  Returns a list of routing decisions the Orchestrator will act on.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import List, Dict, Any

from models.health_payload import HealthPayload

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# Agent identifiers (match Lambda function names)
# ──────────────────────────────────────────────
SLEEP_AGENT = "sleep_agent"
ACTIVITY_AGENT = "activity_agent"
MEDICATION_AGENT = "medication_agent"
REFILL_AGENT = "refill_agent"
CALLING_AGENT = "calling_agent"


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
    bedrock_analysis: Dict[str, Any] | None = None,
) -> List[RoutingDecision]:
    """
    Rule-based + AI-augmented routing logic.

    Parameters
    ----------
    health : HealthPayload
        Parsed wearable data.
    bedrock_analysis : dict, optional
        Output from Bedrock risk analysis
        e.g. {"risk_level": "high", "recommended_action": "call"}

    Returns
    -------
    list[RoutingDecision]
        Ordered list of agents to invoke.
    """
    routes: List[RoutingDecision] = []

    # ── 1. Sleep Agent ─────────────────────────
    if health.is_sleep_deficit:
        logger.info("Routing → Sleep Agent (sleep_hours=%.1f)", health.sleep_hours)
        routes.append(RoutingDecision(
            agent_name=SLEEP_AGENT,
            reason=f"Sleep deficit detected: {health.sleep_hours}h (threshold < 6h)",
            payload=health.to_dict(),
        ))

    # ── 2. Activity Agent ──────────────────────
    if health.is_inactive:
        logger.info("Routing → Activity Agent (idle=%d min)", health.last_movement_minutes)
        routes.append(RoutingDecision(
            agent_name=ACTIVITY_AGENT,
            reason=f"Inactivity detected: {health.last_movement_minutes} min (threshold > 240 min)",
            payload=health.to_dict(),
        ))

    # ── 3. Medication Agent ────────────────────
    # Always invoked during medication windows; for hackathon, always trigger
    logger.info("Routing → Medication Agent (always active during demo)")
    routes.append(RoutingDecision(
        agent_name=MEDICATION_AGENT,
        reason="Medication adherence check (time-window active)",
        payload=health.to_dict(),
    ))

    # ── 4. Refill Agent ────────────────────────
    if health.is_pill_low:
        logger.info("Routing → Refill Agent (pill_count=%d)", health.pill_count)
        routes.append(RoutingDecision(
            agent_name=REFILL_AGENT,
            reason=f"Low pill inventory: {health.pill_count} remaining (threshold < 3)",
            payload=health.to_dict(),
        ))

    # ── 5. Calling Agent (AI-driven) ───────────
    if bedrock_analysis:
        risk = bedrock_analysis.get("risk_level", "low")
        action = bedrock_analysis.get("recommended_action", "monitor")
        if risk in ("high",) or action in ("call", "alert"):
            logger.info("Routing → Calling Agent (risk=%s, action=%s)", risk, action)
            routes.append(RoutingDecision(
                agent_name=CALLING_AGENT,
                reason=f"Bedrock AI risk={risk}, recommended_action={action}",
                payload={
                    **health.to_dict(),
                    "risk_level": risk,
                    "recommended_action": action,
                },
            ))

    # ── Also trigger Calling Agent for vital anomalies ──
    if health.is_heart_rate_abnormal or health.is_spo2_low:
        already_routed = any(r.agent_name == CALLING_AGENT for r in routes)
        if not already_routed:
            logger.info("Routing → Calling Agent (vital anomaly)")
            routes.append(RoutingDecision(
                agent_name=CALLING_AGENT,
                reason=(
                    f"Vital anomaly: HR={health.heart_rate}, SpO2={health.spo2}"
                ),
                payload=health.to_dict(),
            ))

    logger.info("Total routes determined: %d", len(routes))
    return routes
