from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Optional

from ai_assistant.cache import AiResponseCacheProtocol, InMemoryAiResponseCache
from ai_assistant.config import AiAssistantConfig
from ai_assistant.context_builder import AiAssistantContextBuilder
from ai_assistant.fallback import AiAssistantFallbackBuilder
from ai_assistant.guardrails import AiAssistantGuardrails
from ai_assistant.openai_client import OpenAIResponsesClient, OpenAIResponsesClientProtocol
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from ai_assistant.quota import InMemoryAiQuotaStore
from ai_assistant.rate_limiter import InMemoryAiRateLimiter
from ai_assistant.service import AiAssistantService
from ai_assistant.telemetry import AiTelemetryLogger
from ai_assistant.telemetry_store import (
    AiTelemetryStoreProtocol,
    CompositeAiTelemetryStore,
    InMemoryAiTelemetryStore,
    JsonlAiTelemetryStore,
)


@lru_cache(maxsize=1)
def get_ai_assistant_config() -> AiAssistantConfig:
    return AiAssistantConfig.from_env()


@lru_cache(maxsize=1)
def get_ai_rate_limiter() -> InMemoryAiRateLimiter:
    cfg = get_ai_assistant_config()
    return InMemoryAiRateLimiter(limit_per_minute=cfg.ai_rate_limit_per_minute)


@lru_cache(maxsize=1)
def get_ai_quota_store() -> InMemoryAiQuotaStore:
    return InMemoryAiQuotaStore()


@lru_cache(maxsize=1)
def get_ai_telemetry_store() -> AiTelemetryStoreProtocol:
    cfg = get_ai_assistant_config()
    memory = InMemoryAiTelemetryStore()
    jsonl: Optional[JsonlAiTelemetryStore] = None
    if cfg.ai_telemetry_persist_enabled:
        jsonl = JsonlAiTelemetryStore(Path(cfg.ai_telemetry_jsonl_path))
    return CompositeAiTelemetryStore(memory, jsonl=jsonl)


def build_ai_assistant_service(
    config: Optional[AiAssistantConfig] = None,
    *,
    openai_client: Optional[OpenAIResponsesClientProtocol] = None,
    cache: Optional[AiResponseCacheProtocol] = None,
    telemetry_store: Optional[AiTelemetryStoreProtocol] = None,
) -> AiAssistantService:
    """
    DI fabrikası — testlerde bağımlılıklar enjekte edilebilir.
    Production'da Redis tabanlı cache/quota/rate-limit store'ları enjekte edilebilir.
    """
    cfg = config or get_ai_assistant_config()
    context_builder = AiAssistantContextBuilder()
    prompt_builder = AiAssistantPromptBuilder(cfg)
    guardrails = AiAssistantGuardrails()
    fallback_builder = AiAssistantFallbackBuilder()
    telemetry = AiTelemetryLogger(cfg)
    response_cache = cache or InMemoryAiResponseCache(ttl_seconds=cfg.cache_ttl_seconds)
    store = telemetry_store or get_ai_telemetry_store()

    client = openai_client
    if client is None and cfg.is_openai_configured():
        client = OpenAIResponsesClient(cfg)

    return AiAssistantService(
        cfg,
        context_builder=context_builder,
        prompt_builder=prompt_builder,
        guardrails=guardrails,
        fallback_builder=fallback_builder,
        cache=response_cache,
        telemetry=telemetry,
        telemetry_store=store,
        openai_client=client,
    )
