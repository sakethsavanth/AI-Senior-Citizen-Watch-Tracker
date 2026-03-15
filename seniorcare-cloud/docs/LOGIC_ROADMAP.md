# ElderHarmony / SeniorCare AI — Logic Roadmap

> **Context:** The app is currently a blueprint: agents, tools, and routing exist but many paths are stubbed or rely entirely on the LLM. This document lists concrete logic you can add to make it production-ready and demo-strong.

**Sources:** Knowledge base (`knowledge base/`), `CLAUDE.md`, `utils/event_router.py`, agents, tools, and services.

---

## 1. Event router integration (deterministic pre-triage)

**Current state:** `utils/event_router.py` has full routing logic (`determine_routes(health, llm_analysis)`) but **it is never called** in the Railtracks flow. The orchestrator comment says routing is "encoded in the system prompt" — so only the LLM decides.

**Logic to add:**

- **Option A — Hybrid:** In `lambda_handler.py`, call `determine_routes(health)` (and optionally `HealthAnalyzer.full_assessment(health)` or OpenRouter) **before** invoking the Orchestrator. Pass the result as structured context, e.g. `suggested_routes: [agent names]` and `overall_risk`, so the LLM can follow or override.
- **Option B — Enforce routes:** Use `determine_routes()` to decide which agents **must** run; invoke only those agent nodes (or a sub-flow) instead of giving the LLM full freedom. Reduces cost and keeps behavior aligned with clinical rules.
- **Option C — Fallback:** If the LLM returns no agents or errors, fall back to `determine_routes(health)` and invoke those agents explicitly.

**Files to touch:** `railtracks_agents/lambda_handler.py`, optionally `utils/event_router.py` (extend with `llm_analysis` from an OpenRouter call if you add it).

---

## 2. VitalSync agent — concrete actions

**Current state:** VitalSync has tools (assess_vitals, assess_hrv, assess_fall, assess_sleep, assess_activity, emergency_escalation) and a strong system prompt. Logic is mostly “call tools and return JSON.”

**Logic to add:**

- **Fall → emergency_escalation:** In VitalSync (or in a small deterministic wrapper), **if** `assess_fall` returns `fall_detected=true`, **immediately** call `emergency_escalation` with senior/family numbers from payload — do not wait for other assessments. You can do this in the agent prompt (already hinted) or in a thin function that runs before/after the agent.
- **HRV & doctor visit:** When HRV &lt; 40%, add a concrete action: e.g. call a “schedule_doctor_alert” tool (stub that returns “Alert sent to primary care”) or enqueue a task for family (“Consider scheduling a doctor visit”).
- **Daily message by time of day:** Implement the 7AM walk / 9PM sleep message logic in a **tool** (e.g. `get_daily_message(utc_hour, health_json)`) that returns the exact string; agent just calls it and passes through. Makes behavior testable and consistent.
- **Severity → alert_family:** Map `severity` (critical/high/low) to a boolean `alert_family` in code (e.g. critical or high → true), so the family dashboard or downstream logic doesn’t depend on the LLM wording.

**Files:** `railtracks_agents/agents/vital_sync_agent.py`, `railtracks_agents/tools/vitals_tools.py` (new tools if needed), optionally a small `utils/vital_actions.py`.

---

## 3. Medicine / Medication / Refill agents — adherence and refill

**Current state:** Medication windows (8/12/18/21), `assess_medication`, `get_current_med_window`, `request_pharmacy_refill` exist. Pharmacy API simulates when unreachable. No persistent med schedule or adherence state.

**Logic to add:**

