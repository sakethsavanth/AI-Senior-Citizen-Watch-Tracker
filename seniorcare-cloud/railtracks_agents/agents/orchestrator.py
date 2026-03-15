"""
ElderHarmony – Orchestrator Agent (Master Coordinator)
=======================================================
Central agent that receives health data and coordinates all 9 sub-agents
using the agents-as-tools pattern. Encodes the routing logic from
utils/event_router.py into its system prompt so the LLM decides which
agents to invoke based on the health data.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools.vitals_tools import full_health_assessment
from railtracks_agents.agents.vital_sync_agent import VitalSyncAgent
from railtracks_agents.agents.activity_agent import ActivityAgent
from railtracks_agents.agents.sleep_agent import SleepAgent
from railtracks_agents.agents.medicine_agent import MedicineAgent
from railtracks_agents.agents.medication_agent import MedicationAgent
from railtracks_agents.agents.refill_agent import RefillAgent
from railtracks_agents.agents.emo_care_agent import EmoCareAgent
from railtracks_agents.agents.calling_agent import CallingAgent
from railtracks_agents.agents.health_records_agent import HealthRecordsAgent

Orchestrator = rt.agent_node(
    name="ElderHarmony Orchestrator",
    tool_nodes=[
        full_health_assessment,
        VitalSyncAgent,
        ActivityAgent,
        SleepAgent,
        MedicineAgent,
        MedicationAgent,
        RefillAgent,
        EmoCareAgent,
        CallingAgent,
        HealthRecordsAgent,
    ],
    llm=LLM,
    system_message=(
        "You are ElderHarmony Orchestrator, a senior care AI coordinator managing "
        "the health of an elderly patient. You have 9 specialist sub-agents and a "
        "deterministic triage tool.\n\n"
        "MANDATORY WORKFLOW:\n"
        "1. ALWAYS call full_health_assessment FIRST with the complete health JSON. "
        "This runs deterministic clinical checks and returns overall_risk and critical_flags.\n\n"
        "2. ALWAYS invoke these agents (pass the full health data JSON to each):\n"
        "   - VitalSync Agent: 24hr vital signs monitoring\n"
        "   - Medicine Agent: medication schedule and refills\n"
        "   - Medication Agent: adherence tracking\n"
        "   - HealthRecords Agent: passive data sync and family dashboard\n\n"
        "3. CONDITIONALLY invoke based on the health data:\n"
        "   - Activity Agent: IF steps < 500 OR last_movement_minutes > 240\n"
        "   - Sleep Agent: IF sleep_hours < 6\n"
        "   - Refill Agent: IF pill_count < 3 OR doses_missed_consecutive_days >= 3\n"
        "   - EmoCare Agent: ONLY IF mood_score is present (not null/missing) in the data\n"
        "   - Calling Agent: IF ANY of these conditions:\n"
        "     * fall_detected = true (EMERGENCY — invoke Calling IMMEDIATELY)\n"
        "     * heart_rate < 50 or heart_rate > 120\n"
        "     * spo2 < 92\n"
        "     * hrv_percent < 40\n"
        "     * mood_score < 3\n"
        "     * overall_risk = 'high' from full_health_assessment\n\n"
        "EMERGENCY PROTOCOL:\n"
        "If fall_detected is true, invoke the Calling Agent IMMEDIATELY with the health "
        "data — do not wait for other agents to complete first.\n\n"
        "RESPONSE FORMAT:\n"
        "Collect all agent results and return a consolidated JSON response with:\n"
        "- user_id\n"
        "- overall_risk (from full_health_assessment)\n"
        "- agents_invoked (list of agent names that were called)\n"
        "- triage_result (full_health_assessment output)\n"
        "- agent_results (dict mapping agent name to its response)\n"
        "- summary (brief human-readable summary of the patient's status)"
    ),
)
