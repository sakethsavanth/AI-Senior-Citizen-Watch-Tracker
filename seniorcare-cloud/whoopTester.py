"""
Whoop recovery data + Hugging Face (OpenAI-compatible) endpoint.
Fetches Whoop recovery, then uses the HF model for a brief health insight.
"""

import json
import os
import sys
from datetime import datetime, timedelta


def safe_print(text: str) -> None:
    """Print text safely on Windows (avoids UnicodeEncodeError with cp1252)."""
    if not text:
        return
    enc = sys.stdout.encoding or "utf-8"
    try:
        print(text)
    except UnicodeEncodeError:
        print(text.encode(enc, errors="replace").decode(enc))

from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

# Load .env from project root (when run from seniorcare-cloud/)
load_dotenv(Path(__file__).resolve().parent.parent / ".env")
load_dotenv()  # also current dir

# Hugging Face endpoint (OpenAI-compatible)
client = OpenAI(
    api_key=os.getenv("HF_TOKEN", "test"),
    base_url="https://vjioo4r1vyvcozuj.us-east-2.aws.endpoints.huggingface.cloud/v1",
)


def fetch_whoop_recovery():
    """Fetch last 7 days Whoop recovery data. Returns None if Whoop SDK not used."""
    try:
        from whoop_sdk import Whoop

        whoop = Whoop()
        whoop.login()
        end_date = datetime.now()
        start_date = end_date - timedelta(days=7)
        recoveries = whoop.get_recovery(
            start=start_date.isoformat() + "Z",
            end=end_date.isoformat() + "Z",
            limit=25,
        )
        return recoveries
    except Exception as e:
        print(f"Whoop fetch skipped: {e}")
        return None


def main():
    # Optional: Whoop recovery data
    recovery_summary = None
    whoop_data = fetch_whoop_recovery()
    if whoop_data:
        records = whoop_data.get("records", [])
        scored = [r for r in records if r.get("score_state") == "SCORED"]
        print("Whoop Recovery Data (HRV, SpO2, Skin Temp):\n")
        for rec in scored[:5]:
            score = rec.get("score", {})
            print(f"  Cycle {rec.get('cycle_id')}: HRV={score.get('hrv_rmssd_milli')} ms, SpO2={score.get('spo2_percentage')}%, Recovery={score.get('recovery_score')}")
        recovery_summary = json.dumps(
            [
                {
                    "hrv_ms": r.get("score", {}).get("hrv_rmssd_milli"),
                    "spo2": r.get("score", {}).get("spo2_percentage"),
                    "recovery": r.get("score", {}).get("recovery_score"),
                }
                for r in scored[:5]
            ],
            indent=2,
        )
    else:
        print("No Whoop data; using HF model for a simple reply.\n")

    # Hugging Face (OpenAI-compatible) call
    user_content = (
        "In one sentence, give a short health or wellness tip for a senior."
        if recovery_summary
        else "Say hello in one sentence."
    )
    if recovery_summary:
        user_content = f"Based on this recovery data (HRV, SpO2, recovery score), give one short wellness tip:\n{recovery_summary}\n\nReply in one sentence."

    try:
        resp = client.chat.completions.create(
            model="openai/gpt-oss-120b",
            messages=[
                {"role": "system", "content": "You are a helpful assistant. Reply briefly in one sentence."},
                {"role": "user", "content": user_content},
            ],
            max_tokens=256,
        )
    except Exception as e:
        print("\n[ERROR] Hugging Face API call failed:", e)
        print("  Check HF_TOKEN or OPENAI_API_KEY in .env (use a Hugging Face token hf_...).")
        return

    # Extract content; some HF endpoints use slightly different shapes
    reply = ""
    if resp.choices:
        first = resp.choices[0]
        msg = getattr(first, "message", first)
        reply = (getattr(msg, "content", None) if hasattr(msg, "content") else getattr(msg, "text", None)) or ""
    reply = (reply or "").strip()

    if not reply:
        first = resp.choices[0] if resp.choices else None
        finish = getattr(first, "finish_reason", None) if first else None
        print("\nModel reply: (no text returned)")
        print("  finish_reason:", finish)
        if getattr(resp, "usage", None):
            print("  usage:", resp.usage)
    else:
        print("\nModel reply:", end=" ")
        safe_print(reply)


if __name__ == "__main__":
    main()