- **Adherence from `medication_taken_today`:** In Medicine/Medication agent (or in a tool), compute “taken at morning/afternoon/evening/night” from `medication_taken_today` and add to the response (e.g. `adherence_today: { morning: true, afternoon: false }` and a short summary). Use it in the reminder text (“You missed afternoon dose”).
- **Refill conditions in one place:** Centralize “when to refill” in a single function used by both Medicine and Refill agents: e.g. `should_refill(pill_count, doses_missed_consecutive_days)` → true if `pill_count < 3` or `doses_missed_consecutive_days >= 3`. Call it from a tool so both agents get the same behavior.
- **Voice reminder text template:** A tool `build_medication_reminder(health_json)` that returns a fixed template string with slots (window name, med name, pill_count, “Taken? Yes or No”) so Twilio/calling uses the same script every time for a given state.
- **Pharmacy stub for demo:** In `pharmacy_api.py`, add a “demo mode” (e.g. env `PHARMACY_DEMO=1`) that always returns a successful refill with a deterministic `order_id` and “2–3 business days” so demos don’t depend on a real API.

**Files:** `railtracks_agents/tools/medication_tools.py`, `services/pharmacy_api.py`, optionally `models/medication_schedule.py` if you add persistence later.

---

## 4. Calling agent — Twilio and family rotation

**Current state:** `call_senior`, `alert_family_sms`, `emergency_escalation`, `pick_family_contact` exist. Twilio simulates when credentials are missing.

**Logic to add:**

- **Always pass numbers from payload:** Ensure `emergency_contact` and `family_contacts` from `HealthPayload` are passed into the Calling agent (or tools). If `family_contacts` exists, **always** call `pick_family_contact` first and use the chosen contact for SMS/calls so rotation is real.
- **Message templates by trigger:** Map trigger type (fall, vital_anomaly, low_hrv, low_mood) to a short template in code (e.g. “Fall detected…”, “Low SpO2…”, “Mood check suggested…”). Agent or tool fills in numbers and sends; avoids LLM inventing inconsistent wording.
- **Emergency priority:** If both “call senior” and “SMS family” are requested, do **emergency_escalation** (call + SMS) in one step; otherwise prefer “call senior” for critical and “SMS family” for medium/low when you have clear severity from triage.
- **Twilio “press 1” for fall:** In `twilio_service.py`, for fall detection, use a TwiML that says “Press 1 to confirm you’re OK” and, if you later add a webhook, handle the keypress to close the incident or escalate.

**Files:** `railtracks_agents/tools/communication_tools.py`, `railtracks_agents/agents/calling_agent.py`, `services/twilio_service.py`.

---

## 5. EmoCare agent — mood and recommendations

**Current state:** `assess_mood`, `build_mood_recommendations` are implemented. Agent returns JSON with recommendations and trigger_call.

**Logic to add:**

- **Trigger Calling when mood &lt; 3:** In the orchestrator or in a post-step, if EmoCare’s result has `trigger_call=true` (or `mood_score < 3`), **deterministically** add Calling agent to the list of agents to run (or invoke it). This matches the knowledge base (“low mood → trigger call to family”).
- **Recommendations from rules:** Keep `build_mood_recommendations(mood_score, steps, sleep_hours)` as the single source of rules (steps &lt; 1000 → walk suggestion; sleep &lt; 6 → sleep tip; mood &lt; 3 → family call). Agent can still add a short “insight” in natural language on top.
- **Optional: mood history:** If you add a small store (e.g. DynamoDB or in-memory for demo), store last N mood scores and add a tool “mood_trend( user_id )” so the agent can say “mood has been low for 3 days.”

**Files:** `railtracks_agents/agents/emo_care_agent.py`, `railtracks_agents/agents/orchestrator.py`, `railtracks_agents/tools/mood_tools.py`.

---

## 6. HealthRecords agent — stubs to real logic

**Current state:** All tools are stubbed: `get_medication_interactions`, `get_lab_summary`, `get_visit_prep`, `build_family_dashboard`.

**Logic to add:**

