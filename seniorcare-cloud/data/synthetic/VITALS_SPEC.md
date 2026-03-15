# ElderHarmony Vitals Spec & Whoop Mapping

Vitals required for senior health monitoring and how they map from **Whoop** API (recovery, sleep, cycle) and other sources.

---

## 1. Vitals We Need (ElderHarmony / HealthPayload)

| Field | Type | Unit / Scale | Required | Source | Clinical use |
|-------|------|--------------|----------|--------|--------------|
| **user_id** | string | — | Yes | App / auth | Identity |
| **heart_rate** | float | bpm | Yes | Whoop RHR or cycle avg | Bradycardia (<50), tachycardia (>120) |
| **spo2** | float | % | Yes | Whoop recovery `spo2_percentage` | Hypoxemia (<92%) |
| **steps** | int | count | Yes | App / synthetic* | Activity; <500 = very low |
| **sleep_hours** | float | hours | Yes | Whoop sleep duration | Deficit <6h, critical <4h |
| **pill_count** | int | count | Yes | Senior app / manual | Refill when <3 |
| **last_movement_minutes** | int | minutes | Yes | App / synthetic* | Inactivity alert >4h, critical >6h |
| **timestamp** | string | ISO 8601 | No | Server or device | When the reading is from |
| **medication_name** | string | — | No | App | e.g. "Blood Pressure" |
| **emergency_contact** | string | E.164 | No | Profile | Fall / emergency call |
| **hrv_percent** | float | 0–100% | No | Whoop **recovery_score** | Low <40% → possible infection |
| **fall_detected** | bool | — | No | Device / synthetic | Emergency protocol |
| **mood_score** | float | 1–5 | No | Self-report / app | EmoCare; <3 → trigger call |
| **heart_rate_avg_24h** | float | bpm | No | Whoop cycle **average_heart_rate** | 24h trend |
| **spo2_avg_24h** | float | % | No | Whoop recovery **spo2_percentage** | 24h trend |
| **family_contacts** | array | [{name, phone, last_contact_iso}] | No | Profile | Calling rotation |
| **medication_taken_today** | object | e.g. {morning, afternoon, evening, night} | No | App | Adherence |
| **doses_missed_consecutive_days** | int | days | No | App | 3-day miss → refill |

\* Whoop does not provide step count or “last movement”; these come from the senior app, another wearable, or **synthetic data** for demos.

---

## 2. Whoop API → ElderHarmony Mapping

### 2.1 Recovery (Whoop Recovery endpoint)

| Whoop field | Our field | Notes |
|-------------|-----------|--------|
| `recovery_score` (0–100) | **hrv_percent** | Direct mapping; “recovery” is HRV-based |
| `resting_heart_rate` | **heart_rate** or **heart_rate_avg_24h** | RHR for the cycle |
| `spo2_percentage` | **spo2**, **spo2_avg_24h** | If available (e.g. Whoop 4.0) |
| `hrv_rmssd_milli` | — | Optional: convert to % of personal baseline for **hrv_percent** |
| `skin_temp_celsius` | — | Future: fever detection |

### 2.2 Sleep (Whoop Sleep endpoint)

| Whoop field | Our field | Notes |
|-------------|-----------|--------|
| `stage_summary` (total sleep time) | **sleep_hours** | Sum in-bed minus awake, convert to hours |
| `sleep_performance_percentage` | — | Optional: quality indicator |
| `respiratory_rate` | — | Optional: future vitals |

### 2.3 Cycle / Strain (Whoop Cycle endpoint)

| Whoop field | Our field | Notes |
|-------------|-----------|--------|
| `average_heart_rate` | **heart_rate_avg_24h** | 24h average from cycle |
| `max_heart_rate` | — | Optional: peak activity |
| `kilojoule` / strain | — | **steps** not in Whoop; derive synthetic steps (e.g. strain × 400) or use app |

### 2.4 Not from Whoop (app or synthetic)

- **steps** – from phone/watch step counter or synthetic.
- **last_movement_minutes** – from app/device motion or synthetic.
- **pill_count**, **medication_taken_today**, **doses_missed_consecutive_days** – senior app.
- **fall_detected** – device accelerometer or synthetic for demos.
- **mood_score** – self-reported in app (1–5).
- **family_contacts**, **emergency_contact** – profile.

---

## 3. Clinical Thresholds (ElderHarmony)

| Vital | Normal | Concern | Critical | Agent / action |
|-------|--------|---------|----------|-----------------|
| Heart rate | 50–120 bpm | — | <50 or >120 | VitalSync, Calling |
| SpO2 | ≥92% | 90–92% | <90% | VitalSync, Calling |
| HRV (recovery %) | ≥40% | — | <40% | VitalSync, doctor visit nudge |
| Sleep | ≥6 h | 4–6 h | <4 h | Sleep agent, alert family |
| Steps | — | <3000 | <500 | Activity agent |
| Last movement | <4 h | 4–6 h | >6 h | Activity, Calling (welfare) |
| Pills | >3 | 1–3 | 0 | Refill, Medicine |
| Missed doses | 0–2 days | — | ≥3 days | Refill |
| Mood | 4–5 | 3 | 1–2 | EmoCare, Calling |
| Fall | false | — | true | Calling (emergency) |

---

## 4. Synthetic Data Ranges (Elderly-Typical)

For believable demo data:

- **heart_rate**: 58–88 bpm (normal), 48–52 (brady), 122–135 (tachy).
- **spo2**: 94–99% (normal), 88–91% (concerning), 85–87% (critical).
- **hrv_percent**: 25–75% (typical), 15–38% (low), 80–100% (excellent).
- **sleep_hours**: 5.0–7.5 (normal), 3.5–5.5 (deficit), 2.5–4.0 (critical).
- **steps**: 800–4500 (normal), 200–600 (low), 50–200 (very low).
- **last_movement_minutes**: 10–180 (active), 250–350 (sedentary), 370–420 (critical).
- **mood_score**: 1–5; use 2.0–2.5 for “low mood” scenarios.

See `personas.json` and scenario files in this folder for concrete values.
