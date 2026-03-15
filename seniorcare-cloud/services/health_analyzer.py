"""
ElderHarmony – Health Analyzer
===============================
Deterministic rule-based assessments: vitals (24hr), sleep, activity,
HRV, fall, medication. Complements OpenRouter AI analysis.
"""

from __future__ import annotations

import logging
from typing import Dict, Any, List

from models.health_payload import (
    HealthPayload,
    SLEEP_LOW_THRESHOLD,
    INACTIVITY_HIGH_THRESHOLD,
    PILL_LOW_THRESHOLD,
    HEART_RATE_LOW,
    HEART_RATE_HIGH,
    SPO2_LOW_THRESHOLD,
    HRV_LOW_PERCENT,
)

logger = logging.getLogger(__name__)


class HealthAnalyzer:
    """Stateless, deterministic health-risk engine. Vitals = 24hr period."""

    # ──────────────────────────────────────────────
    # Individual assessments (24hr vitals where applicable)
    # ──────────────────────────────────────────────
    @staticmethod
    def assess_vitals(health: HealthPayload) -> Dict[str, Any]:
        """Check heart rate and SpO2 (24hr) against clinical thresholds."""
        issues: List[str] = []
        hr = health.heart_rate_24h
        spo2 = health.spo2_24h

        if hr < HEART_RATE_LOW:
            issues.append(f"Bradycardia: HR={hr} bpm (< {HEART_RATE_LOW})")
        elif hr > HEART_RATE_HIGH:
            issues.append(f"Tachycardia: HR={hr} bpm (> {HEART_RATE_HIGH})")

        if spo2 < SPO2_LOW_THRESHOLD:
            issues.append(f"Hypoxemia: SpO2={spo2}% (< {SPO2_LOW_THRESHOLD}%)")

        return {
            "category": "vitals",
            "heart_rate": hr,
            "spo2": spo2,
            "period": "24h",
            "status": "critical" if issues else "normal",
            "issues": issues,
        }

    @staticmethod
    def assess_hrv(health: HealthPayload) -> Dict[str, Any]:
        """HRV as % of normal. < 40% → possible infection / doctor visit."""
        hrv = health.hrv_percent
        if hrv is None:
            return {
                "category": "hrv",
                "hrv_percent": None,
                "status": "unknown",
                "below_threshold": False,
            }
        return {
            "category": "hrv",
            "hrv_percent": hrv,
            "status": "low" if health.is_hrv_low else "normal",
            "below_threshold": health.is_hrv_low,
        }

    @staticmethod
    def assess_fall(health: HealthPayload) -> Dict[str, Any]:
        """Fall detection → emergency."""
        return {
            "category": "fall",
            "fall_detected": health.fall_detected,
            "status": "critical" if health.fall_detected else "normal",
        }

    @staticmethod
    def assess_sleep(health: HealthPayload) -> Dict[str, Any]:
        """Evaluate sleep quality from duration."""
        if health.sleep_hours < 4:
            quality = "poor"
        elif health.sleep_hours < SLEEP_LOW_THRESHOLD:
            quality = "fair"
        else:
            quality = "good"

        return {
            "category": "sleep",
            "sleep_hours": health.sleep_hours,
            "quality": quality,
            "below_threshold": health.is_sleep_deficit,
        }

    @staticmethod
    def assess_activity(health: HealthPayload) -> Dict[str, Any]:
        """Evaluate mobility and inactivity risk."""
        if health.last_movement_minutes > 360:
            status = "critical"
        elif health.last_movement_minutes > INACTIVITY_HIGH_THRESHOLD:
            status = "sedentary"
        else:
            status = "active"

        return {
            "category": "activity",
            "steps": health.steps,
            "last_movement_minutes": health.last_movement_minutes,
            "status": status,
            "inactive_flag": health.is_inactive,
        }

    @staticmethod
    def assess_medication(health: HealthPayload) -> Dict[str, Any]:
        """Evaluate medication inventory and 3-day miss → refill."""
        if health.pill_count == 0:
            status = "depleted"
        elif health.pill_count < PILL_LOW_THRESHOLD:
            status = "low"
        else:
            status = "sufficient"

        return {
            "category": "medication",
            "pill_count": health.pill_count,
            "medication_name": health.medication_name,
            "status": status,
            "refill_needed": health.is_pill_low,
            "refill_3day_miss": health.needs_refill_3day_miss,
        }

    @staticmethod
    def assess_mood(health: HealthPayload) -> Dict[str, Any]:
        """EmoCare: mood 1–5. < 3 → trigger call."""
        score = health.mood_score
        if score is None:
            return {"category": "mood", "mood_score": None, "status": "unknown", "low_mood": False}
        return {
            "category": "mood",
            "mood_score": score,
            "status": "low" if health.is_mood_low else "ok",
            "low_mood": health.is_mood_low,
        }

    # ──────────────────────────────────────────────
    # Composite assessment
    # ──────────────────────────────────────────────
    @classmethod
    def full_assessment(cls, health: HealthPayload) -> Dict[str, Any]:
        """
        Run all assessments. Vitals = 24hr period. Includes HRV, fall, mood.
        """
        assessments = [
            cls.assess_vitals(health),
            cls.assess_hrv(health),
            cls.assess_fall(health),
            cls.assess_sleep(health),
            cls.assess_activity(health),
            cls.assess_medication(health),
            cls.assess_mood(health),
        ]

        critical_flags = []
        for a in assessments:
            if a.get("category") == "mood" and a.get("low_mood"):
                critical_flags.append("mood")
            elif a.get("status") in ("critical", "poor", "depleted"):
                critical_flags.append(a["category"])
            if a.get("issues"):
                critical_flags.extend(a["issues"])

        if health.fall_detected:
            critical_flags.append("fall")

        if len(critical_flags) >= 2 or health.fall_detected:
            overall_risk = "high"
        elif len(critical_flags) == 1:
            overall_risk = "medium"
        else:
            overall_risk = "low"

        report = {
            "user_id": health.user_id,
            "overall_risk": overall_risk,
            "assessments": assessments,
            "critical_flags": critical_flags,
        }

        logger.info("Health assessment: risk=%s flags=%s", overall_risk, critical_flags)
        return report
