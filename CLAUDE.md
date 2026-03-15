# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ElderHarmony** – An AI-powered elderly care system for a hackathon. A Whoop wearable/app POSTs 24-hour health vitals to an API Gateway endpoint, which triggers an Orchestrator that fans out to 9 specialized agents. Two backend implementations exist side-by-side: the original **Lambda-based** system and the newer **Railtracks agentic** system.

## Architecture

All backend code lives in `seniorcare-cloud/`. The system is event-driven (no cron):

```
POST /health-data → API Gateway → Orchestrator
                                      ↓
         ┌──────────┬──────────┬──────────┬──────────┐
     VitalSync  Medicine  EmoCare  Calling  HealthRecords  (always)
         +       +         +        +
     Activity   Sleep   Medication  Refill                 (conditional)
```

### Two Backend Implementations

**1. Lambda-based (`lambdas/`)** – Original architecture. Orchestrator uses `HealthAnalyzer` (deterministic) + `OpenRouterClient` (Claude via OpenRouter) → `event_router.determine_routes()` → async Lambda invocations. Each agent is a separate Lambda with `lambda_handler(event, context)`.

**2. Railtracks agentic (`railtracks_agents/`)** – Newer implementation using the `railtracks` SDK. Uses **agents-as-tools** pattern: the Orchestrator is an `rt.agent_node` with 9 sub-agents + a `full_health_assessment` triage tool as `tool_nodes`. The LLM (GPT-OSS 120B via HuggingFace endpoint) decides which agents to invoke based on its system prompt. Entry point: `railtracks_agents/lambda_handler.py`.

### Shared Modules (used by both implementations)

- **`models/health_payload.py`** – `HealthPayload` dataclass with clinical thresholds and risk-flag properties. The data contract for all agents.
- **`services/openrouter_client.py`** – `OpenRouterClient` wraps OpenRouter chat-completions with domain-specific helpers (`analyze_health`, `analyze_vitals_24h`, `analyze_mood`, etc.).
- **`services/twilio_service.py`** – `TwilioService` for voice calls and SMS. Simulates when credentials are missing.
- **`services/pharmacy_api.py`** – `PharmacyAPI` for medication refills. Simulates when unreachable.
- **`services/health_analyzer.py`** – `HealthAnalyzer` with deterministic assessments (vitals, HRV, fall, sleep, activity, medication, mood).
- **`utils/event_router.py`** – `determine_routes()` returns `List[RoutingDecision]` for the Lambda-based system.

### Railtracks-Specific Structure

- **`railtracks_agents/config.py`** – LLM provider setup (GPT-OSS 120B via OpenAICompatibleProvider).
- **`railtracks_agents/tools/`** – `@rt.function_node` tools organized by domain: `vitals_tools.py`, `medication_tools.py`, `mood_tools.py`, `communication_tools.py`, `health_records_tools.py`.
- **`railtracks_agents/tools/_tool_registry.py`** – Central `AGENT_TOOLS` dict mapping agent names to their tool lists. **Extensibility point**: to add a new tool, create a `@rt.function_node`, import it here, and append to the relevant agent's list.
- **`railtracks_agents/agents/`** – Each agent is an `rt.agent_node` with system prompt, tools from registry, and a `ToolManifest`.

## Agent Routing Rules

- **VitalSync** – Always runs. Alerts on fall, low HRV (<40%).
- **Medicine** – Always runs. Auto-refill on low pills (<3) or 3-day consecutive miss.
- **EmoCare** – Runs when `mood_score` is present. Low mood (<3) triggers Calling.
- **Calling** – Triggered by: fall (emergency), low HRV, vital anomaly, high risk, or low mood. Uses smart family contact rotation (least-contacted first).
- **HealthRecords** – Always runs (passive sync, stubbed for pharmacy/doctor APIs).
- **Activity** – Conditional: steps <500 or >4h idle.
- **Sleep** – Conditional: sleep <6h.
- **Medication** – Always (adherence tracking, alternate to Medicine).
- **Refill** – Conditional: pill_count <3 or 3-day miss.

## Commands

```bash
# Install dependencies (Python 3.11)
cd seniorcare-cloud
pip install -r requirements.txt

# Run Lambda-based local tests (orchestrator + agents via OpenRouter)
cd seniorcare-cloud
python tests/test_local.py

# Run Railtracks-based local tests (agents-as-tools via GPT-OSS)
cd seniorcare-cloud
python tests/test_railtracks_local.py

# Test Whoop wearable data integration
cd seniorcare-cloud
python whoopTester.py
```

## Environment Variables

Required in `.env` (at `seniorcare-cloud/.env`):
- **AWS/OpenRouter:** `AWS_REGION`, `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, agent ARNs (`VITAL_SYNC_AGENT_ARN`, etc.)
- **Railtracks:** `OPENAI_API_KEY` (for GPT-OSS endpoint)
- **Twilio:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`, `FAMILY_PHONE_NUMBER`
- **Pharmacy:** `PHARMACY_API_URL`, `PHARMACY_API_KEY`, `DEFAULT_REFILL_QTY`
- All services gracefully degrade (simulate) when credentials are missing.

## Import Path Convention

Both Lambda handlers and Railtracks handlers use `sys.path.insert(0, ...)` to resolve imports from `seniorcare-cloud/` root. Imports like `from models.health_payload import HealthPayload` assume the working directory or sys.path includes `seniorcare-cloud/`.

## Related Project

**SafePath York** (`E:/Personal Project/yorkUhack/`) – A Flutter web app for safe walking routes in York Region, Ontario. Separate codebase, not directly integrated with ElderHarmony.
