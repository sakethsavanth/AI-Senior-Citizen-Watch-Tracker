# ElderHarmony – Architecture & Triggers

## 5-Agent System (aligned with ProjectIdea.md)

```
                    [ORCHESTRATOR]
                         |
    ┌────────────────────┼────────────────────┐
    |                    |                    |
[VitalSync]      [Medicine]      [EmoCare]   [Calling]   [HealthRecords]
```

- **VitalSync** – 24hr vitals (HR, SpO2, HRV), daily guardian. 7AM walk reminder, 9PM sleep. HRV < 40% → doctor; fall → emergency.
- **Medicine** – Schedule 8AM, 12PM, 6PM, 9PM. Voice reminder + confirmation. Low pills or 3-day miss → auto-refill (Pharmacy API).
- **EmoCare** – Mood 1–5. Score < 3 → trigger Calling. Walk reminder, “Let’s call Sarah.”
- **Calling** – Welfare/emergency calls (Twilio). Smart rotation: `family_contacts` → least-contacted first. Triggers: fall, vitals, AI risk, EmoCare low mood.
- **HealthRecords** – Passive: med interaction warnings, lab summary, visit prep (mock; plug in pharmacy/doctor APIs).

**Vitals = 24hr period.** Payload can send spot values and/or `heart_rate_avg_24h`, `spo2_avg_24h`, `hrv_percent` for the last 24 hours.

---

## How triggering works (no cron)

1. **Entry:** Wearable/app **POST /health-data** → API Gateway → **Orchestrator**.
2. Orchestrator parses payload (24hr vitals), runs **HealthAnalyzer** + **OpenRouter**, then **event_router** decides which agents to invoke.
3. Each selected agent Lambda is invoked **asynchronously** (`InvocationType="Event"`). No scheduled cron; everything is event-driven per request.

Medication windows (8/12/18/21) are evaluated **when a payload is received** (e.g. wearable sends data hourly); for fixed-time reminders you’d add EventBridge rules (see below).

---

## EventBridge (cron-style) options

| Use case | Trigger | What runs |
|----------|--------|-----------|
| No-data check | Every 15 min | Lambda checks last payload time (e.g. DynamoDB); if > 2h → invoke Calling. |
| Medicine reminders | 8:00, 12:00, 18:00, 21:00 | Lambda invokes Medicine Agent for users in that window. |
| Daily vitals summary | 06:00 / 21:00 | Lambda runs VitalSync logic and sends “24hr summary” to family. |

---

## Payload (24hr vitals)

Required: `user_id`, `heart_rate`, `spo2`, `steps`, `sleep_hours`, `pill_count`, `last_movement_minutes`.

Optional (ElderHarmony): `hrv_percent`, `fall_detected`, `mood_score`, `heart_rate_avg_24h`, `spo2_avg_24h`, `family_contacts` (list of `{name, phone, last_contact_iso}`), `medication_taken_today`, `doses_missed_consecutive_days`, `medication_name`, `emergency_contact`.

When `*_avg_24h` or `hrv_percent` are present, routing and alerts use these for the 24hr period.

---

## Env vars (Orchestrator)

- `VITAL_SYNC_AGENT_ARN`, `MEDICINE_AGENT_ARN`, `EMO_CARE_AGENT_ARN`, `CALLING_AGENT_ARN`, `HEALTH_RECORDS_AGENT_ARN`
- `AWS_REGION`, OpenRouter/Twilio/Pharmacy as needed per agent

---

## Summary

| Question | Answer |
|----------|--------|
| Cron/loop? | **No.** All agent runs are triggered by the Orchestrator on each /health-data POST. |
| 24hr vitals? | **Yes.** Use `heart_rate_avg_24h`, `spo2_avg_24h`, `hrv_percent`; otherwise spot values are used. |
| Fixed-time reminders? | Add **EventBridge** rules that invoke the relevant Lambdas on a schedule. |
