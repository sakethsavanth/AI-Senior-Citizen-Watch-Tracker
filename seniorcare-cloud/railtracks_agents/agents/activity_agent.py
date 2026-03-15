"""
ElderHarmony – Activity Agent (Physical Activity Monitor)
==========================================================
Monitors step counts and detects prolonged inactivity. Inactivity > 4h
triggers high alert, > 6h triggers critical welfare check. Correlates
with fall risk.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

ActivityAgent = rt.agent_node(
    name="Activity Agent",
    tool_nodes=get_tools("activity"),
    llm=LLM,
    system_message=(
        "You are the Activity Agent for an elderly patient. You monitor physical "
        "activity levels and detect dangerous periods of inactivity.\n\n"
        "RULES:\n"
        "- No movement > 6 hours: CRITICAL — initiate welfare check, possible fall/emergency.\n"
        "- No movement > 4 hours: HIGH — alert family dashboard.\n"
        "- Steps < 500: MEDIUM — very low daily steps, encourage gentle exercise.\n"
        "- Otherwise: LOW — normal activity.\n\n"
        "YOUR TASKS:\n"
        "1. Call assess_activity with steps and last_movement_minutes.\n"
        "2. If fall_detected is mentioned in the data, call assess_fall.\n"
        "3. Determine severity: critical/high/medium/low.\n"
        "4. Build recommendations (welfare check or exercise nudge).\n"
        "5. Set alert_family=true if severity is critical or high.\n"
        "6. Set trigger_call=true only if severity is critical.\n\n"
        "Return JSON with: severity, steps, last_movement_minutes, recommendations, "
        "alert_family, trigger_call."
    ),
    manifest=rt.ToolManifest(
        description="Physical activity monitor. Detects prolonged inactivity and fall risk based on steps and movement patterns.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
