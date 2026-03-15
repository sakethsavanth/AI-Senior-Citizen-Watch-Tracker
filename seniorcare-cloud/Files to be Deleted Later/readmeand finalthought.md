# Readme + Requirement.txt

# README + requirements.txt — Copy-Paste Ready

> Copy these two files directly into your repo root. Then commit and push.
> 

---

## File 1 — [README.md](http://README.md)

Create `README.md` at the repo root and paste this:

```markdown
# 🏥 SeniorCare AI — Multi-Agent GenAI Health Monitor

> Bridging the gap between students abroad and their aging parents at home — using GenAI, wearables, and autonomous agents.

Built with Railtracks

---

## 🎯 The Problem

Millions of students study abroad (e.g. University of Toronto) while their parents age alone in home countries (India, Ghana, Nigeria). Existing tools are passive — they show data but don't act.

- **28%** of US seniors 65+ live alone (Pew Research, 2025)
- **50%** of patients skip medications (WHO, 2024)
- **125,000** preventable deaths/year from non-adherence (JMCP)
- Caregiver ratio drops to **3:1 by 2040** (Census Bureau)

## 💡 Our Solution

SeniorCare AI is a **multi-agent GenAI system** powered by **Claude (Anthropic)** that autonomously monitors senior health and takes action — not just sends alerts.

### How It Works

```

Samsung Watch → Health SDK → Android App

→ AWS API Gateway

→ Lambda Orchestrator (Claude AI Brain)

→ Sleep Agent / Activity Agent / Medication Agent / Refill Agent

→ Calling Agent (Twilio Voice/Video)

→ Family Dashboard

```

## 🤖 Multi-Agent Architecture (Railtracks)

We use **Railtracks** to build and orchestrate our multi-agent system:

```

import railtracks as rt

# Medication reminder agent

@rt.function_node

def check_medication_status(senior_id: str, missed_doses: int) -> dict:

"""Check if a senior has missed doses and trigger reminders.

Args:

senior_id (str): The ID of the senior to check.

missed_doses (int): Number of consecutive missed doses.

"""

if missed_doses >= 2:

return {"action": "critical", "trigger_call": True}

return {"action": "remind", "trigger_call": missed_doses > 0}

# Activity monitoring agent

@rt.function_node

def check_activity(last_movement_mins: int, waking_hours: bool) -> dict:

"""Check for dangerous inactivity periods.

Args:

last_movement_mins (int): Minutes since last movement detected.

waking_hours (bool): Whether it is currently waking hours.

"""

if last_movement_mins > 360 and waking_hours:

return {"alert": "critical", "message": "No movement for 6+ hours"}

return {"alert": "ok"}

# Claude AI orchestrator agent

orchestrator = rt.agent_node(

name="SeniorCare Orchestrator",

llm=rt.llm.AnthropicLLM("claude-sonnet-4-6"),

tool_nodes=[check_medication_status, check_activity],

system_message="""

You are SeniorCare AI, an intelligent health monitoring orchestrator.

Given real-time wearable health data, assess the situation and decide which agents to activate.

Always respond with a JSON object: {urgency, agents_to_trigger, calling_agent_needed, alert_message}

CRITICAL triggers: HR >120 or <45 bpm, SpO2 <90%, no movement >6h, missed 2+ doses.

"""

)

# Run the orchestrator with health data

with rt.Session(context={"senior_id": "senior_001"}) as session:

result = await [rt.call](http://rt.call)(

orchestrator,

"Heart rate: 128bpm, SpO2: 87%, no movement: 380 mins, missed doses: 2"

)

print(result.text)

```

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| GenAI Brain | Claude claude-sonnet-4-6 (Anthropic) |
| Agent Framework | **Railtracks** |
| Wearable | Samsung Galaxy Watch + Health SDK |
| Cloud | AWS Lambda + API Gateway |
| Voice/Video Calls | Twilio Voice + Video |
| Database | AWS DynamoDB |
| Family Dashboard | React + Tailwind |

## 🚀 Quick Start

```

git clone https://github.com/KIRTIRAJ4327/AI-Senior-Citizen-Watch-Tracker

cd AI-Senior-Citizen-Watch-Tracker

pip install -r requirements.txt

cp .env.example .env   # add your API keys