- **Medication interactions:** Integrate a real API (e.g. OpenFDA, or a pharmacy API) or a local DB of interactions. At minimum, add a **static list** of known pairs (e.g. “Blood Pressure + NSAID”) and return “possible interaction” when the payload’s med matches.
- **Lab summary:** If you have no lab API, derive a **synthetic** summary from vitals: e.g. “Based on recent vitals: HR and SpO2 in range; consider A1C if diabetic.” Or pull from a mock JSON file per user for demo.
- **Visit prep:** Keep checklist as-is or make it **data-driven**: e.g. if `fall_detected` or `is_hrv_low`, add “Discuss fall risk” or “Discuss low HRV / possible infection” to the checklist.
- **Family dashboard:** `build_family_dashboard` already uses health JSON; add **next_checkup** from a config or calendar stub (e.g. env or JSON “next_checkup”: “Mar 20”) and **last_alert_at** if you persist alerts.

**Files:** `railtracks_agents/tools/health_records_tools.py`, optional `services/health_records_api.py` or static data files.

---

## 7. Activity agent — thresholds and escalation

**Current state:** `assess_activity` and `assess_fall` are used. Agent prompt describes >4h / >6h rules.

**Logic to add:**

- **Single source of thresholds:** Use the same constants as `HealthPayload` (e.g. `INACTIVITY_HIGH_THRESHOLD = 240`, and 360 for critical) in the activity tool so “sedentary” vs “critical” is consistent with the event router and VitalSync.
- **Trigger Calling on critical inactivity:** In the orchestrator or in the Activity agent’s expected output, define that when `status == "critical"` (e.g. >6h no movement), the **Calling agent must be invoked** with a welfare-check message. You can enforce this in `determine_routes()` or in a post-processing step that checks Activity result and enqueues Calling.
- **Steps &lt; 500:** Add a simple “very low steps” message or recommendation in a tool (e.g. “Consider a short walk”) so the agent always has a concrete suggestion when steps are low.

**Files:** `railtracks_agents/tools/vitals_tools.py` (assess_activity), `railtracks_agents/agents/activity_agent.py`, `utils/event_router.py` (if you use it for enforcement).

---

## 8. Sleep agent — quality and alerts

**Current state:** `assess_sleep` and `assess_vitals` are used. Prompt defines &lt;4h critical, 4–6h fair, 6+ good.

**Logic to add:**

- **Alert family when poor:** If `quality == "poor"` (sleep &lt; 4h), set `alert_family=true` in code (or in a tool) so the pipeline always alerts family for poor sleep, independent of LLM wording.
- **Correlate with HR:** A tool `sleep_hr_correlation(sleep_hours, heart_rate)` that returns a short line like “Poor sleep may explain elevated heart rate” when sleep is low and HR is high; agent can include it in the summary.
- **Chronic poor sleep:** If you add storage, flag “sleep &lt; 6h for 3+ days” and add a recommendation to “Discuss sleep with provider” in visit prep or family dashboard.

**Files:** `railtracks_agents/tools/vitals_tools.py`, `railtracks_agents/agents/sleep_agent.py`.

---

## 9. Lambda handler and flow

**Current state:** Handler parses `HealthPayload`, builds a single prompt string, invokes the Orchestrator once, returns `flow_result` text.

**Logic to add:**

- **Structured response:** Parse the Orchestrator’s final message as JSON (e.g. `agents_invoked`, `overall_risk`, `summary`, `agent_results`) and return that in `response_body` so the family dashboard or mobile app can show structured cards and actions (e.g. “Call Now”).
- **Use triage first:** Call `full_health_assessment(health_json)` (or `HealthAnalyzer.full_assessment(health)`) and pass `overall_risk` and `critical_flags` into the prompt so the LLM sees deterministic triage and can align agent choice with it.
- **Idempotency / rate limiting:** For the same `user_id` + time window (e.g. 15 min), optionally return a cached result or “already_processed” to avoid duplicate calls and Twilio spam.
- **Validation:** Validate required fields and ranges (e.g. `heart_rate` 30–200, `spo2` 70–100) before creating `HealthPayload` and return 400 with a clear message if invalid.

**Files:** `railtracks_agents/lambda_handler.py`, optionally `models/health_payload.py` (validation helpers).

---

## 10. Persistence and state (optional but high impact)

**Current state:** No DB. All state is in the incoming payload.

**Logic to add:**

- **DynamoDB (or similar):** Store last payload per user (e.g. `user_id` + `period = "24h"`) so you can compare “previous vs current” for trends (e.g. “HR increased since yesterday”) and so the family dashboard can show last-known state if the app is closed.
- **Alerts log:** Store each “alert” or “call” (user_id, timestamp, type, agent, result) for audit and for “last_alert_at” in the family view.
- **Medication schedule:** Store schedule per user (drug, times, timezone) so reminders and adherence are not only from the payload’s `medication_taken_today` but from a canonical schedule.
- **Family contacts:** Store and update `last_contact_iso` when a call/SMS is made so `pick_family_contact` rotation is real across requests.

**Files:** New `services/repository.py` or `services/state_store.py`, plus table definitions (e.g. Terraform or SAM). Agents/tools call the store via small functions.

---

## 11. GenAI enhancements (from knowledge base)

**Current state:** Orchestrator uses an LLM to decide agents and summarize. No separate “weekly summary” or “call script” generation.

**Logic to add:**

- **Weekly AI summary:** A scheduled job (or a separate endpoint) that loads the last 7 days of health data for a user and calls Claude to produce a short paragraph (“Mr. Sharma had a stable week. Sleep improved 12%. Consider increasing walks.”). Store or send to family dashboard. Matches the knowledge base “Weekly AI Health Summaries.”
- **Personalized call script:** Before Calling agent runs, call Claude with senior name, vitals, and trigger reason to generate a **short** script (2–3 sentences) and pass it to `call_senior(to_number, script)`. Twilio then speaks that script instead of a fixed template. Matches “AI-generated voice scripts” in the knowledge base.
- **Urgency and alert_message:** Have the Orchestrator (or a dedicated small prompt) output a strict JSON with `urgency` (low/medium/high/critical), `alert_message`, and `call_target` (senior/family/both) so the pipeline and dashboard don’t have to parse free text.

**Files:** New `services/summary_service.py` or similar, `railtracks_agents/agents/calling_agent.py` (or a “script_generator” tool), orchestrator prompt/output schema.

---

## 12. Demo and testing

**Current state:** Mock payloads and simulated Twilio/Pharmacy exist.

**Logic to add:**

- **Normal vs critical demo:** Two fixed payloads (e.g. `mock-data/normal_day.json` and `mock-data/critical_alert.json`) and a script or env flag that runs the flow for both and prints or asserts expected agents and expected “at least one call” for critical. Matches the plan’s “Prepare demo scenario files.”
- **Whoop/Samsung payload shape:** If the mobile app will send a different shape (e.g. from Samsung Health SDK), add an **adapter** in `HealthPayload.from_event()` that maps their fields (e.g. `heart_rate_avg_24h`, `spo2_24h`) into your model so one codebase supports both “internal” and “device” payloads.
- **E2E test:** One test that runs the full flow with `critical_alert.json` and checks that (1) `emergency_escalation` or `call_senior` was invoked (e.g. via mock) and (2) response contains `overall_risk: high` or similar.

**Files:** `tests/test_railtracks_local.py`, `tests/test_e2e_critical.py`, `models/health_payload.py` (adapter), `mock-data/` (ensure files exist and are used).

---

## 13. Quick reference — where things live

| Area              | Main files |
|-------------------|------------|
| Routing rules     | `utils/event_router.py` |
| Triage / assessment | `railtracks_agents/tools/vitals_tools.py` (`full_health_assessment`), `services/health_analyzer.py` |
| Agents            | `railtracks_agents/agents/*.py` |
| Tools             | `railtracks_agents/tools/*.py`, `_tool_registry.py` |
| Entry point       | `railtracks_agents/lambda_handler.py` |
| Twilio            | `services/twilio_service.py` |
| Pharmacy          | `services/pharmacy_api.py` |
| Data contract     | `models/health_payload.py` |

---

Implementing even a subset of the items above (e.g. event router integration, fall → emergency_escalation, structured response, and demo scenarios) will move the app from blueprint to a logical, demo-ready system that matches the knowledge base and plan.
