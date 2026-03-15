"""
ElderHarmony – Railtracks Lambda Handler
==========================================
AWS Lambda entry point for the Railtracks-based agentic system.
Receives API Gateway POST /health-data events and processes them
through the Orchestrator agent flow.

Flow:
  1. Parse & validate HealthPayload
  2. Run deterministic triage (HealthAnalyzer + EventRouter)
  3. Pass triage context into Orchestrator LLM flow
  4. Parse structured response and return

Environment variables:
  OPENAI_API_KEY – GPT-OSS 120B API key (default: "test")
  AWS_LAMBDA_FUNCTION_NAME – set by AWS automatically in Lambda
"""

import json
import logging
import os
import sys

# Ensure project root is on path for imports
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import railtracks as rt
from models.health_payload import HealthPayload
from railtracks_agents.config import LLM, IS_LAMBDA, configure_observability
from railtracks_agents.agents.orchestrator import Orchestrator
from services.health_analyzer import HealthAnalyzer
from utils.event_router import determine_routes

logger = logging.getLogger(__name__)

# ── Field range validation ────────────────────
FIELD_RANGES = {
    "heart_rate": (30, 220),
    "spo2": (50, 100),
    "steps": (0, 100_000),
    "sleep_hours": (0, 24),
    "pill_count": (0, 500),
    "last_movement_minutes": (0, 1440),
    "hrv_percent": (0, 100),
    "mood_score": (1, 5),
    "doses_missed_consecutive_days": (0, 365),
}


def _validate_ranges(health: HealthPayload) -> list[str]:
    """Check field values against clinical/physical ranges. Returns list of violations."""
    errors = []
    for field_name, (lo, hi) in FIELD_RANGES.items():
        value = getattr(health, field_name, None)
        if value is not None and not (lo <= value <= hi):
            errors.append(f"{field_name}={value} out of range [{lo}, {hi}]")
    return errors


def lambda_handler(event, context):
    """
    AWS Lambda + API Gateway entry point.

    1. Configure observability
    2. Parse & validate HealthPayload
    3. Run deterministic triage (HealthAnalyzer + EventRouter)
    4. Build enriched prompt with triage context
    5. Invoke Railtracks Orchestrator flow
    6. Return structured response
    """
    configure_observability()

    logger.info("ElderHarmony Railtracks handler invoked. Event keys: %s",
                list(event.keys()) if isinstance(event, dict) else type(event))

    # ── Step 1: Parse payload ──────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Parsed payload: %s", health.summary())
    except (ValueError, KeyError) as exc:
        logger.error("Invalid payload: %s", exc)
        return _response(400, {"error": f"Invalid payload: {exc}"})

    # ── Step 2: Validate field ranges ──────────
    range_errors = _validate_ranges(health)
    if range_errors:
        logger.warning("Field range violations: %s", range_errors)
        return _response(400, {"error": "Field range violations", "details": range_errors})

    # ── Step 3: Deterministic triage ───────────
    triage_report = HealthAnalyzer.full_assessment(health)
    routes = determine_routes(health)
    suggested_agents = [r.agent_name for r in routes]
    route_reasons = {r.agent_name: r.reason for r in routes}

    logger.info("Triage: risk=%s agents=%s", triage_report["overall_risk"], suggested_agents)

    # ── Step 4: Build enriched prompt ──────────
    health_json = health.to_json()
    triage_context = json.dumps({
        "overall_risk": triage_report["overall_risk"],
        "critical_flags": triage_report["critical_flags"],
        "suggested_agents": suggested_agents,
        "route_reasons": route_reasons,
        "assessments": triage_report["assessments"],
    }, default=str)

    prompt = (
        f"Process health data for patient {health.user_id}.\n\n"
        f"HEALTH DATA:\n{health_json}\n\n"
        f"DETERMINISTIC TRIAGE (pre-computed — use as guidance):\n{triage_context}\n\n"
        f"Based on the triage, invoke the suggested agents and provide a structured "
        f"JSON response with: overall_risk, summary, agents_invoked (list of agent names), "
        f"and agent_results (dict of agent_name -> result)."
    )

    # ── Step 5: Invoke Orchestrator flow ───────
    try:
        flow = rt.Flow(
            name="ElderHarmony",
            entry_point=Orchestrator,
            save_state=not IS_LAMBDA,
        )

        result = flow.invoke(prompt)
        flow_text = result.text if hasattr(result, "text") else str(result)

        # ── Step 6: Parse structured response ──
        response_body = _build_response(health, triage_report, suggested_agents, route_reasons, flow_text)

        logger.info("ElderHarmony flow complete for user %s", health.user_id)
        return _response(200, response_body)

    except Exception as exc:
        logger.error("Flow execution failed: %s", exc, exc_info=True)
        # Fallback: return triage-only response so the client still gets useful data
        fallback_body = _build_fallback_response(health, triage_report, suggested_agents, route_reasons, str(exc))
        return _response(200, fallback_body)


def _build_response(
    health: HealthPayload,
    triage_report: dict,
    suggested_agents: list,
    route_reasons: dict,
    flow_text: str,
) -> dict:
    """Build structured response, attempting to parse LLM output as JSON."""
    # Try to extract JSON from the LLM output
    llm_parsed = _try_parse_json(flow_text)

    return {
        "user_id": health.user_id,
        "timestamp": health.timestamp,
        "period": "24h",
        "deterministic_report": {
            "overall_risk": triage_report["overall_risk"],
            "critical_flags": triage_report["critical_flags"],
            "assessments": triage_report["assessments"],
        },
        "agents_invoked": [
            {"agent_name": name, "reason": route_reasons.get(name, "")}
            for name in suggested_agents
        ],
        "ai_analysis": llm_parsed if llm_parsed else {"raw_response": flow_text},
        "overall_risk": (
            llm_parsed.get("overall_risk", triage_report["overall_risk"])
            if llm_parsed
            else triage_report["overall_risk"]
        ),
        "summary": (
            llm_parsed.get("summary", "")
            if llm_parsed
            else flow_text[:500]
        ),
    }


def _build_fallback_response(
    health: HealthPayload,
    triage_report: dict,
    suggested_agents: list,
    route_reasons: dict,
    error_msg: str,
) -> dict:
    """Fallback response when LLM flow fails — still returns deterministic triage."""
    return {
        "user_id": health.user_id,
        "timestamp": health.timestamp,
        "period": "24h",
        "deterministic_report": {
            "overall_risk": triage_report["overall_risk"],
            "critical_flags": triage_report["critical_flags"],
            "assessments": triage_report["assessments"],
        },
        "agents_invoked": [
            {"agent_name": name, "reason": route_reasons.get(name, "")}
            for name in suggested_agents
        ],
        "ai_analysis": {"error": error_msg, "fallback": True},
        "overall_risk": triage_report["overall_risk"],
        "summary": f"Deterministic triage: risk={triage_report['overall_risk']}, "
                   f"flags={triage_report['critical_flags']}. LLM analysis unavailable.",
    }


def _try_parse_json(text: str) -> dict | None:
    """Attempt to parse JSON from LLM output, handling markdown fences."""
    if not text:
        return None
    # Strip markdown code fences if present
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        # Remove first line (```json) and last line (```)
        lines = [l for l in lines if not l.strip().startswith("```")]
        cleaned = "\n".join(lines).strip()
    try:
        return json.loads(cleaned)
    except (json.JSONDecodeError, TypeError):
        # Try to find JSON object in the text
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except (json.JSONDecodeError, TypeError):
                pass
    return None


def _response(status_code: int, body: dict) -> dict:
    """Build an API Gateway proxy response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }
