"""
ElderHarmony – Lambda Orchestrator
===================================
Central controller. Receives health-data POST (vitals = 24hr period),
runs deterministic + AI risk analysis, fans out to: VitalSync, Medicine,
EmoCare, Calling, HealthRecords.

Trigger : API Gateway  →  POST /health-data
Environment Variables
---------------------
VITAL_SYNC_AGENT_ARN, MEDICINE_AGENT_ARN, EMO_CARE_AGENT_ARN,
CALLING_AGENT_ARN, HEALTH_RECORDS_AGENT_ARN
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Dict, Any, List

import boto3
from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv()

from models.health_payload import HealthPayload
from services.bedrock_client import BedrockClient
from services.health_analyzer import HealthAnalyzer
from utils.event_router import determine_routes, RoutingDecision

logger = logging.getLogger()
logger.setLevel(logging.INFO)

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
lambda_client = boto3.client("lambda", region_name=AWS_REGION)

# ElderHarmony 5 agents
AGENT_ARNS: Dict[str, str] = {
    "vital_sync_agent":    os.getenv("VITAL_SYNC_AGENT_ARN", ""),
    "medicine_agent":      os.getenv("MEDICINE_AGENT_ARN", ""),
    "emo_care_agent":      os.getenv("EMO_CARE_AGENT_ARN", ""),
    "calling_agent":       os.getenv("CALLING_AGENT_ARN", ""),
    "health_records_agent": os.getenv("HEALTH_RECORDS_AGENT_ARN", ""),
}

bedrock = BedrockClient()


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    1. Parse & validate health payload (24hr vitals)
    2. Deterministic assessment (HealthAnalyzer)
    3. AI risk analysis (Bedrock)
    4. Route to VitalSync, Medicine, EmoCare, Calling, HealthRecords
    5. Fan-out invoke agent Lambdas
    6. Return consolidated response
    """
    logger.info("ElderHarmony Orchestrator invoked. Event keys: %s", list(event.keys()))

    try:
        health = HealthPayload.from_event(event)
        logger.info("Parsed payload: %s", health.summary())
    except (ValueError, KeyError) as exc:
        logger.error("Invalid payload: %s", exc)
        return _response(400, {"error": f"Invalid payload: {exc}"})

    deterministic_report = HealthAnalyzer.full_assessment(health)
    logger.info("Deterministic risk: %s", deterministic_report["overall_risk"])

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

    routes: List[RoutingDecision] = determine_routes(health, bedrock_analysis)
    logger.info("Routing to %d agent(s): %s", len(routes), [r.agent_name for r in routes])

    invocation_results = []
    for route in routes:
        result = _invoke_agent(route)
        invocation_results.append(result)

    response_body = {
        "user_id": health.user_id,
        "timestamp": health.timestamp,
        "period": "24h",
        "deterministic_report": deterministic_report,
        "ai_analysis": bedrock_analysis,
        "agents_invoked": [r.to_dict() for r in routes],
        "invocation_results": invocation_results,
    }

    logger.info("Orchestrator complete. Agents invoked: %d", len(routes))
    return _response(200, response_body)


def _invoke_agent(route: RoutingDecision) -> Dict[str, Any]:
    agent_name = route.agent_name
    arn = AGENT_ARNS.get(agent_name, "")

    if not arn:
        logger.warning("No ARN for '%s' – simulating.", agent_name)
        return {"agent": agent_name, "status": "simulated", "reason": route.reason}

    try:
        response = lambda_client.invoke(
            FunctionName=arn,
            InvocationType="Event",
            Payload=json.dumps(route.payload),
        )
        status_code = response.get("StatusCode", 0)
        logger.info("Invoked %s → HTTP %d", agent_name, status_code)
        return {"agent": agent_name, "status": "invoked", "http_status": status_code}
    except Exception as exc:
        logger.error("Failed to invoke %s: %s", agent_name, exc)
        return {"agent": agent_name, "status": "failed", "error": str(exc)}


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
        },
        "body": json.dumps(body, default=str),
    }
