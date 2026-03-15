"""
ElderHarmony – Synthetic Health Database
=========================================
Loads synthetic vitals and personas for testing and demos. Simulates health
readings for elderly users; compatible with HealthPayload.from_event().

Usage:
    from data.synthetic_db import SyntheticHealthDB
    db = SyntheticHealthDB()
    payload = db.get_payload("senior_001", "critical_alert")
    event = {"body": json.dumps(payload)}
    health = HealthPayload.from_event(event)
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# Base path for synthetic data (this file lives in data/, synthetic/ is data/synthetic/)
_DATA_DIR = Path(__file__).resolve().parent / "synthetic"
_SCENARIOS_DIR = _DATA_DIR / "scenarios"


class SyntheticHealthDB:
    """
    In-memory "database" of synthetic health payloads and personas.
    Use for tests and demos without real Whoop or device data.
    """

    def __init__(self, data_dir: Optional[Path] = None, scenarios_dir: Optional[Path] = None):
        self.data_dir = data_dir or _DATA_DIR
        self.scenarios_dir = scenarios_dir or _SCENARIOS_DIR
        self._personas: Optional[Dict[str, Dict[str, Any]]] = None
        self._scenarios: Dict[str, Dict[str, Any]] = {}

    def _load_personas(self) -> Dict[str, Dict[str, Any]]:
        if self._personas is not None:
            return self._personas
        path = self.data_dir / "personas.json"
        if not path.exists():
            logger.warning("personas.json not found at %s", path)
            self._personas = {}
            return self._personas
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self._personas = {p["user_id"]: p for p in data.get("personas", [])}
        return self._personas

    def _load_scenario(self, scenario_id: str) -> Dict[str, Any]:
        if scenario_id in self._scenarios:
            return self._scenarios[scenario_id]
        path = self.scenarios_dir / f"{scenario_id}.json"
        if not path.exists():
            raise FileNotFoundError(f"Scenario not found: {scenario_id} at {path}")
        with open(path, encoding="utf-8") as f:
            self._scenarios[scenario_id] = json.load(f)
        return self._scenarios[scenario_id]

    def get_persona(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Return persona for user_id (name, contacts, medication_name, etc.)."""
        return self._load_personas().get(user_id)

    def list_personas(self) -> List[Dict[str, Any]]:
        """Return all personas."""
        return list(self._load_personas().values())

    def list_scenarios(self) -> List[str]:
        """Return scenario IDs (from filenames in scenarios/)."""
        if not self.scenarios_dir.exists():
            return []
        return [p.stem for p in self.scenarios_dir.glob("*.json")]

    def get_payload(
        self,
        user_id: str,
        scenario_id: str,
        timestamp: Optional[str] = None,
        include_persona: bool = True,
    ) -> Dict[str, Any]:
        """
        Build a full health payload (ready for HealthPayload.from_event(body=...)).

        Merges scenario health_data with persona (emergency_contact, family_contacts,
        medication_name). Use include_persona=False to get only scenario health_data
        with user_id and timestamp set.
        """
        scenario = self._load_scenario(scenario_id)

        # Single-day scenario
        if "health_data" in scenario:
            health = dict(scenario["health_data"])
        # Multi-day (e.g. declining_week): use last day as "current"
        elif "days" in scenario:
            days = scenario["days"]
            health = dict(days[-1]) if days else {}
            health.setdefault("medication_taken_today", scenario.get("medication_taken_today"))
            health.setdefault("doses_missed_consecutive_days", scenario.get("doses_missed_consecutive_days", 0))
            health.setdefault("pill_count", 5)
        else:
            health = {}

        health["user_id"] = user_id
        health["timestamp"] = timestamp or datetime.now(timezone.utc).isoformat()

        if include_persona:
            persona = self.get_persona(user_id)
            if persona:
                health.setdefault("medication_name", persona.get("medication_name", "Blood Pressure"))
                health.setdefault("emergency_contact", persona.get("emergency_contact"))
                health.setdefault("family_contacts", persona.get("family_contacts"))

        return health

    def get_payload_for_api_event(
        self,
        user_id: str,
        scenario_id: str,
        timestamp: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Return a dict suitable for API Gateway event body (string or dict).
        Use: event = {"body": json.dumps(db.get_payload_for_api_event("senior_001", "critical_alert"))}
        """
        return self.get_payload(user_id, scenario_id, timestamp=timestamp, include_persona=True)

    def get_week_payloads(
        self,
        user_id: str,
        scenario_id: str = "declining_week",
        include_persona: bool = True,
    ) -> List[Dict[str, Any]]:
        """
        For multi-day scenarios (e.g. declining_week), return one payload per day.
        Each payload has user_id, timestamp (date noon UTC), and that day's health_data.
        """
        scenario = self._load_scenario(scenario_id)
        if "days" not in scenario:
            single = self.get_payload(user_id, scenario_id, include_persona=include_persona)
            return [single]

        personas = self._load_personas() if include_persona else {}
        persona = personas.get(user_id) or {}

        out = []
        for day in scenario["days"]:
            health = dict(day)
            health["user_id"] = user_id
            date_str = health.pop("date", "2026-03-15")
            health["timestamp"] = f"{date_str}T12:00:00+00:00"
            health.setdefault("medication_taken_today", scenario.get("medication_taken_today"))
            health.setdefault("doses_missed_consecutive_days", scenario.get("doses_missed_consecutive_days", 0))
            health.setdefault("pill_count", 10)
            if include_persona and persona:
                health.setdefault("medication_name", persona.get("medication_name", "Blood Pressure"))
                health.setdefault("emergency_contact", persona.get("emergency_contact"))
                health.setdefault("family_contacts", persona.get("family_contacts"))
            out.append(health)
        return out


def whoop_recovery_to_health_data(
    user_id: str,
    recovery: Dict[str, Any],
    sleep_hours: Optional[float] = None,
    steps: Optional[int] = None,
    last_movement_minutes: Optional[int] = None,
    pill_count: int = 10,
    fall_detected: bool = False,
    mood_score: Optional[float] = None,
    medication_taken_today: Optional[Dict[str, bool]] = None,
    doses_missed_consecutive_days: int = 0,
) -> Dict[str, Any]:
    """
    Map a Whoop Recovery (and optional sleep/cycle) object to our health payload shape.

    Whoop recovery typically has: score (recovery_score 0-100), resting_heart_rate,
    hrv_rmssd_milli, spo2_percentage. Use this when you have real Whoop API data.
    """
    score = recovery.get("score") or {}
    return {
        "user_id": user_id,
        "heart_rate": float(score.get("resting_heart_rate", 72)),
        "spo2": float(score.get("spo2_percentage", 97)),
        "heart_rate_avg_24h": float(score.get("resting_heart_rate", 72)),
        "spo2_avg_24h": float(score.get("spo2_percentage", 97)),
        "hrv_percent": float(score.get("recovery_score", 66)),
        "sleep_hours": sleep_hours if sleep_hours is not None else 6.5,
        "steps": steps if steps is not None else 3000,
        "last_movement_minutes": last_movement_minutes if last_movement_minutes is not None else 60,
        "pill_count": pill_count,
        "fall_detected": fall_detected,
        "mood_score": mood_score,
        "medication_taken_today": medication_taken_today or {},
        "doses_missed_consecutive_days": doses_missed_consecutive_days,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
