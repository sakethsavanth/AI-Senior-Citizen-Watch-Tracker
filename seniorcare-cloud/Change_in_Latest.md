# ElderHarmony – Change Log (Latest Sprint)

> **Branch:** `kirti`  
> **Date:** March 15, 2026  
> **Test Status:** 33/33 passing  

---

## 1. Rewrite `lambda_handler` with Deterministic Triage

**File:** `railtracks_agents/lambda_handler.py`

- Fully rewrote the AWS Lambda entry point with a 4-stage pipeline:
  1. **Parse & validate** `HealthPayload` from API Gateway event body
  2. **Deterministic triage** via `HealthAnalyzer.full_assessment()` + `determine_routes()` — runs _before_ the LLM, so every request gets a baseline risk classification even if the model is down
  3. **LLM orchestration** — enriched prompt with triage context is passed to the Railtracks `Flow`
  4. **Structured response** — `_build_response()` parses LLM JSON output and merges it with the deterministic report
- Added `_build_fallback_response()` — when the LLM flow throws, the handler returns **200** with triage-only data instead of a 500 error
- Added `_try_parse_json()` helper that handles markdown fences and embedded JSON from LLM output
- Added `_validate_ranges()` for field-level bounds checking (heart_rate, spo2, steps, etc.)

---

## 2. Add `HealthPayload` Validation

**File:** `models/health_payload.py`

- Added `FIELD_RANGES: ClassVar[Dict[str, tuple]]` — clinical bounds for 9 fields:
  - `heart_rate` 30–220, `spo2` 50–100, `steps` 0–100k, `sleep_hours` 0–24, `pill_count` 0–500, `last_movement_minutes` 0–1440, `hrv_percent` 0–100, `mood_score` 1–5, `doses_missed` 0–365
- Added `validate_ranges() -> List[str]` method that returns human-readable violation messages
- Payloads outside these ranges are rejected with a 400 response at the Lambda layer

---

## 3. Create New Scenario JSON Files

**Directory:** `data/synthetic/scenarios/`

Created 4 new scenario files and updated 2 existing ones:

| File | Description |
|---|---|
| `sleep_deficit.json` (new) | HRV=35, sleep=3.5h, medium risk |
| `low_mood_trigger_call.json` (new) | mood=2.0, family contacts, triggers EmoCare + Calling |
| `critical_vitals.json` (new) | HR=135, SpO2=88, high risk |
| `low_pills_refill.json` (new) | pill_count=2, 3-day miss, triggers auto-refill |
| `normal_day.json` (updated) | Added `expected_risk`, `expected_agents`, `expected_emergency` |
| `fall_detected.json` (updated) | Added `expected_risk`, `expected_agents`, `expected_emergency` |

All scenario files now include test annotations (`expected_risk`, `expected_agents`, `expected_emergency`) used by the automated test suite.

---

## 4. Add Medication Adherence Tools

**File:** `railtracks_agents/tools/medication_tools.py`

Added 3 new `@rt.function_node` tools:

- **`should_refill(pill_count, doses_missed)`** — centralized refill decision logic; returns `refill_now`, `urgency` (low/medium/high), and `reason`
- **`compute_adherence_today(medication_taken_today_json)`** — computes `taken`/`missed`/`adherence_pct` from the 4-window medication dict
- **`build_medication_reminder(health_json)`** — generates a voice/text reminder message based on current time window and adherence state

---

## 5. Enhance Sleep & Activity Alert Tools

**File:** `railtracks_agents/tools/vitals_tools.py`

- **`assess_sleep`** — added `alert_family: True` flag when sleep quality is `"poor"`
- **`assess_activity`** — added `alert_family: True` flag when status is `"critical"`, plus a `recommendation` string for low-step cases
- **`sleep_hr_correlation(sleep_hours, heart_rate)`** (new) — returns a correlation note and recommendation when poor sleep coincides with elevated heart rate

---

## 6. Implement Health Records Tools

**File:** `railtracks_agents/tools/health_records_tools.py`

Replaced all stubs with data-driven implementations:

- **`get_medication_interactions`** — now uses a `KNOWN_INTERACTIONS` static list (4 drug pairs: ACE+NSAID, Warfarin+Aspirin, Metformin+Alcohol, Digoxin+Amiodarone)
- **`get_lab_summary`** — returns synthetic per-user lab data (A1C, cholesterol, creatinine, BP)
- **`get_visit_prep_from_health(health_json)`** (new) — builds a condition-specific checklist from the health payload (fall, low HRV, poor sleep, low mood, low pills, missed doses)
- **`build_family_dashboard`** — now generates active alerts list (type + message) from health data

---

## 7. Add Pharmacy Demo Mode

