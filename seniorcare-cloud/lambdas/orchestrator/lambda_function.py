"""
SeniorCare AI – Lambda Orchestrator
=====================================
Central intelligence controller.  Receives health-data POST events from
API Gateway, runs deterministic + AI risk analysis, then fans out to the
appropriate micro-agent Lambdas.

Trigger : API Gateway  →  POST /health-data
Runtime : Python 3.11
Memory  : 512 MB recommended
Timeout : 60 s recommended

Environment Variables
---------------------
SLEEP_AGENT_ARN, ACTIVITY_AGENT_ARN, MEDICATION_AGENT_ARN,
REFILL_AGENT_ARN, CALLING_AGENT_ARN  – ARNs of downstream agent Lambdas.
AWS_REGION – AWS region (default us-east-1).
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Dict, Any, List

import boto3
from dotenv import load_dotenv

# ── Path setup (allows shared modules when running locally) ────
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

load_dotenv()

from models.health_payload import HealthPayload
from services.bedrock_client import BedrockClient
from services.health_analyzer import HealthAnalyzer
from utils.event_router import determine_routes, RoutingDecision

# ── Logging ────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ── AWS Clients ────────────────────────────────
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
lambda_client = boto3.client("lambda", region_name=AWS_REGION)

# ── Agent Lambda ARNs (set in console or .env) ─
AGENT_ARNS: Dict[str, str] = {
    "sleep_agent":      os.getenv("SLEEP_AGENT_ARN", ""),
    "activity_agent":   os.getenv("ACTIVITY_AGENT_ARN", ""),
    "medication_agent": os.getenv("MEDICATION_AGENT_ARN", ""),
    "refill_agent":     os.getenv("REFILL_AGENT_ARN", ""),
    "calling_agent":    os.getenv("CALLING_AGENT_ARN", ""),
}

# ── Bedrock AI client ─────────────────────────
bedrock = BedrockClient()


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main entry point invoked by API Gateway.

    Flow
    ----
    1. Parse & validate the health payload
    2. Run deterministic health assessment (HealthAnalyzer)
    3. Run AI-based risk analysis (Bedrock / Claude)
    4. Determine which agents to invoke (EventRouter)
    5. Fan-out: invoke each agent Lambda asynchronously
    6. Return consolidated response to API Gateway
    """
    logger.info("Orchestrator invoked. Event keys: %s", list(event.keys()))

    # ── 1. Parse payload ───────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Parsed payload: %s", health.summary())
    except (ValueError, KeyError) as exc:
        logger.error("Invalid payload: %s", exc)
        return _response(400, {"error": f"Invalid payload: {exc}"})

    # ── 2. Deterministic assessment ────────────
    deterministic_report = HealthAnalyzer.full_assessment(health)
    logger.info("Deterministic risk: %s", deterministic_report["overall_risk"])

    # ── 3. AI-based risk analysis (Bedrock) ────
    try:
        bedrock_analysis = bedrock.analyze_health(health.to_dict())
        logger.info("Bedrock analysis: %s", bedrock_analysis)
    except Exception as exc:
        logger.warning("Bedrock analysis failed, falling back to rules: %s", exc)
        bedrock_analysis = {
            "risk_level": deterministic_report["overall_risk"],
            "recommended_action": "alert" if deterministic_report["overall_risk"] != "low" else "monitor",
            "explanation": "Bedrock unavailable – using deterministic fallback.",
        }

    # ── 4. Route to agents ─────────────────────
    routes: List[RoutingDecision] = determine_routes(health, bedrock_analysis)
    logger.info("Routing to %d agent(s): %s", len(routes), [r.agent_name for r in routes])

    # ── 5. Fan-out: invoke agent Lambdas ───────
    invocation_results = []
    for route in routes:
        result = _invoke_agent(route)
        invocation_results.append(result)

    # ── 6. Build response ──────────────────────
    response_body = {
        "user_id": health.user_id,
        "timestamp": health.timestamp,
        "deterministic_report": deterministic_report,
        "ai_analysis": bedrock_analysis,
        "agents_invoked": [r.to_dict() for r in routes],
        "invocation_results": invocation_results,
    }

    logger.info("Orchestrator complete. Agents invoked: %d", len(routes))
    return _response(200, response_body)


# ==============================================================
#  HELPER: Invoke a downstream agent Lambda
# ==============================================================
def _invoke_agent(route: RoutingDecision) -> Dict[str, Any]:
    """
    Invoke an agent Lambda asynchronously (Event invocation type).

    If the ARN is not configured, the invocation is simulated locally
    (useful for dev/hackathon).
    """
    agent_name = route.agent_name
    arn = AGENT_ARNS.get(agent_name, "")

    if not arn:
        logger.warning("No ARN for '%s' – simulating local invocation.", agent_name)
        return {
            "agent": agent_name,
            "status": "simulated",
            "reason": route.reason,
        }

    try:
        response = lambda_client.invoke(
            FunctionName=arn,
            InvocationType="Event",  # async fire-and-forget
            Payload=json.dumps(route.payload),
        )
        status_code = response.get("StatusCode", 0)
        logger.info("Invoked %s → HTTP %d", agent_name, status_code)
        return {
            "agent": agent_name,
            "status": "invoked",
            "http_status": status_code,
        }
    except Exception as exc:
        logger.error("Failed to invoke %s: %s", agent_name, exc)
        return {
            "agent": agent_name,
            "status": "failed",
            "error": str(exc),
        }


# ==============================================================
#  HELPER: API Gateway proxy response builder
# ==============================================================
def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Format a Lambda Proxy Integration response for API Gateway."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }
