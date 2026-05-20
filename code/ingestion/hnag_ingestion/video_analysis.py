"""
TikTok video → dish extraction via LLM (caption NLU) + vision (later).
"""
from __future__ import annotations
import os
import json
from typing import Any

from openai import OpenAI

_client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY', ''))

SYSTEM = """Bạn là food vision specialist VN. Trích xuất món ăn + restaurant + region từ caption TikTok.
Trả JSON: { dish_detected, confidence (0-1), cuisine, region_hint (bac|trung|nam|intl), restaurant_mentioned, audio_quote, quality_score (0-100) }"""

def analyze_video(*, caption: str, external_id: str) -> dict[str, Any]:
    """Pure caption NLU for skeleton. Production: + vision keyframe + Whisper ASR."""
    if not caption or not _client.api_key:
        return _empty()

    try:
        resp = _client.chat.completions.create(
            model='gpt-4o-mini',
            response_format={'type': 'json_object'},
            messages=[
                {'role': 'system', 'content': SYSTEM},
                {'role': 'user',   'content': f'CAPTION: {caption}\n\nReturn JSON.'},
            ],
            temperature=0.2,
            max_tokens=300,
        )
        data = json.loads(resp.choices[0].message.content or '{}')
    except Exception:
        return _empty()

    return {
        'dish':       data.get('dish_detected'),
        'confidence': float(data.get('confidence') or 0),
        'cuisine':    data.get('cuisine') or 'vietnamese',
        'region':     data.get('region_hint') or 'other',
        'restaurant': data.get('restaurant_mentioned'),
        'audio':      data.get('audio_quote'),
        'quality':    int(data.get('quality_score') or 50),
    }

def _empty() -> dict[str, Any]:
    return {'dish': None, 'confidence': 0, 'cuisine': None, 'region': None, 'restaurant': None, 'audio': None, 'quality': 0}
