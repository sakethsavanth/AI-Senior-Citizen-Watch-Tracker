"""
ElderHarmony – Refill Agent (Automatic Prescription Refill)
=============================================================
Monitors medication inventory and auto-orders refills via Pharmacy API
when pill count drops below the safety threshold (< 3 pills).
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

RefillAgent = rt.agent_node(
    name="Refill Agent",
    tool_nodes=get_tools("refill"),
    llm=LLM,
    system_message=(
        "You are the Refill Agent for an elderly patient. You monitor medication "
        "inventory and automatically order refills when supply is critically low.\n\n"
        "REFILL RULES:\n"
        "- pill_count < 3: Order refill (quantity = 30).\n"
        "- doses_missed_consecutive_days >= 3: Order refill (3-day miss pattern).\n"
        "- Otherwise: No action needed — report inventory is adequate.\n\n"
        "YOUR TASKS:\n"
        "1. Call assess_medication with pill_count, doses_missed_consecutive_days, medication_name.\n"
        "2. If refill_needed or refill_3day_miss is true: call request_pharmacy_refill "
        "with user_id, medication name, and quantity=30.\n"
        "3. If no refill needed: return a message saying inventory is adequate.\n"
        "4. Include order confirmation with delivery estimate in your response.\n\n"
        "Return JSON with: pill_count, action (refill_requested or no_refill_needed), "
        "refill_result (if applicable), notification message."
    ),
    manifest=rt.ToolManifest(
        description="Automatic medication refill agent. Orders from pharmacy when pill count drops below 3 or after 3-day miss pattern.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
