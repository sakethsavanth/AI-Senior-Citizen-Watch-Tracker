"""
SeniorCare AI – Amazon Bedrock Client
=======================================
Wraps boto3 bedrock-runtime calls so every agent can invoke Claude
through a single, tested interface.

Usage
-----
    from services.bedrock_client import BedrockClient
    client = BedrockClient()
    result = client.analyze_health(payload.to_dict())
"""

from __future__ import annotations

import json
import logging
import os
from typing import Dict, Any

import boto3
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ── Configuration ──────────────────────────────
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
BEDROCK_MODEL_ID = os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-3-sonnet-20240229-v1:0")
MAX_TOKENS = int(os.getenv("BEDROCK_MAX_TOKENS", "1024"))


class BedrockClient:
    """Reusable Amazon Bedrock client for Claude model invocations."""

    def __init__(self, region: str = AWS_REGION, model_id: str = BEDROCK_MODEL_ID):
        self.model_id = model_id
        self.client = boto3.client("bedrock-runtime", region_name=region)
        logger.info("BedrockClient initialised (model=%s, region=%s)", model_id, region)

    # ──────────────────────────────────────────────
    # Core invocation
    # ──────────────────────────────────────────────
    def invoke(self, system_prompt: str, user_message: str) -> str:
        """
        Send a prompt to Claude via Bedrock and return the text response.

        Parameters
        ----------
        system_prompt : str
            Sets the assistant's persona / context.
        user_message : str
            The actual user query or data payload.

        Returns
        -------
        str  – Raw text response from Claude.
        """
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": MAX_TOKENS,
            "system": system_prompt,
            "messages": [
                {"role": "user", "content": user_message}
            ],
        })

        try:
            response = self.client.invoke_model(
                modelId=self.model_id,
                contentType="application/json",
                accept="application/json",
                body=body,
            )
            result = json.loads(response["body"].read())
            text = result["content"][0]["text"]
            logger.debug("Bedrock response (truncated): %s", text[:200])
            return text

        except Exception as exc:
            logger.error("Bedrock invocation failed: %s", exc, exc_info=True)
            raise

    # ──────────────────────────────────────────────
    # Domain-specific helpers
    # ──────────────────────────────────────────────
    def analyze_health(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Ask Claude to assess overall health risk from wearable data.

        Returns
        -------
        dict with keys:
            risk_level : "low" | "medium" | "high"
            recommended_action : "monitor" | "alert" | "call"
            explanation : str
        """
        system_prompt = (
            "You are a senior-care health AI assistant. "
            "Analyze the following wearable health data for an elderly patient. "
            "Return ONLY valid JSON with these keys: "
            "risk_level (low|medium|high), "
            "recommended_action (monitor|alert|call), "
            "explanation (brief string)."
        )
        user_message = json.dumps(health_data, indent=2)

        raw = self.invoke(system_prompt, user_message)

        # Parse the JSON from Claude's response
        try:
            # Claude may wrap JSON in markdown code fences – strip them
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                cleaned = cleaned.split("\n", 1)[1]
                cleaned = cleaned.rsplit("```", 1)[0]
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning("Could not parse Bedrock JSON; returning default.")
            return {
                "risk_level": "medium",
                "recommended_action": "alert",
                "explanation": raw[:300],
            }

    def analyze_sleep(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """Specialised sleep-quality analysis."""
        system_prompt = (
            "You are a sleep specialist AI. Analyze the sleep data for a senior citizen. "
            "Return ONLY valid JSON with: sleep_quality (good|fair|poor), "
            "risk_factors (list of strings), recommendations (list of strings)."
        )
        return self._invoke_and_parse(system_prompt, health_data)

    def analyze_activity(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """Specialised activity/movement analysis."""
        system_prompt = (
            "You are an elderly mobility specialist AI. Analyze the activity data. "
            "Return ONLY valid JSON with: mobility_status (active|sedentary|critical), "
            "fall_risk (low|medium|high), recommendations (list of strings)."
        )
        return self._invoke_and_parse(system_prompt, health_data)

    def analyze_medication(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """Specialised medication adherence analysis."""
        system_prompt = (
            "You are a pharmacology AI assistant for elderly care. "
            "Analyze the medication data and return ONLY valid JSON with: "
            "adherence_status (on_track|at_risk|missed), "
            "next_reminder (string), recommendations (list of strings)."
        )
        return self._invoke_and_parse(system_prompt, health_data)

    # ── Internal ───────────────────────────────
    def _invoke_and_parse(self, system_prompt: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Invoke Claude with structured data and return parsed JSON."""
        raw = self.invoke(system_prompt, json.dumps(data, indent=2))
        try:
            cleaned = raw.strip()
            if cleaned.startswith("```"):
                cleaned = cleaned.split("\n", 1)[1]
                cleaned = cleaned.rsplit("```", 1)[0]
            return json.loads(cleaned)
        except json.JSONDecodeError:
            logger.warning("JSON parse failed; wrapping raw text.")
            return {"raw_response": raw[:500]}
