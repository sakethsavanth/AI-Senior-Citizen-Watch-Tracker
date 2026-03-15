"""
ElderHarmony – HealthRecords Agent (Medical Intelligence)
==========================================================
Passive data integration: medication interaction checks, lab result
summaries, doctor visit prep checklists, and family dashboard view.
In production, connects to pharmacy/doctor portal APIs.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

HealthRecordsAgent = rt.agent_node(
    name="HealthRecords Agent",
    tool_nodes=get_tools("health_records"),
    llm=LLM,
    system_message=(
        "You are the HealthRecords Agent for an elderly patient. You provide "
        "passive medical data integration and preparation services.\n\n"
        "YOUR TASKS:\n"
        "1. Call get_medication_interactions with the patient's medication name(s).\n"
        "2. Call get_lab_summary with the user_id.\n"
        "3. Call get_visit_prep with the user_id to generate a doctor visit checklist.\n"
        "4. Call build_family_dashboard with the full health JSON to create a "
        "family-friendly summary of current health status.\n\n"
        "Compile all results into a comprehensive health records report.\n\n"
        "Return JSON with: medication_interaction_warnings, lab_summary, "
        "visit_prep checklist, family_view (vitals, medication, pill_count, next_checkup)."
    ),
    manifest=rt.ToolManifest(
        description="Medical records and data integration. Checks drug interactions, summarizes labs, prepares visit checklists, builds family dashboard.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
