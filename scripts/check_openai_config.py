#!/usr/bin/env python3
"""OpenAI / Captain Atlas yapılandırma smoke — API key değerini asla yazdırmaz."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))


def _load_env_file() -> None:
    env_path = ROOT / ".env"
    if not env_path.is_file():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key and os.getenv(key) is None:
            os.environ[key] = value


def main() -> int:
    parser = argparse.ArgumentParser(description="Check OpenAI/Captain Atlas config (safe).")
    parser.add_argument(
        "--live",
        action="store_true",
        help="Opsiyonel: küçük bir OpenAI test çağrısı yap (gerçek key gerekir).",
    )
    args = parser.parse_args()

    _load_env_file()
    from ai_assistant.config import AiAssistantConfig

    cfg = AiAssistantConfig.from_env()
    health = cfg.health_payload()

    print("AI_ASSISTANT_ENABLED:", cfg.ai_assistant_enabled)
    print("OPENAI_KEY_PRESENT:", bool(cfg.openai_api_key))
    print("OPENAI_MODEL:", cfg.openai_model or "(missing)")
    print("AI_RUNTIME_READY:", cfg.is_operational())
    print("STREAMING_ENABLED:", cfg.streaming_enabled)
    print("TIMEOUT_SECONDS:", cfg.ai_timeout_seconds)
    print("HEALTH:", health)

    if not args.live:
        return 0

    if not cfg.is_operational():
        print("LIVE_REQUEST: skipped — runtime not ready")
        return 1

    from ai_assistant.openai_client import OpenAIResponsesClient
    from ai_assistant.openai_errors import classify_openai_failure, sanitize_log_message

    client = OpenAIResponsesClient(cfg)
    try:
        result = client.generate_structured(
            system_prompt="You are a test harness. Reply with minimal JSON only.",
            user_prompt=(
                'Return JSON: {"summary_tr":"ok","confidence":"low",'
                '"recommended_actions":[],"hotspot_insights":[],'
                '"conditions_comment_tr":"test","species_comment_tr":"test",'
                '"limitations_tr":[],"safety_reminders_tr":[]}'
            ),
        )
    except Exception as exc:
        reason = classify_openai_failure(exc)
        print("LIVE_REQUEST: fail")
        print("LIVE_SOURCE: fallback")
        print("LIVE_FALLBACK_REASON:", reason)
        print("LIVE_ERROR:", sanitize_log_message(str(exc))[:240])
        return 1

    preview = (result.output_text or "")[:120].replace("\n", " ")
    print("LIVE_REQUEST: ok")
    print("LIVE_SOURCE: ai")
    print("LIVE_MODEL:", result.model)
    print("LIVE_LATENCY_MS:", round(result.latency_ms, 1))
    print("LIVE_OUTPUT_PREVIEW:", preview)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
