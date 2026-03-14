"""
SeniorCare AI – Sleep Agent Lambda
====================================
Analyses sleep data for a senior citizen using both deterministic rules
and Bedrock AI reasoning.  Generates recommendations and optionally
triggers family alerts for chronic sleep issues.

Trigger : Invoked asynchronously by the Orchestrator Lambda.
Runtime : Python 3.11
"""

from __future__ import annotations

import json
import logging
import os
import sys
from typing import Dict, Any

from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv()

from models.health_payload import HealthPayload
from services.bedrock_client import BedrockClient
from services.health_analyzer import HealthAnalyzer

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = BedrockClient()


# ==============================================================
#  LAMBDA HANDLER
# ==============================================================
def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Sleep Agent entry point.

    Responsibilities
    ----------------
    - Analyse sleep stages, duration, and quality
    - Detect insomnia, poor sleep cycles
    - Generate AI-powered sleep recommendations
    - Flag chronic patterns for family dashboard

    Parameters
    ----------
    event : dict – Health payload forwarded by the Orchestrator.
    """
    logger.info("🌙 Sleep Agent invoked.")

    # ── Parse payload ──────────────────────────
    try:
        health = HealthPayload.from_event(event)
        logger.info("Sleep Agent received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    # ── Deterministic sleep assessment ─────────
    sleep_report = HealthAnalyzer.assess_sleep(health)
    logger.info("Deterministic sleep quality: %s", sleep_report["quality"])

    # ── Bedrock AI sleep analysis ──────────────
    try:
        ai_analysis = bedrock.analyze_sleep(health.to_dict())
        logger.info("Bedrock sleep analysis: %s", ai_analysis)
    except Exception as exc:
        logger.warning("Bedrock sleep analysis failed: %s", exc)
        ai_analysis = {
            "sleep_quality": sleep_report["quality"],
            "risk_factors": ["Bedrock unavailable"],
            "recommendations": ["Monitor sleep patterns manually."],
        }

    # ── Build recommendations ──────────────────
    recommendations = _build_recommendations(health, sleep_report, ai_analysis)

    # ── Compose result ─────────────────────────
    result = {
        "agent": "sleep_agent",
        "user_id": health.user_id,
        "sleep_hours": health.sleep_hours,
        "deterministic_report": sleep_report,
        "ai_analysis": ai_analysis,
        "recommendations": recommendations,
        "alert_family": sleep_report["quality"] == "poor",
    }

    logger.info("🌙 Sleep Agent complete. Quality=%s", sleep_report["quality"])
    return {"statusCode": 200, "body": json.dumps(result, default=str)}


# ==============================================================
#  HELPER: Build actionable recommendations
# ==============================================================
def _build_recommendations(
    health: HealthPayload,
    sleep_report: Dict[str, Any],
    ai_analysis: Dict[str, Any],
) -> list:
    """Merge rule-based and AI recommendations."""
    recs = []

    # Rule-based
    if health.sleep_hours < 4:
        recs.append("⚠️ Critical: Less than 4 hours of sleep. Consider contacting healthcare provider.")
    elif health.sleep_hours < 6:
        recs.append("💤 Sleep below recommended 6 hours. Try establishing a regular bedtime routine.")

    if health.is_heart_rate_abnormal:
        recs.append("❤️ Abnormal heart rate may be affecting sleep quality.")

    # AI-based
    ai_recs = ai_analysis.get("recommendations", [])
    if isinstance(ai_recs, list):
        recs.extend(ai_recs)

    return recs
