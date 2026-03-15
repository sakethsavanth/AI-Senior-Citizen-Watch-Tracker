"""
ElderHarmony – Health Payload Model
====================================
Data contract for health data from wearable (e.g. Whoop) or app.
Vitals are treated as 24-hour period aggregates where applicable.
Supports HRV, fall detection, mood, and optional 24h averages.
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
HRV_LOW_PERCENT = 40                 # HRV recovery / normal % – below = possible infection risk
MISSED_DOSES_REFILL_DAYS = 3         # 3-day miss pattern → auto-refill


@dataclass
class HealthPayload:
    """
    Structured health submission. Vitals (HR, SpO2, HRV) represent
    the last 24-hour period unless otherwise noted (e.g. spot readings).
    """

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

    # ── 24hr / ElderHarmony extensions ─────────
    hrv_percent: Optional[float] = None          # HRV as % of normal (e.g. Whoop recovery)
    fall_detected: bool = False
    mood_score: Optional[float] = None           # 1–5 scale from EmoCare
    heart_rate_avg_24h: Optional[float] = None   # 24h average HR (optional; else use heart_rate)
    spo2_avg_24h: Optional[float] = None        # 24h average SpO2 (optional)
    family_contacts: Optional[list] = None       # [{name, phone, last_contact_iso}]
    medication_taken_today: Optional[dict] = None  # e.g. {"morning": true, "afternoon": false}
    doses_missed_consecutive_days: int = 0      # for 3-day miss → refill

    # ── Factory ────────────────────────────────
    @classmethod
    def from_event(cls, event: Dict[str, Any]) -> "HealthPayload":
        """
        Build from API Gateway proxy event or direct dict.
        Handles both body string and body dict. New fields are optional.
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
            hrv_percent=float(body["hrv_percent"]) if body.get("hrv_percent") is not None else None,
            fall_detected=bool(body.get("fall_detected", False)),
            mood_score=float(body["mood_score"]) if body.get("mood_score") is not None else None,
            heart_rate_avg_24h=float(body["heart_rate_avg_24h"]) if body.get("heart_rate_avg_24h") is not None else None,
            spo2_avg_24h=float(body["spo2_avg_24h"]) if body.get("spo2_avg_24h") is not None else None,
            family_contacts=body.get("family_contacts"),
            medication_taken_today=body.get("medication_taken_today"),
            doses_missed_consecutive_days=int(body.get("doses_missed_consecutive_days", 0)),
        )

    # ── 24hr vitals (use averages when present) ─
    @property
    def heart_rate_24h(self) -> float:
        """Heart rate for 24hr period: avg if provided, else spot."""
        return self.heart_rate_avg_24h if self.heart_rate_avg_24h is not None else self.heart_rate

    @property
    def spo2_24h(self) -> float:
        """SpO2 for 24hr period: avg if provided, else spot."""
        return self.spo2_avg_24h if self.spo2_avg_24h is not None else self.spo2

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
        hr = self.heart_rate_24h
        return hr < HEART_RATE_LOW or hr > HEART_RATE_HIGH

    @property
    def is_spo2_low(self) -> bool:
        return self.spo2_24h < SPO2_LOW_THRESHOLD

    @property
    def is_hrv_low(self) -> bool:
        """HRV below 40% normal → possible infection / doctor visit."""
        return self.hrv_percent is not None and self.hrv_percent < HRV_LOW_PERCENT

    @property
    def needs_refill_3day_miss(self) -> bool:
        """3-day miss pattern → auto-refill."""
        return self.doses_missed_consecutive_days >= MISSED_DOSES_REFILL_DAYS

    @property
    def is_mood_low(self) -> bool:
        """EmoCare: score < 3 → trigger call."""
        return self.mood_score is not None and self.mood_score < 3.0

    # ── Serialisation ──────────────────────────
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict())

    def summary(self) -> str:
        """Human-readable one-liner for logs."""
        parts = [
            f"[user={self.user_id}] HR={self.heart_rate_24h:.0f} SpO2={self.spo2_24h:.0f}",
            f"Steps={self.steps} Sleep={self.sleep_hours}h Pills={self.pill_count} Idle={self.last_movement_minutes}min",
        ]
        if self.hrv_percent is not None:
            parts.append(f"HRV={self.hrv_percent:.0f}%")
        if self.fall_detected:
            parts.append("FALL")
        if self.mood_score is not None:
            parts.append(f"Mood={self.mood_score}/5")
        return " ".join(parts)
