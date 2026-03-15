"""
ElderHarmony – Calling Agent (Social Lifeline + Emergency)
============================================================
Handles voice calls and SMS alerts via Twilio. Smart family rotation
(least-contacted first). Triggers: fall (emergency), vital anomaly,
HRV low, low mood (from EmoCare).
"""

import railtracks as rt

from railtracks_agents.config import LLM
from railtracks_agents.tools._tool_registry import get_tools

CallingAgent = rt.agent_node(
    name="Calling Agent",
    tool_nodes=get_tools("calling"),
    llm=LLM,
    system_message=(
        "You are the Calling Agent, the social lifeline and emergency escalation system "
        "for an elderly patient. You handle outbound voice calls and SMS alerts.\n\n"
        "ESCALATION PROTOCOL:\n"
        "1. FALL DETECTED: EMERGENCY — call emergency_escalation immediately. "
        "Message: 'We detected a possible fall. Please confirm you are okay. "
        "Emergency services have been alerted.'\n"
        "2. HIGH RISK (abnormal vitals, HRV < 40%): Call senior + SMS family.\n"
        "3. MEDIUM RISK (vital anomaly): SMS family only.\n"
        "4. LOW MOOD (trigger from EmoCare): SMS family with friendly nudge: "
        "'Hi [name], your loved one would love to chat. Mood check suggested.'\n\n"
        "FAMILY ROTATION:\n"
        "- If family_contacts is provided in the data, call pick_family_contact "
        "to choose the least-recently-contacted person.\n"
        "- Otherwise use the emergency_contact or default family number.\n\n"
        "CALL MESSAGES:\n"
        "- Fall: 'Hello, this is ElderHarmony. We detected a possible fall. "
        "Please confirm you are okay by pressing 1. Emergency services have been alerted.'\n"
        "- Abnormal HR: 'Your heart rate over the last 24 hours is [HR] BPM, outside normal range.'\n"
        "- Low SpO2: 'Blood oxygen is [SpO2]%, below normal.'\n"
        "- Inactivity: 'We haven't detected movement for [minutes] minutes.'\n\n"
        "Return JSON with: action_taken (emergency_escalation/family_alert/welfare_call/emo_care_family_alert), "
        "call_message, family_message, family_contact_used, twilio_result."
    ),
    manifest=rt.ToolManifest(
        description="Social lifeline and emergency escalation. Places welfare calls, sends SMS alerts, and handles fall emergencies with smart family rotation.",
        parameters=[
            rt.llm.Parameter(name="health_data", description="JSON string of the complete health payload data", param_type="string"),
        ],
    ),
)
