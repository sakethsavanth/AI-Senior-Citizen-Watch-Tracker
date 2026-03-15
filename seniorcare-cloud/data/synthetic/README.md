# Synthetic Health Data (ElderHarmony)

Synthetic vitals and personas for **testing** and **demos** without real Whoop or device data.

## Contents

| Item | Description |
|------|-------------|
| **VITALS_SPEC.md** | Which vitals we need, units, and **Whoop API mapping** |
| **personas.json** | Elderly personas (user_id, name, contacts, medication) |
| **scenarios/** | One JSON per scenario: health_data for a single “day” or multi-day |

## Scenarios

| File | Purpose |
|------|--------|
| `normal_day.json` | Stable vitals; no alerts |
| `critical_alert.json` | High HR, low SpO2, long inactivity, missed doses → demo emergency/calling |
| `fall_detected.json` | `fall_detected: true` → emergency escalation |
| `low_mood.json` | Mood 2/5, low steps → EmoCare + Calling |
| `refill_needed.json` | Low pills + 3-day miss → Refill agent |
| `poor_sleep.json` | Sleep <4h → Sleep agent + alert family |
| `inactivity_critical.json` | No movement >6h → Activity + Calling |
| `low_hrv.json` | HRV <40% → VitalSync doctor nudge |
| `declining_week.json` | 7 days of declining vitals → weekly summary / trend demos |

## Usage (Python)

```python
from data.synthetic_db import SyntheticHealthDB
import json
from models.health_payload import HealthPayload

db = SyntheticHealthDB()

# One payload for API / Lambda
payload = db.get_payload_for_api_event("senior_001", "critical_alert")
event = {"body": json.dumps(payload)}
health = HealthPayload.from_event(event)

# List scenarios and personas
print(db.list_scenarios())
print(db.list_personas())

# Multi-day (e.g. declining_week)
for day_payload in db.get_week_payloads("senior_001", "declining_week"):
    print(day_payload["timestamp"], day_payload["sleep_hours"], day_payload["hrv_percent"])
```

## Whoop mapping

When using **real Whoop** data, use the adapter so recovery/sleep/cycle map into the same payload shape:

```python
from data.whoop_adapter import build_health_payload_from_whoop

# After fetching recovery, sleep, cycle from Whoop API
payload = build_health_payload_from_whoop(
    user_id="senior_001",
    recovery=whoop_recovery_record,
    sleep=whoop_sleep_record,
    cycle=whoop_cycle_record,
    steps=2500,  # from app or synthetic
    last_movement_minutes=45,
    pill_count=8,
    emergency_contact="+14165551234",
)
```

See **VITALS_SPEC.md** for full field list and Whoop → ElderHarmony mapping.
