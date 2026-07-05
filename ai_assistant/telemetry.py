from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass
from typing import Any, Dict, Optional

from ai_assistant.config import AiAssistantConfig
from ai_assistant.captain_atlas import resolve_assistant_for_scope

_logger = logging.getLogger("ai_assistant.telemetry")


@dataclass(frozen=True)
class AiTelemetryRecord:
    event: str
    model: Optional[str]
    latency_ms: float
    cache_hit: bool
    input_tokens: int
    output_tokens: int
    total_tokens: int
    estimated_cost_usd: float
    processing_time_ms: int
    prompt_version: str
    source: str
    scope: str
    fallback_reason: Optional[str]
    client_request_id: Optional[str]
    token_usage: Dict[str, int]
    assistant_name: Optional[str] = None
    persona_version: Optional[str] = None

    def to_log_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        return payload


class AiTelemetryLogger:
    """Her AI isteğini yapılandırılmış şekilde loglar."""

    def __init__(self, config: AiAssistantConfig) -> None:
        self._config = config

    def log(self, record: AiTelemetryRecord) -> None:
        payload = record.to_log_dict()
        _logger.info("%s", json.dumps(payload, ensure_ascii=False))

    def build_record(
        self,
        *,
        model: Optional[str],
        latency_ms: float,
        cache_hit: bool,
        input_tokens: int,
        output_tokens: int,
        processing_time_ms: int,
        prompt_version: str,
        source: str,
        scope: str,
        fallback_reason: Optional[str],
        client_request_id: Optional[str],
    ) -> AiTelemetryRecord:
        total = input_tokens + output_tokens
        token_usage = {
            "input": input_tokens,
            "output": output_tokens,
            "total": total,
        }
        assistant_name, persona_version, _tone = resolve_assistant_for_scope(scope)
        return AiTelemetryRecord(
            event="ai_assistant_request",
            model=model,
            latency_ms=round(latency_ms, 2),
            cache_hit=cache_hit,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total,
            estimated_cost_usd=self._config.estimate_cost_usd(
                input_tokens=input_tokens,
                output_tokens=output_tokens,
            ),
            processing_time_ms=processing_time_ms,
            prompt_version=prompt_version,
            source=source,
            scope=scope,
            fallback_reason=fallback_reason,
            client_request_id=client_request_id,
            token_usage=token_usage,
            assistant_name=assistant_name,
            persona_version=persona_version,
        )
