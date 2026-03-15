"""
ElderHarmony – Railtracks Lambda Handler
==========================================
AWS Lambda entry point for the Railtracks-based agentic system.
Receives API Gateway POST /health-data events and processes them
through the Orchestrator agent flow.

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

logger = logging.getLogger(__name__)


def lambda_handler(event, context):
    """
    AWS Lambda + API Gateway entry point.

    1. Configure observability
    2. Parse HealthPayload from the event
    3. Create Railtracks Flow with Orchestrator
    4. Invoke and return consolidated response
    """
    configure_observability()

    logger.info("ElderHarmony Railtracks handler invoked. Event keys: %s",
                list(event.keys()) if isinstance(event, dict) else type(event))

    try:
        health = HealthPayload.from_event(event)
        logger.info("Parsed payload: %s", health.summary())
    except (ValueError, KeyError) as exc:
        logger.error("Invalid payload: %s", exc)
        return _response(400, {"error": f"Invalid payload: {exc}"})

    try:
        flow = rt.Flow(
            name="ElderHarmony",
            entry_point=Orchestrator,
            save_state=not IS_LAMBDA,
        )

        health_json = health.to_json()
        result = flow.invoke(f"Process health data for patient {health.user_id}: {health_json}")

        response_body = {
            "user_id": health.user_id,
            "timestamp": health.timestamp,
            "period": "24h",
            "flow_result": result.text if hasattr(result, "text") else str(result),
        }

        logger.info("ElderHarmony flow complete for user %s", health.user_id)
        return _response(200, response_body)

    except Exception as exc:
        logger.error("Flow execution failed: %s", exc, exc_info=True)
        return _response(500, {"error": f"Flow execution failed: {str(exc)}"})


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
