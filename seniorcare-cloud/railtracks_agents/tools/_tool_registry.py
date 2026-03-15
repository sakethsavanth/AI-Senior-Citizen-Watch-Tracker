"""
Tool Registry — Central mapping of agent names to their tool lists.
=====================================================================
This is the key extensibility point for ElderHarmony.

TO ADD A NEW TOOL:
  1. Create a @rt.function_node function in the appropriate tools/*.py file
  2. Import it below
  3. Append it to the relevant agent's list in AGENT_TOOLS
  That's it. No other files need to change.
"""

from railtracks_agents.tools.vitals_tools import (
    assess_vitals,
    assess_hrv,
    assess_fall,
    assess_sleep,
    assess_activity,
    full_health_assessment,
)
from railtracks_agents.tools.medication_tools import (
    assess_medication,
    get_current_med_window,
    request_pharmacy_refill,
)
from railtracks_agents.tools.mood_tools import (
    assess_mood,
    build_mood_recommendations,
)
from railtracks_agents.tools.communication_tools import (
    call_senior,
    alert_family_sms,
    emergency_escalation,
    pick_family_contact,
)
from railtracks_agents.tools.health_records_tools import (
    get_medication_interactions,
    get_lab_summary,
    get_visit_prep,
    build_family_dashboard,
)


AGENT_TOOLS = {
    "vital_sync": [assess_vitals, assess_hrv, assess_fall, assess_sleep, assess_activity, emergency_escalation],
    "activity": [assess_activity, assess_fall],
    "sleep": [assess_sleep, assess_vitals],
    "medicine": [assess_medication, get_current_med_window, request_pharmacy_refill],
    "medication": [assess_medication, get_current_med_window],
    "refill": [assess_medication, request_pharmacy_refill],
    "emo_care": [assess_mood, build_mood_recommendations],
    "calling": [call_senior, alert_family_sms, emergency_escalation, pick_family_contact],
    "health_records": [get_medication_interactions, get_lab_summary, get_visit_prep, build_family_dashboard],
}


def get_tools(agent_name: str) -> list:
    """Return the tool list for a given agent name.

    Args:
        agent_name: Key from AGENT_TOOLS (e.g. 'vital_sync', 'calling').

    Returns:
        List of @rt.function_node tools for the agent.
    """
    return AGENT_TOOLS.get(agent_name, [])
