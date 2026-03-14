"""
SeniorCare AI – Health Analyzer
=================================
Pure-logic health analysis utilities.  Provides deterministic rule-based
assessments that complement the AI-based Bedrock analysis.

Usage
-----
    from services.health_analyzer import HealthAnalyzer
    report = HealthAnalyzer.full_assessment(payload)
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
)

logger = logging.getLogger(__name__)


class HealthAnalyzer:
    """Stateless, deterministic health-risk engine."""

    # ──────────────────────────────────────────────
    # Individual assessments
    # ──────────────────────────────────────────────
    @staticmethod
    def assess_vitals(health: HealthPayload) -> Dict[str, Any]:
        """Check heart rate and SpO2 against clinical thresholds."""
        issues: List[str] = []

        if health.heart_rate < HEART_RATE_LOW:
            issues.append(f"Bradycardia: HR={health.heart_rate} bpm (< {HEART_RATE_LOW})")
        elif health.heart_rate > HEART_RATE_HIGH:
            issues.append(f"Tachycardia: HR={health.heart_rate} bpm (> {HEART_RATE_HIGH})")

        if health.spo2 < SPO2_LOW_THRESHOLD:
            issues.append(f"Hypoxemia: SpO2={health.spo2}% (< {SPO2_LOW_THRESHOLD}%)")

        return {
            "category": "vitals",
            "heart_rate": health.heart_rate,
            "spo2": health.spo2,
            "status": "critical" if issues else "normal",
            "issues": issues,
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
        """Evaluate medication inventory."""
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
        }

    # ──────────────────────────────────────────────
    # Composite assessment
    # ──────────────────────────────────────────────
    @classmethod
    def full_assessment(cls, health: HealthPayload) -> Dict[str, Any]:
        """
        Run all individual assessments and compute an aggregate risk level.

        Returns
        -------
        dict with keys: overall_risk, assessments (list), critical_flags (list)
        """
        assessments = [
            cls.assess_vitals(health),
            cls.assess_sleep(health),
            cls.assess_activity(health),
            cls.assess_medication(health),
        ]

        critical_flags = []
        for a in assessments:
            if a.get("status") in ("critical", "poor", "depleted"):
                critical_flags.append(a["category"])
            if a.get("issues"):
                critical_flags.extend(a["issues"])

        # Determine overall risk
        if len(critical_flags) >= 2:
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
