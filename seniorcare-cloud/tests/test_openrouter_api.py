"""
SeniorCare AI - OpenRouter API Smoke Test
=========================================
Quick validation script for OpenRouter connectivity and model responses.

Usage
-----
    cd seniorcare-cloud
    python tests/test_openrouter_api.py --check-env
    python tests/test_openrouter_api.py
    python tests/test_openrouter_api.py --model anthropic/claude-sonnet-4.5
"""

from __future__ import annotations

import argparse
import json
import os
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, PROJECT_ROOT)

from dotenv import load_dotenv

from services.openrouter_client import OpenRouterClient


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OpenRouter API smoke test")
    parser.add_argument(
        "--model",
        default=os.getenv("OPENROUTER_MODEL", "anthropic/claude-sonnet-4.5"),
        help="OpenRouter model id",
    )
    parser.add_argument(
        "--check-env",
        action="store_true",
        help="Only check required environment variables without calling the API",
    )
    return parser.parse_args()


def check_env() -> tuple[bool, str]:
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        return False, "Missing OPENROUTER_API_KEY"
    if len(api_key) < 12:
        return False, "OPENROUTER_API_KEY looks too short"
    return True, "Environment looks valid"


def run_smoke_test(model: str) -> int:
    client = OpenRouterClient(model_id=model)

    system_prompt = (
        "You are a strict API test assistant. "
        "Return only compact valid JSON with keys provider, model, ok, and message."
    )
    user_prompt = "Reply with a JSON object proving this endpoint is working."

    raw = client.invoke(system_prompt, user_prompt)

    print("\nRaw response:")
    print(raw)

    try:
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
            cleaned = cleaned.rsplit("```", 1)[0]

        parsed = json.loads(cleaned)
        print("\nParsed JSON response:")
        print(json.dumps(parsed, indent=2))
        return 0
    except json.JSONDecodeError:
        print("\nResponse was not valid JSON. API call still succeeded.")
        return 0


def main() -> int:
    load_dotenv(os.path.join(PROJECT_ROOT, ".env"))
    args = parse_args()

    ok, message = check_env()
    print(f"Env check: {message}")
    print(f"Model: {args.model}")

    if not ok:
        print("Set OPENROUTER_API_KEY in seniorcare-cloud/.env and try again.")
        return 1

    if args.check_env:
        return 0

    return run_smoke_test(args.model)


if __name__ == "__main__":
    raise SystemExit(main())
