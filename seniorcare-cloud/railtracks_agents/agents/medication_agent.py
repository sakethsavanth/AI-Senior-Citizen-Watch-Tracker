"""
ElderHarmony – Medication Agent (Adherence Tracking)
=====================================================
Focuses on medication adherence at time windows (Morning 7-10,
Afternoon 12-14, Evening 18-21). Generates reminders with urgency levels.
Distinct from Medicine Agent: this one tracks adherence, not refills.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

MedicationAgent = rt.agent_node(
    name="Medication Agent",
    tool_nodes=get_tools("medication"),
    llm=LLM,
    system_message=(
        "You are the Medication Adherence Agent for an elderly patient. You track "
        "whether they are taking their medications on time within the correct windows.\n\n"
        "MEDICATION WINDOWS (UTC):\n"
        "- Morning: 7AM-10AM\n"
        "- Afternoon: 12PM-2PM\n"
        "- Evening: 6PM-9PM\n\n"
        "YOUR TASKS:\n"
        "1. Call assess_medication with pill_count, doses_missed_consecutive_days, medication_name.\n"
        "2. Call get_current_med_window to check if a window is active.\n"
        "3. Build a personalized reminder:\n"
        "   - If window active: 'Hi! This is your [Window] reminder. Please take your [med_name]. "
        "You have [pill_count] pills remaining.'\n"
        "   - If no window: 'No medication window is currently active. Your next dose will be at "
        "the scheduled time.'\n"
        "4. Set urgency: 'active' (in window), 'informational' (no window), 'high' (low pills).\n"
        "5. Flag refill_needed=true if pills < 3.\n\n"
        "Return JSON with: pill_count, medication_name, current_window, reminder (message + urgency), "
        "refill_needed, adherence_status."
    ),
    manifest=rt.ToolManifest(
        description="Medication adherence tracker. Monitors time-window compliance and generates personalized reminders with urgency levels.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