**File:** `services/pharmacy_api.py`

- Added `PHARMACY_DEMO` environment variable (defaults to `"1"` → demo mode ON)
- When demo mode is active, `request_refill()` returns `_simulate_refill()` immediately without attempting a real API call
- Prevents network errors during local testing and hackathon demos

---

## 8. Update Tool Registry

**File:** `railtracks_agents/tools/_tool_registry.py`

Updated imports and `AGENT_TOOLS` dict to register all new tools:

- `"medicine"` → added `should_refill`, `compute_adherence_today`, `build_medication_reminder`
- `"medication"` → added `compute_adherence_today`, `build_medication_reminder`
- `"refill"` → added `should_refill`
- `"sleep"` → added `sleep_hr_correlation`
- `"health_records"` → added `get_visit_prep_from_health`

---

## 9. Create Test Files

Created 3 new test files in `tests/`:

| File | Tests | Purpose |
|---|---|---|
| `test_scenario_contracts.py` | 8 | Validates all scenario JSONs: required fields present, parseable by `HealthPayload`, values within clinical ranges, invalid data rejected |
| `test_router_rules.py` | 17 | Deterministic assertions for `HealthAnalyzer.full_assessment()` and `determine_routes()` against annotated scenarios; edge cases (boundary HRV, mood presence) |
| `test_e2e_critical.py` | 8 | Full lambda pipeline with mocked Railtracks `Flow`: fall, critical vitals, normal day, invalid payload, out-of-range, flow failure fallback, response structure, low mood |

---

## 10. Add Annotated Scenarios

All 6 scenario files (4 new + 2 updated) now include:

```json
{
  "expected_risk": "high|medium|low",
  "expected_agents": ["vital_sync_agent", "calling_agent", ...],
  "expected_emergency": true|false
}
```

These annotations are consumed by `test_router_rules.py` to auto-verify that the deterministic triage engine produces the correct risk level and agent routing for every scenario.

---

## 11. Fix `HealthAnalyzer` Flag Gaps

**File:** `services/health_analyzer.py`

Fixed `full_assessment()` critical flag collection — two categories were silently missed:

- **Sleep**: `assess_sleep` returns `quality` (not `status`), so `quality == "poor"` was never caught. Added `elif a.get("quality") == "poor"` check.
- **Medication**: `refill_needed` and `refill_3day_miss` flags were not treated as critical. Added `elif a.get("refill_needed") or a.get("refill_3day_miss")` check.

This fixed 3 failing tests (sleep_deficit and low_pills_refill scenarios were incorrectly classified as "low" risk instead of "medium").

---

## 12. Run All Tests Green

```
=================== 33 passed, 61 subtests passed in 0.22s ====================
```

- `test_scenario_contracts.py` — 8/8 ✅
- `test_router_rules.py` — 17/17 ✅
- `test_e2e_critical.py` — 8/8 ✅

Additional fixes made during test stabilization:
- Changed `FIELD_RANGES` from `Dict[str, tuple]` to `ClassVar[Dict[str, tuple]]` — Python 3.14 dataclasses reject mutable defaults
- Mocked `railtracks` module at `sys.modules` level in E2E tests (SDK not installed locally)
- Moved `lambda_handler` import to module level so `@patch` decorators can resolve the target

---

## 13. Test & Deploy Instructions

Documented complete testing commands and AWS Lambda deployment guide:

- **Test commands** for all 3 layers + OpenRouter API smoke test
- **Lambda handler path**: `railtracks_agents.lambda_handler.lambda_handler`
- **Deployment zip** packaging steps
- **Environment variables** reference (OPENAI_API_KEY, OPENROUTER_API_KEY, PHARMACY_DEMO, Twilio, etc.)
- **Lambda settings**: Python 3.12 runtime, 512MB memory, 60s timeout
- **API Gateway**: POST `/health-data` with CORS
- **SAM template** for infrastructure-as-code deployment

---

## Files Modified (Summary)

| File | Type |
|---|---|
| `railtracks_agents/lambda_handler.py` | Rewritten |
| `models/health_payload.py` | Enhanced |
| `services/health_analyzer.py` | Bug fix |
| `railtracks_agents/tools/vitals_tools.py` | Enhanced |
| `railtracks_agents/tools/medication_tools.py` | Enhanced |
| `railtracks_agents/tools/health_records_tools.py` | Rewritten |
| `railtracks_agents/tools/_tool_registry.py` | Updated |
| `services/pharmacy_api.py` | Enhanced |
| `data/synthetic/scenarios/` (6 files) | Created / Updated |
| `tests/test_scenario_contracts.py` | Created |
| `tests/test_router_rules.py` | Created |
| `tests/test_e2e_critical.py` | Created |
