"""
Shared — AI Client
===================
Thin wrapper around OpenAI used by every platform.

Usage:
    from shared.ai_client import call_openai
    result = call_openai(
        system_prompt="You are an expert copywriter.",
        user_prompt="Write a product description for...",
        api_key=Config.OPENAI_API_KEY,
    )
    # result = {"content": {...}, "tokens_used": 123}
"""

import json
import logging

logger = logging.getLogger(__name__)


def call_openai(
    *,
    system_prompt,
    user_prompt,
    api_key,
    model="gpt-4o-mini",
    temperature=0.7,
    max_tokens=1000,
    json_mode=True,
):
    """
    Call the OpenAI chat completion API.

    If json_mode=True the response is parsed as JSON.
    Returns dict with 'content' (parsed JSON or raw text) and 'tokens_used'.
    """
    from openai import OpenAI

    client = OpenAI(api_key=api_key)

    kwargs = dict(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=temperature,
        max_tokens=max_tokens,
    )
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    response = client.chat.completions.create(**kwargs)

    tokens_used = response.usage.total_tokens if response.usage else 0
    raw = response.choices[0].message.content.strip()

    if json_mode:
        content = json.loads(raw)
    else:
        content = raw

    return {"content": content, "tokens_used": tokens_used}
