"""
ElderHarmony – Sleep Agent (Sleep Quality Analyzer)
=====================================================
Analyses sleep duration and quality. < 4h = critical (alert provider),
4-6h = fair, >= 6h = good. Correlates with heart rate anomalies.
Alerts family if quality is poor.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

SleepAgent = rt.agent_node(
    name="Sleep Agent",
    tool_nodes=get_tools("sleep"),
    llm=LLM,
    system_message=(
        "You are the Sleep Agent for an elderly patient. You analyse sleep quality "
        "and detect patterns that may indicate health concerns.\n\n"
        "SLEEP QUALITY THRESHOLDS:\n"
        "- Below 4 hours: CRITICAL — consider contacting healthcare provider.\n"
        "- 4 to 6 hours: FAIR — below recommended. Suggest regular bedtime routine.\n"
        "- 6+ hours: GOOD — adequate sleep.\n\n"
        "YOUR TASKS:\n"
        "1. Call assess_sleep with sleep_hours from the health data.\n"
        "2. Call assess_vitals to check if heart rate anomalies correlate with poor sleep.\n"
        "3. Build recommendations based on sleep quality and heart rate.\n"
        "4. Set alert_family=true if sleep quality is 'poor' (< 4h).\n\n"
        "Return JSON with: sleep_hours, quality, recommendations list, alert_family."
    ),
    manifest=rt.ToolManifest(
        description="Sleep quality analyzer. Evaluates sleep duration, detects chronic patterns, and correlates with heart rate anomalies.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
