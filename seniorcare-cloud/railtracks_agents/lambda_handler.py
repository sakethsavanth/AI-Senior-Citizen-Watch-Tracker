"""
ElderHarmony – Railtracks Lambda Handler
==========================================
AWS Lambda entry point for the ElderHarmony agentic system.
Receives API Gateway POST /health-data events and processes them
through the deterministic orchestrator engine.

The orchestrator uses direct tool invocation for deterministic health
assessments and agent routing, with LLM text generation for summaries.

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

from models.health_payload import HealthPayload
from railtracks_agents.config import IS_LAMBDA, configure_observability
from railtracks_agents.orchestrator_engine import run_orchestration

logger = logging.getLogger(__name__)


def lambda_handler(event, context):
    """
    AWS Lambda + API Gateway entry point.

    1. Configure observability
    2. Parse HealthPayload from the event
    3. Run deterministic orchestration with all agents
    4. Return consolidated response
    """
    configure_observability()

    logger.info("ElderHarmony handler invoked. Event keys: %s",
                list(event.keys()) if isinstance(event, dict) else type(event))

    try:
        health = HealthPayload.from_event(event)
        logger.info("Parsed payload: %s", health.summary())
    except (ValueError, KeyError) as exc:
        logger.error("Invalid payload: %s", exc)
        return _response(400, {"error": f"Invalid payload: {exc}"})

    try:
        health_dict = json.loads(health.to_json())
        result = run_orchestration(health_dict)

        response_body = {
            "user_id": health.user_id,
            "timestamp": health.timestamp,
            "period": "24h",
            "overall_risk": result.get("overall_risk", "unknown"),
            "agents_invoked": result.get("agents_invoked", []),
            "triage_result": result.get("triage_result", {}),
            "agent_results": result.get("agent_results", {}),
            "summary": result.get("summary", ""),
        }

        logger.info("ElderHarmony orchestration complete for user %s — risk=%s agents=%s",
                     health.user_id, result.get("overall_risk"), result.get("agents_invoked"))
        return _response(200, response_body)

    except Exception as exc:
        logger.error("Orchestration failed: %s", exc, exc_info=True)
        return _response(500, {"error": f"Orchestration failed: {str(exc)}"})


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
