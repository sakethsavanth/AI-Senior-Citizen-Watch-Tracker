## SeniorCare AI — Multi-Agent GenAI Health Monitoring System

---

|  |  |
| --- | --- |
| **Version** | 1.0 — Hackathon Edition |
| **Date** | March 14, 2026 |
| **Target Event** | University Hackathon |
| **Technology Stack** | GenAI (Claude) · AWS Lambda · Twilio · Samsung Health SDK |
| **Document Owner** | SeniorCare AI Team |
| **Status** | 🟡 In Progress |

---

## 1. Executive Summary

SeniorCare AI is a **multi-agent GenAI system** designed to bridge the gap between senior citizens living alone — particularly those in diaspora families — and their children or caregivers living far away. Powered by **Claude (Anthropic)**, the system monitors health data in real time, takes autonomous actions, and proactively communicates with both the senior and their family.

### 1.1 The Problem

| Statistic | Source |
| --- | --- |
| 28% of US seniors (65+) live alone | Pew Research 2025 |
| 50% of patients skip medications | WHO / BMC Proceedings 2024 |
| 125,000 preventable deaths/year from non-adherence | JMCP / PMC 2024 |
| Caregiver ratio drops to 3:1 by 2040 (from 6:1 today) | Census Bureau / PRB 2025 |
| RPM market growing to $137B by 2033 at 12.25% CAGR | Straits Research 2025 |

### 1.2 Our Solution

A GenAI-powered orchestrator (Claude) reads health data from a **Samsung Galaxy Watch** via the Samsung Health SDK, decides which specialized agents to activate, and coordinates autonomous actions — including AI voice/video calls via **Twilio** — to protect the senior and keep family informed.

### 1.3 Why GenAI?

- Claude acts as the **reasoning brain** — not hardcoded if/else rules
- Generates **personalized, compassionate voice scripts** for each call
- Writes **AI health summaries** for family dashboard in plain English
- Classifies urgency dynamically: `low` / `medium` / `high` / `critical`

---

## 2. System Architecture Overview

### 2.1 Layer Breakdown

| Layer | Component | Technology | Status |
| --- | --- | --- | --- |
| Device | Samsung Galaxy Watch | Samsung Health SDK (Android) | Build / Mock for demo |
| Mobile | Senior App + Family App | React Native / Android | Build |
| Cloud | API Gateway + Lambda Orchestrator | AWS Lambda + Claude API | Build |
| Agents | Sleep / Activity / Meds / Refill / Calling | AWS Lambda functions | Build |
| Communication | Voice & Video Calls | Twilio Voice API | Build |
| Dashboard | Family Web Dashboard | React + AWS Amplify | Build |

### 2.2 Data Flow

1. Samsung Watch collects: **heart rate, SpO2, steps, sleep stages**
2. Samsung Health SDK sends data to Senior Android App
3. App posts JSON payload to **AWS API Gateway** (HTTPS)
4. Lambda Orchestrator receives data — sends to **Claude AI**
5. Claude assesses health context and returns **agent trigger decisions**
6. Orchestrator fans out to: Sleep Agent, Activity Agent, Medication Agent
7. If urgent: **Calling Agent** fires Twilio voice call to senior and/or family
8. Family Dashboard receives **real-time alerts** and weekly AI summaries

---

## 3. Samsung Watch Integration — Step by Step

> ⚠️ **This section is your most important technical reference. Follow these steps in order.**
> 

### Step 1 — Register on Samsung Developer Portal

