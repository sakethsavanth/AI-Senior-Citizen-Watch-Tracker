"""
ElderHarmony – Whoop API to Health Payload Adapter
===================================================
Maps Whoop API responses (recovery, sleep, cycle) to our HealthPayload-compatible
dict. Use when ingesting real Whoop data (e.g. from whoop_sdk or Whoop API v2).

See data/synthetic/VITALS_SPEC.md for field mapping.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional


def _parse_sleep_duration_hours(stage_summary: Optional[Dict[str, Any]]) -> float:
    """Convert Whoop stage_summary to total sleep hours. Fallback 6.0."""
    if not stage_summary:
        return 6.0
    # Whoop may give total_sleep_time_seconds or stage durations in ms
    total_sec = stage_summary.get("total_sleep_time_seconds")
    if total_sec is not None:
        return round(total_sec / 3600.0, 1)
    # Fallback: sum of stages if in seconds
    for key in ("in_bed_time_seconds", "total_in_bed_time_seconds"):
        if key in stage_summary and stage_summary[key]:
            return round(stage_summary[key] / 3600.0, 1)
    return 6.0


def build_health_payload_from_whoop(
    user_id: str,
    recovery: Optional[Dict[str, Any]] = None,
    sleep: Optional[Dict[str, Any]] = None,
    cycle: Optional[Dict[str, Any]] = None,
    *,
    steps: Optional[int] = None,
    last_movement_minutes: Optional[int] = None,
    pill_count: int = 10,
    fall_detected: bool = False,
    mood_score: Optional[float] = None,
    medication_name: str = "Blood Pressure",
    emergency_contact: Optional[str] = None,
    family_contacts: Optional[list] = None,
    medication_taken_today: Optional[Dict[str, bool]] = None,
    doses_missed_consecutive_days: int = 0,
) -> Dict[str, Any]:
    """
    Build a HealthPayload-compatible dict from Whoop API objects.

    Whoop Recovery (when score_state == 'SCORED'):
      - score.recovery_score (0–100) → hrv_percent
      - score.resting_heart_rate → heart_rate, heart_rate_avg_24h
      - score.spo2_percentage → spo2, spo2_avg_24h

    Whoop Sleep:
      - stage_summary (total sleep time) → sleep_hours

    Whoop Cycle:
      - average_heart_rate → heart_rate_avg_24h (overrides recovery RHR for 24h)

    Steps and last_movement_minutes are NOT from Whoop; pass from app or synthetic.
    """
    now = datetime.now(timezone.utc).isoformat()
    payload = {
        "user_id": user_id,
        "timestamp": now,
        "heart_rate": 72.0,
        "spo2": 97.0,
        "steps": steps if steps is not None else 3000,
        "sleep_hours": 6.0,
        "pill_count": pill_count,
        "last_movement_minutes": last_movement_minutes if last_movement_minutes is not None else 60,
        "medication_name": medication_name,
        "emergency_contact": emergency_contact,
        "hrv_percent": None,
        "heart_rate_avg_24h": None,
        "spo2_avg_24h": None,
        "fall_detected": fall_detected,
        "mood_score": mood_score,
        "family_contacts": family_contacts,
        "medication_taken_today": medication_taken_today or {},
        "doses_missed_consecutive_days": doses_missed_consecutive_days,
    }

    if recovery:
        rec = recovery.get("score") or recovery
        if isinstance(rec, dict):
            rhr = rec.get("resting_heart_rate")
            if rhr is not None:
                payload["heart_rate"] = float(rhr)
                payload["heart_rate_avg_24h"] = float(rhr)
            spo2 = rec.get("spo2_percentage")
            if spo2 is not None:
                payload["spo2"] = float(spo2)
                payload["spo2_avg_24h"] = float(spo2)
            recovery_score = rec.get("recovery_score")
            if recovery_score is not None:
                payload["hrv_percent"] = float(recovery_score)

    if cycle:
        avg_hr = cycle.get("average_heart_rate")
        if avg_hr is not None:
            payload["heart_rate_avg_24h"] = float(avg_hr)
            if payload.get("heart_rate") == 72.0:  # default
                payload["heart_rate"] = float(avg_hr)

    if sleep:
        stage = sleep.get("score") or sleep.get("stage_summary") or sleep
        if isinstance(stage, dict):
            payload["sleep_hours"] = _parse_sleep_duration_hours(stage)
        elif isinstance(sleep.get("stage_summary"), dict):
            payload["sleep_hours"] = _parse_sleep_duration_hours(sleep["stage_summary"])

    return payload
