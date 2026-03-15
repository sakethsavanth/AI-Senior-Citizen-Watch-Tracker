"""
SeniorCare AI – OpenRouter Client
=================================
Provides a single Claude invocation interface via OpenRouter.

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

import requests
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# ── Configuration ──────────────────────────────
OPENROUTER_API_URL = os.getenv("OPENROUTER_API_URL", "https://openrouter.ai/api/v1/chat/completions")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "anthropic/claude-sonnet-4.5")
MAX_TOKENS = int(os.getenv("OPENROUTER_MAX_TOKENS", os.getenv("BEDROCK_MAX_TOKENS", "1024")))
OPENROUTER_REFERER = os.getenv("OPENROUTER_REFERER", "")
OPENROUTER_APP_TITLE = os.getenv("OPENROUTER_APP_TITLE", "SeniorCare AI")


class OpenRouterClient:
    """Reusable OpenRouter client for Claude model invocations."""

    def __init__(self, model_id: str = OPENROUTER_MODEL):
        self.api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY is required to call OpenRouter")

        self.model_id = model_id
        self.api_url = OPENROUTER_API_URL
        self.session = requests.Session()
        logger.info("OpenRouterClient initialised (model=%s)", model_id)

    # ──────────────────────────────────────────────
    # Core invocation
    # ──────────────────────────────────────────────
    def invoke(self, system_prompt: str, user_message: str) -> str:
        """
        Send a prompt to Claude via OpenRouter and return the text response.

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
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        if OPENROUTER_REFERER:
            headers["HTTP-Referer"] = OPENROUTER_REFERER
        if OPENROUTER_APP_TITLE:
            headers["X-Title"] = OPENROUTER_APP_TITLE

        payload = {
            "model": self.model_id,
            "max_tokens": MAX_TOKENS,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
        }

        try:
            response = self.session.post(
                self.api_url,
                headers=headers,
                json=payload,
                timeout=60,
            )
            response.raise_for_status()
            result = response.json()
            message = result.get("choices", [{}])[0].get("message", {})
            content = message.get("content", "")

            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = "".join(block.get("text", "") for block in content if isinstance(block, dict))
            else:
                text = str(content)

            logger.debug("OpenRouter response (truncated): %s", text[:200])
            return text

        except Exception as exc:
            logger.error("OpenRouter invocation failed: %s", exc, exc_info=True)
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
            logger.warning("Could not parse model JSON; returning default.")
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

    def analyze_vitals_24h(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """VitalSync: 24hr vitals (HR, SpO2, HRV), daily summary, fall risk."""
        system_prompt = (
            "You are a senior vital-signs specialist. The data is for the last 24 hours. "
            "Return ONLY valid JSON with: vital_status (normal|caution|critical), "
            "hrv_interpretation (string), daily_message (e.g. morning walk reminder or evening sleep well), "
            "recommendations (list of strings)."
        )
        return self._invoke_and_parse(system_prompt, health_data)

    def analyze_mood(self, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """EmoCare: mood 1–5, social isolation, suggestions (call family, walk)."""
        system_prompt = (
            "You are an elderly mental wellness AI. Analyze mood and social context. "
            "Return ONLY valid JSON with: mood_interpretation (string), "
            "suggest_call (boolean), walk_reminder (boolean), recommendations (list of strings)."
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


class BedrockClient(OpenRouterClient):
    """Backwards-compatible alias for legacy imports."""