- Go to: [developer.samsung.com](http://developer.samsung.com)
- Create a Samsung Developer Account (free)
- Navigate to: **Samsung Health > Health Platform**
- Apply for Samsung Health SDK access *(approval can take 1–3 days — do this FIRST)*

> 💡 **Hackathon Tip:** If SDK approval is pending, use mock/simulated data from day 1. Build the real connection as a stretch goal.
> 

### Step 2 — Set Up Android Development Environment

- Install **Android Studio** (latest stable version)
- Install **JDK 17** or later
- Set up Android emulator: API Level 30+ (or use a real Galaxy Watch + Galaxy phone)
- Required devices: Samsung Galaxy Watch 4/5/6 paired with a Samsung Galaxy phone

In `build.gradle` (app level), add:

```kotlin
implementation "com.samsung.android.sdk.health:health-data-store:1.1.0"
```

### Step 3 — Configure Samsung Health Permissions

In `AndroidManifest.xml`, declare:

```xml
<uses-permission android:name="com.samsung.android.health.permission.READ_HEART_RATE"/>
<uses-permission android:name="com.samsung.android.health.permission.READ_SLEEP"/>
<uses-permission android:name="com.samsung.android.health.permission.READ_STEP_COUNT"/>
```

**Data types available:**

| Data Type | SDK Constant | Your Agent |
| --- | --- | --- |
| Heart Rate | `HealthConstants.HeartRate.HEALTH_DATA_TYPE` | Activity Agent + Calling Agent |
| SpO2 / Blood Oxygen | `HealthConstants.SpO2.HEALTH_DATA_TYPE` | Critical alert threshold (<90%) |
| Step Count | `HealthConstants.StepCount.HEALTH_DATA_TYPE` | Activity Agent |
| Sleep Stage | `HealthConstants.SleepStage.HEALTH_DATA_TYPE` | Sleep Agent |
| Exercise | `HealthConstants.Exercise.HEALTH_DATA_TYPE` | Activity Agent |

### Step 4 — Connect to Samsung Health Data Store

```kotlin
val store = HealthDataStore(context, connectionListener)
store.connectService()

// In connectionListener.onConnected:
val resolver = HealthDataResolver(store, null)
val request = HealthDataResolver.ReadRequest.Builder()
    .setDataType(HealthConstants.HeartRate.HEALTH_DATA_TYPE)
    .setLocalTimeRange(startTime, endTime)
    .build()
val result = resolver.read(request).await()
```

### Step 5 — Post Data to AWS Backend

```kotlin
val payload = JSONObject()
payload.put("senior_id", "senior_001")
payload.put("heart_rate", heartRate)
payload.put("spo2", spO2)
payload.put("steps", stepCount)
payload.put("trigger_type", "threshold")

// POST to: https://your-api-id.execute-api.region.amazonaws.com/prod/health
```

### Step 6 — Hackathon Shortcut: Mock Data

> If Samsung SDK approval is delayed or you don't have a Galaxy Watch:
> 
- Create a simple Android app with a button to send mock health payloads
- Hard-code two scenarios: **Normal Day** and **Critical Alert**
- POST the mock JSON directly to API Gateway — skip the watch entirely
- This lets you demo the **full AI orchestration flow** without device dependency

---

## 4. Multi-Agent System — Detailed Design

### 4.1 Agent Responsibility Matrix

| Agent | Input | Output / Action | Trigger Type | Priority |
| --- | --- | --- | --- | --- |
| Sleep Agent | Sleep hours, quality score | Alert if <5h or abnormal | Scheduled (morning) | Medium |
| Activity Agent | Steps, last movement timestamp | Alert if no movement >4h waking hours | Threshold | High |
| Medication Agent | Med schedule, missed count | Voice call reminder if missed | Scheduled (per dose) | High |
| Refill Agent | Pill count, refill schedule | Auto-order via pharmacy API | Inventory (<5 pills) | Medium |
| Calling Agent | Critical decision from Orchestrator | Twilio voice/video call | Event-driven | Critical |

### 4.2 Claude Orchestrator — Prompt Design

```
SYSTEM: You are SeniorCare AI, an intelligent health monitoring orchestrator.
Given real-time wearable health data, assess the situation and respond ONLY
with a JSON object containing:
  urgency: low | medium | high | critical
  agents_to_trigger: [list]
  calling_agent_needed: true/false
  call_target: senior | family | both
  alert_message: string for family dashboard

CRITICAL triggers (always call):
- Heart rate >120 or <45 bpm
- No movement >6h during waking hours
- Missed 2+ consecutive medication doses
- SpO2 <90%
```

---

## 5. Project Phases & Timeline

> Hackathon sprints are typically 24–48 hours. This plan is designed for a **2-day sprint with parallel tracks.**
> 

### 🟦 Phase 01 — Foundation & Setup `Hours 0–4`

**Backend Tasks**

- [ ]  Create AWS account and set up IAM roles
- [ ]  Deploy API Gateway with single `POST /health` endpoint
- [ ]  Create Lambda function: `seniorcare-orchestrator`
- [ ]  Set environment variables: `ANTHROPIC_API_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
- [ ]  Test Lambda invocation with hardcoded mock health data

**Frontend Tasks**

- [ ]  Initialize React Native project for Senior App
- [ ]  Initialize React project for Family Web Dashboard
- [ ]  Set up project folder structure

**Samsung Watch Tasks**

- [ ]  Submit Samsung Developer registration *(start NOW — approval takes time)*
- [ ]  Set up Android Studio with emulator
- [ ]  Begin mock data sender app as fallback

### 🟧 Phase 02 — Core Agent Build `Hours 4–16`

**Orchestrator** *(Most Important)*

- [ ]  Build Lambda handler that calls Claude API with health context
- [ ]  Parse Claude's JSON response and fan out to sub-agent Lambdas
- [ ]  Handle errors and fallbacks gracefully

**Medication Agent**

- [ ]  Build medication schedule data model (DynamoDB table or JSON config)
- [ ]  Implement missed dose detection logic
- [ ]  Connect to Calling Agent when doses are missed

**Activity Agent**

- [ ]  Implement inactivity threshold detection (no movement > X hours)
- [ ]  Connect to Calling Agent for critical inactivity

**Calling Agent** *(Demo WOW Factor)*

- [ ]  Set up Twilio account and get phone number
- [ ]  Build Claude-generated script function (personalized per senior)
- [ ]  Implement Twilio Voice API call with TwiML response
- [ ]  **TEST THIS LIVE — have a real phone receive a call during demo**

### 🟩 Phase 03 — UI & Integration `Hours 16–36`

**Senior Android App**

- [ ]  Home screen: vitals display (heart rate, SpO2, steps, sleep)
- [ ]  Medication tab: per-pill status, Mark as Taken button
- [ ]  Incoming AI call screen: Answer / Decline UI
- [ ]  Emergency screen: SOS button, alert sent confirmation

**Family Dashboard (Web)**

- [ ]  Overview page: parent health summary cards
- [ ]  Alerts page: color-coded critical / warning / info feed
- [ ]  Reports page: weekly AI summary + step bar chart
- [ ]  'Call Now' button wired to Calling Agent

**End-to-End Integration**

- [ ]  Wire Samsung Health SDK (or mock app) to API Gateway
- [ ]  Test full flow: Watch data → Lambda → Claude → Agent → Twilio call
- [ ]  Test critical scenario: low SpO2 → critical urgency → calls both senior and family

### 🟥 Phase 04 — Polish & Demo Prep `Hours 36–48`

**Demo Preparation**

- [ ]  Prepare 2 demo scenarios: **Normal Day** and **Critical Alert**
- [ ]  Have a real phone ready to receive the Twilio voice call live on stage
- [ ]  Record backup video of full flow in case of live demo issues
- [ ]  Prepare 3-minute pitch using validation stats

**Presentation Pitch Structure**

1. **Hook** — *"Your dad is alone in India. You're in Toronto. What happens if he falls?"*
2. **Problem** — 28% seniors alone, 50% skip meds, caregiver ratio collapsing
3. **Solution** — Live demo of AI monitoring + Twilio call
4. **Technology** — Multi-agent GenAI, Claude as the brain
5. **Market** — $137B RPM market, 12% CAGR, no diaspora-focused competitor exists
6. **Vision** — Scale to any wearable, any country, WhatsApp integration

---

## 6. Recommended Project Folder Structure

```
seniorcare-ai/
├── backend/
│   ├── orchestrator/          ← Claude AI brain (Lambda)
│   │   └── handler.py
│   ├── agents/
│   │   ├── sleep_agent.py
│   │   ├── activity_agent.py
│   │   ├── medication_agent.py
│   │   ├── refill_agent.py
│   │   └── calling_agent.py   ← Twilio voice/video
│   ├── models/
│   │   └── health_data.py
│   └── serverless.yml         ← AWS deployment config
├── android/                   ← Senior App + Samsung Health SDK
│   ├── app/src/main/
│   │   ├── SamsungHealthManager.kt
│   │   ├── MainActivity.kt
│   │   └── MockDataSender.kt  ← Hackathon shortcut
├── web-dashboard/             ← Family React dashboard
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Overview.jsx
│   │   │   ├── Alerts.jsx
│   │   │   └── Reports.jsx
│   │   └── App.jsx
├── mock-data/
│   ├── normal_day.json        ← Test scenario 1
│   └── critical_alert.json   ← Test scenario 2 (demo this!)
└── README.md
```

---

## 7. Full Technology Stack

| Category | Technology | Purpose | Cost / Notes |
| --- | --- | --- | --- |
| GenAI | Anthropic Claude (claude-sonnet-4-6) | Orchestrator brain, call scripts, summaries | Pay-per-token via API |
| Wearable | Samsung Galaxy Watch + Health SDK | Health data collection | Free SDK; need device |
| Cloud | AWS Lambda + API Gateway | Serverless backend | Free tier available |
| Database | AWS DynamoDB | Health records, med schedules | Free tier: 25 GB |
| Calling | Twilio Voice + Video | AI calls to senior & family | ~$0.013/min voice |
| Mobile App | React Native (Android) | Senior app interface | Open source / free |
| Web Dashboard | React + AWS Amplify | Family monitoring dashboard | Free tier available |
| Auth | AWS Cognito | User authentication | 50K MAU free |

---

## 8. Risks & Mitigations

| Risk | Severity | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Samsung SDK not approved in time | High | High | Use mock data sender as fallback. Demo full flow without real watch. |
| Twilio call not working on demo day | High | Medium | Pre-test with 3 different phones. Have backup screen recording. |
| Claude API rate limits | Medium | Low | Cache responses, use mock JSON for non-demo calls. |
| Team integration conflicts | Medium | Medium | Use agreed API contracts (JSON schema). Build and test independently. |
| Privacy / HIPAA concerns from judges | Low | Low | Clarify this is a prototype. Acknowledge compliance as future work. |

---

## 9. API Contracts

### 9.1 Health Data Payload — Watch → API Gateway

```json
POST /health
Content-Type: application/json

{
  "senior_id": "senior_001",
  "trigger_type": "threshold",
  "health_data": {
    "heart_rate": 72,
    "spo2": 98,
    "steps": 3241,
    "last_movement_mins": 15,
    "sleep_hours": 7.2,
    "sleep_quality": "good",
    "last_medication_time": "08:00",
    "next_medication_time": "20:00",
    "pills_remaining": 12,
    "missed_doses": 0
  }
}
```

### 9.2 Mock Data Scenarios

Save as `mock-data/normal_day.json` and `mock-data/critical_alert.json`

```json
// NORMAL DAY
{
  "heart_rate": 72, "spo2": 98, "steps": 3241,
  "last_movement_mins": 15, "sleep_hours": 7.2,
  "pills_remaining": 12, "missed_doses": 0
}

// CRITICAL ALERT — use this for WOW demo moment
{
  "heart_rate": 128, "spo2": 87, "steps": 200,
  "last_movement_mins": 380, "sleep_hours": 4.1,
  "pills_remaining": 3, "missed_doses": 2
}
```

### 9.3 Claude Response Contract

```json
{
  "assessment": "Critical: No movement 6h+, low SpO2, elevated HR, 2 missed doses",
  "urgency": "critical",
  "agents_to_trigger": ["activity_agent", "medication_agent", "refill_agent"],
  "calling_agent_needed": true,
  "call_target": "both",
  "call_reason": "SpO2 critically low at 87%, no movement for 6 hours",
  "alert_message": "URGENT: No movement for 6h. SpO2 at 87%. Check in immediately."
}
```

---

## 10. Key Resources & Links

| Resource | URL | What you need |
| --- | --- | --- |
| Samsung Health SDK | [developer.samsung.com/health](http://developer.samsung.com/health) | SDK download + API docs |
| Samsung Health SDK Docs | [developer.samsung.com/health/android-privileged-sdk](http://developer.samsung.com/health/android-privileged-sdk) | Full HealthConstants reference |
| Anthropic Claude API | [docs.anthropic.com](http://docs.anthropic.com) | API key, model names, pricing |
| Twilio Voice Quickstart | [twilio.com/docs/voice/quickstart](http://twilio.com/docs/voice/quickstart) | Make your first outbound call |
| AWS Lambda Console | [console.aws.amazon.com/lambda](http://console.aws.amazon.com/lambda) | Deploy orchestrator + agents |
| AWS API Gateway | [console.aws.amazon.com/apigateway](http://console.aws.amazon.com/apigateway) | Create REST endpoint |
| DynamoDB Console | [console.aws.amazon.com/dynamodb](http://console.aws.amazon.com/dynamodb) | Medication schedule tables |

---

> *SeniorCare AI — Built with heart for seniors everywhere.*
> 

> *This document is a living reference for the hackathon team. Update it as decisions change.*
>