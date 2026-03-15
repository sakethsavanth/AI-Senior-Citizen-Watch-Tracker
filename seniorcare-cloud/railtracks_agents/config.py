"""
ElderHarmony – Railtracks Configuration
=========================================
LLM provider setup (GPT-OSS 120B via OpenAICompatibleProvider)
and observability configuration.

Environment variables:
  OPENAI_API_KEY  – API key for the GPT-OSS endpoint (default: "test")
  AWS_LAMBDA_FUNCTION_NAME – set automatically in Lambda; controls save_state
"""

import os
import railtracks as rt

IS_LAMBDA = bool(os.getenv("AWS_LAMBDA_FUNCTION_NAME"))

LLM = rt.llm.OpenAICompatibleProvider(
    model_name="openai/gpt-oss-120b",
    api_base="https://vjioo4r1vyvcozuj.us-east-2.aws.endpoints.huggingface.cloud/v1",
    api_key=os.getenv("OPENAI_API_KEY", "test"),
)


def configure_observability():
    """Enable Railtracks logging and state saving for visualization."""
    rt.enable_logging(level="INFO")
    rt.set_config(save_state=not IS_LAMBDA)
