"""
ElderHarmony – Mood Tool Functions
====================================
Mood assessment and wellness recommendation generation for the EmoCare agent.

To add a new mood tool:
  1. Add a @rt.function_node function below
  2. Import it in _tool_registry.py and add to the relevant agent list
"""

import logging
import railtracks as rt

logger = logging.getLogger(__name__)


@rt.function_node
def assess_mood(mood_score: float) -> dict:
    """Assess emotional wellbeing from mood score on a 1-5 scale.

    Args:
        mood_score: Self-reported mood score from 1.0 (very low) to 5.0 (excellent).

    Returns:
        dict with category, mood_score, status (low/ok), low_mood flag,
        and trigger_call flag (True if mood < 3, indicating Calling agent should act).
    """
    low_mood = mood_score < 3.0
    return {
        "category": "mood",
        "mood_score": mood_score,
        "status": "low" if low_mood else "ok",
        "low_mood": low_mood,
        "trigger_call": low_mood,
    }


@rt.function_node
def build_mood_recommendations(mood_score: float, steps: int, sleep_hours: float) -> dict:
    """Build personalized wellness recommendations based on mood, activity, and sleep.

    Args:
        mood_score: Self-reported mood score from 1.0 to 5.0.
        steps: Daily step count.
        sleep_hours: Hours of sleep in last 24h.

    Returns:
        dict with recommendations list and overall wellness summary.
    """
    recommendations = []

    if mood_score < 3.0:
        recommendations.append("Let's call a family member — social connection helps lift mood.")
        recommendations.append("Try some gentle music or a favorite TV show for comfort.")
    elif mood_score < 4.0:
        recommendations.append("Your mood is fair. A short chat with a friend could brighten your day.")

    if steps < 1000:
        recommendations.append("Fresh air helps! Consider a 10-minute stroll outside.")
    elif steps < 3000:
        recommendations.append("Good start on steps today. A short walk could boost your mood further.")

    if sleep_hours < 4:
        recommendations.append("Very little sleep — consider a short nap and talk to your provider.")
    elif sleep_hours < 6:
        recommendations.append("Sleep was short. Try a regular bedtime routine tonight.")

    if not recommendations:
        recommendations.append("You're doing great! Keep up the good habits.")

    return {
        "mood_score": mood_score,
        "recommendations": recommendations,
        "wellness_summary": "low" if mood_score < 3.0 else ("fair" if mood_score < 4.0 else "good"),
    }
