"""
ElderHarmony – EmoCare Agent (Mental Wellness)
================================================
Proactive mood check (scale 1–5). Score < 3 → trigger Calling Agent.
Walk reminder, "Let's call Sarah", music therapy if isolated 72hrs (stub).
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
    EmoCare: mood 1–5, recommendations. Low mood → trigger_call=True
    (orchestrator already routes to Calling when mood low).
    """
    logger.info("😊 EmoCare Agent invoked.")

    try:
        health = HealthPayload.from_event(event)
        logger.info("EmoCare received: %s", health.summary())
    except Exception as exc:
        logger.error("Payload parse error: %s", exc)
        return {"statusCode": 400, "body": json.dumps({"error": str(exc)})}

    mood_report = HealthAnalyzer.assess_mood(health)

    # ── Bedrock: mood interpretation, suggest call, walk reminder ─
    try:
        ai_analysis = bedrock.analyze_mood(health.to_dict())
    except Exception as exc:
        logger.warning("Bedrock mood analysis failed: %s", exc)
        ai_analysis = {
            "mood_interpretation": "Mood data received.",
            "suggest_call": health.is_mood_low,
            "walk_reminder": health.steps < 1000,
            "recommendations": ["Stay connected with family."] if health.is_mood_low else [],
        }

    # ── Recommendations ────────────────────────
    recommendations = list(ai_analysis.get("recommendations") or [])
    if health.is_mood_low:
        recommendations.insert(0, "Let's call a family member – triggering Calling Agent.")
    if health.steps < 1000:
        recommendations.append("Fresh air helps! Consider a 10-minute stroll.")

    trigger_call = health.is_mood_low or ai_analysis.get("suggest_call")

    result = {
        "agent": "emo_care_agent",
        "user_id": health.user_id,
        "mood_score": health.mood_score,
        "deterministic_report": mood_report,
        "ai_analysis": ai_analysis,
        "recommendations": recommendations,
        "trigger_call": trigger_call,
        "insight": f"Mood {'low' if health.is_mood_low else 'stable'}. " + (ai_analysis.get("mood_interpretation") or ""),
    }
    logger.info("😊 EmoCare complete. trigger_call=%s", trigger_call)
    return {"statusCode": 200, "body": json.dumps(result, default=str)}
