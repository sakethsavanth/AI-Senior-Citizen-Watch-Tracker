"""
SeniorCare AI – Health Payload Model
=====================================
Defines the data contract for incoming health data from the Android wearable app.
Provides validation, serialization, and risk-flag helpers.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# Threshold constants (clinical defaults)
# ──────────────────────────────────────────────
SLEEP_LOW_THRESHOLD = 6.0            # hours
INACTIVITY_HIGH_THRESHOLD = 240      # minutes (4 hours)
PILL_LOW_THRESHOLD = 3               # remaining count
HEART_RATE_LOW = 50                  # bpm
HEART_RATE_HIGH = 120                # bpm
SPO2_LOW_THRESHOLD = 92              # percent


@dataclass
class HealthPayload:
    """Structured representation of a single health-data submission."""

    user_id: str
    heart_rate: float
    spo2: float
    steps: int
    sleep_hours: float
    pill_count: int
    last_movement_minutes: int
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    medication_name: Optional[str] = "Blood Pressure"
    emergency_contact: Optional[str] = None

    # ── Factory ────────────────────────────────
    @classmethod
    def from_event(cls, event: Dict[str, Any]) -> "HealthPayload":
        """
        Build a HealthPayload from an API Gateway proxy event.
        Handles both direct dict payloads and stringified JSON bodies.
        """
        body = event
        if isinstance(event.get("body"), str):
            body = json.loads(event["body"])
        elif isinstance(event.get("body"), dict):
            body = event["body"]

        required_fields = [
            "user_id", "heart_rate", "spo2",
            "steps", "sleep_hours", "pill_count",
            "last_movement_minutes",
        ]
        missing = [f for f in required_fields if f not in body]
        if missing:
            raise ValueError(f"Missing required fields: {missing}")

        return cls(
            user_id=str(body["user_id"]),
            heart_rate=float(body["heart_rate"]),
            spo2=float(body["spo2"]),
            steps=int(body["steps"]),
            sleep_hours=float(body["sleep_hours"]),
            pill_count=int(body["pill_count"]),
            last_movement_minutes=int(body["last_movement_minutes"]),
            timestamp=body.get("timestamp", datetime.now(timezone.utc).isoformat()),
            medication_name=body.get("medication_name", "Blood Pressure"),
            emergency_contact=body.get("emergency_contact"),
        )

    # ── Risk Flags ─────────────────────────────
    @property
    def is_sleep_deficit(self) -> bool:
        return self.sleep_hours < SLEEP_LOW_THRESHOLD

    @property
    def is_inactive(self) -> bool:
        return self.last_movement_minutes > INACTIVITY_HIGH_THRESHOLD

    @property
    def is_pill_low(self) -> bool:
        return self.pill_count < PILL_LOW_THRESHOLD

    @property
    def is_heart_rate_abnormal(self) -> bool:
        return self.heart_rate < HEART_RATE_LOW or self.heart_rate > HEART_RATE_HIGH

    @property
    def is_spo2_low(self) -> bool:
        return self.spo2 < SPO2_LOW_THRESHOLD

    # ── Serialisation ──────────────────────────
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict())

    def summary(self) -> str:
        """Human-readable one-liner for logs."""
        return (
            f"[user={self.user_id}] HR={self.heart_rate} SpO2={self.spo2} "
            f"Steps={self.steps} Sleep={self.sleep_hours}h "
            f"Pills={self.pill_count} Idle={self.last_movement_minutes}min"
        )
