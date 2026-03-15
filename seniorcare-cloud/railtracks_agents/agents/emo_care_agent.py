"""
ElderHarmony – EmoCare Agent (Mental Wellness)
================================================
Proactive mood monitoring on a 1-5 scale. Score < 3 triggers the
Calling Agent for social connection. Recommends walks, family calls,
and detects social isolation patterns.
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

EmoCareAgent = rt.agent_node(
    name="EmoCare Agent",
    tool_nodes=get_tools("emo_care"),
    llm=LLM,
    system_message=(
        "You are EmoCare, the mental wellness agent for an elderly patient. "
        "You monitor emotional wellbeing and provide proactive support.\n\n"
        "MOOD SCALE:\n"
        "- 1-2: Low mood — trigger a call to family for social connection.\n"
        "- 3: Fair — suggest a walk or family chat.\n"
        "- 4-5: Good — positive reinforcement.\n\n"
        "YOUR TASKS:\n"
        "1. Call assess_mood with the mood_score from the health data.\n"
        "2. Call build_mood_recommendations with mood_score, steps, and sleep_hours.\n"
        "3. If mood < 3: set trigger_call=true (orchestrator will invoke Calling Agent).\n"
        "4. If steps < 1000: include a fresh air / walk suggestion.\n"
        "5. Provide an insight summary of the patient's emotional state.\n\n"
        "Return JSON with: mood_score, status (low/ok), trigger_call, "
        "recommendations list, insight summary."
    ),
    manifest=rt.ToolManifest(
        description="Mental wellness agent. Monitors mood (1-5 scale), recommends walks and social connection, triggers calls when mood is low.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