python seniorcare-cloud/orchestrator/[handler.py](http://handler.py)

```

## 🔑 Environment Variables

Create a `.env` file (never commit this):

```

ANTHROPIC_API_KEY=sk-ant-...

TWILIO_ACCOUNT_SID=AC...

TWILIO_AUTH_TOKEN=...

TWILIO_PHONE_NUMBER=+1...

```

## 📁 Project Structure

```

AI-Senior-Citizen-Watch-Tracker/

├── [README.md](http://README.md)

├── requirements.txt

├── .env.example

├── .gitignore

├── [Architecture.md](http://Architecture.md)

├── Architecture.png

├── seniorcare-cloud/

│   ├── orchestrator/

│   │   └── [handler.py](http://handler.py)        ← Claude AI brain

│   ├── agents/

│   │   ├── sleep_[agent.py](http://agent.py)

│   │   ├── activity_[agent.py](http://agent.py)

│   │   ├── medication_[agent.py](http://agent.py)

│   │   ├── refill_[agent.py](http://agent.py)

│   │   └── calling_[agent.py](http://agent.py)  ← Twilio voice/video

│   └── models/

│       └── health_[data.py](http://data.py)

├── mock-data/

│   ├── normal_day.json

│   └── critical_alert.json

└── android/

└── MockDataSender.kt

```

## 🎯 Demo Scenarios

**Normal Day** — `mock-data/normal_day.json`
```

{"heart_rate": 72, "spo2": 98, "steps": 3241,

"last_movement_mins": 15, "sleep_hours": 7.2,

"pills_remaining": 12, "missed_doses": 0}

```

**Critical Alert** — `mock-data/critical_alert.json`
```

{"heart_rate": 128, "spo2": 87, "steps": 200,

"last_movement_mins": 380, "sleep_hours": 4.1,

"pills_remaining": 3, "missed_doses": 2}

```

## 🏆 Hackathon

Built for Genesis GenAI 2026 Hackathon.

Built with Railtracks — https://github.com/RailtownAI/railtracks
```

---

## File 2 — requirements.txt

Create `requirements.txt` at the repo root and paste this:

```
anthropicrailtracks
railtracks-cli
twilio>=9.0.0
boto3>=1.34.0
botocore>=1.34.0
python-dotenv>=1.0.0
pydantic>=2.0.0
fastapi>=0.110.0
uvicorn>=0.29.0
requests>=2.31.0
```

---

## File 3 — .env.example

Create `.env.example` (safe to commit — no real keys):

```
# Anthropic Claude API
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Twilio
TWILIO_ACCOUNT_SID=ACyour-sid-here
TWILIO_AUTH_TOKEN=your-auth-token-here
TWILIO_PHONE_NUMBER=+1XXXXXXXXXX

# Senior contact (for demo)
SENIOR_PHONE=+1XXXXXXXXXX
FAMILY_PHONE=+1XXXXXXXXXX
```

---

## File 4 — mock-data/normal_day.json

```json
{
  "senior_id": "senior_001",
  "trigger_type": "scheduled",
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

## File 5 — mock-data/critical_alert.json

```json
{
  "senior_id": "senior_001",
  "trigger_type": "threshold",
  "health_data": {
    "heart_rate": 128,
    "spo2": 87,
    "steps": 200,
    "last_movement_mins": 380,
    "sleep_hours": 4.1,
    "sleep_quality": "poor",
    "last_medication_time": "08:00",
    "next_medication_time": "14:00",
    "pills_remaining": 3,
    "missed_doses": 2
  }
}
```

---

## Git Commands — Do This Now

```bash
# 1. Remove the exposed .env file
git rm .env
echo ".env" >> .gitignore

# 2. Create .env.example (safe)
touch .env.example  # paste content above

# 3. Create README.md
touch README.md  # paste content above

# 4. Create requirements.txt
touch requirements.txt  # paste content above

# 5. Create mock-data folder
mkdir mock-data
touch mock-data/normal_day.json
touch mock-data/critical_alert.json

# 6. Commit everything
git add .
git commit -m "feat: add README, requirements.txt, mock data, fix .env security"
git push
```

> ⚠️ After pushing, go to Anthropic + Twilio dashboards and regenerate new API keys. Your old keys were exposed.
> 

**How Railtracks wraps your multi-agent system:**

python

`import railtracks as rt

# Each of your agents becomes an @rt.function_node tool
@rt.function_node
def check_medication_status(senior_id: str, missed_doses: int) -> dict:
    """Check if senior missed doses and trigger reminders."""
    ...

# Claude IS your orchestrator agent
orchestrator = rt.agent_node(
    name="SeniorCare Orchestrator",
    llm=rt.llm.AnthropicLLM("claude-sonnet-4-6"),  # your existing Claude call
    tool_nodes=[check_medication_status, check_activity],
    system_message="You are SeniorCare AI..."
)

# Run it — Railtracks handles the routing automatically
with rt.Session() as session:
    result = await rt.call(orchestrator, health_data_prompt)`

**Why this is a win-win:**

- Your orchestrator code barely changes — you're wrapping what you already planned to build
- You get the **built-in visualizer** free (`railtracks viz`) — shows execution tree, timing, all agent calls. Great for demoing to judges
- You qualify for **up to $700 bonus cash** just by adding `railtracks` to `requirements.txt` and README

**Do this in the next 10 minutes:**

1. Run `git rm .env` — your keys are exposed right now
2. Copy the README and requirements.txt from the Notion page above
3. Commit and push — you're done with the