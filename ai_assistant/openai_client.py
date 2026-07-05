from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Any, Dict, Optional, Protocol, runtime_checkable

from ai_assistant.config import AiAssistantConfig
from ai_assistant.json_schema import structured_output_format
from ai_assistant.openai_errors import classify_openai_failure, sanitize_log_message
from openai import OpenAI

_logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class OpenAIGenerationResult:
    output_text: str
    input_tokens: int
    output_tokens: int
    total_tokens: int
    latency_ms: float
    model: str


@runtime_checkable
class OpenAIResponsesClientProtocol(Protocol):
    def generate_structured(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        vision_image_base64: Optional[str] = None,
    ) -> OpenAIGenerationResult:
        ...

    def generate_structured_stream(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        vision_image_base64: Optional[str] = None,
    ):
        """Streaming mimarisi — Faz 1'de yalnızca STREAMING_ENABLED=true iken kullanılır."""
        ...


class OpenAIResponsesClient:
    """Resmi OpenAI SDK — Responses API (Chat Completions değil)."""

    def __init__(self, config: AiAssistantConfig) -> None:
        if not config.openai_api_key or not config.openai_model:
            raise ValueError("OpenAI client requires OPENAI_API_KEY and OPENAI_MODEL.")
        self._config = config
        self._client = OpenAI(
            api_key=config.openai_api_key,
            timeout=config.ai_timeout_seconds,
            max_retries=0,
        )

    def generate_structured(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        vision_image_base64: Optional[str] = None,
    ) -> OpenAIGenerationResult:
        if self._config.streaming_enabled:
            raise RuntimeError(
                "Streaming is enabled but non-streaming path was invoked. "
                "Use generate_structured_stream or disable STREAMING_ENABLED."
            )
        started = time.perf_counter()
        try:
            response = self._client.responses.create(
                model=self._config.openai_model,
                input=self._build_input(system_prompt, user_prompt, vision_image_base64),
                text={"format": structured_output_format()},
                max_output_tokens=self._config.ai_max_tokens,
                temperature=self._config.ai_temperature,
            )
        except Exception as exc:
            reason = classify_openai_failure(exc)
            _logger.warning(
                "OpenAI request failed [%s]: %s",
                reason,
                sanitize_log_message(str(exc)),
            )
            raise
        latency_ms = (time.perf_counter() - started) * 1000.0
        output_text = getattr(response, "output_text", None) or _extract_output_text(response)
        usage = getattr(response, "usage", None)
        input_tokens = int(getattr(usage, "input_tokens", 0) or 0)
        output_tokens = int(getattr(usage, "output_tokens", 0) or 0)
        total_tokens = int(getattr(usage, "total_tokens", input_tokens + output_tokens) or 0)
        return OpenAIGenerationResult(
            output_text=output_text,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=total_tokens,
            latency_ms=latency_ms,
            model=self._config.openai_model,
        )

    def generate_structured_stream(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        vision_image_base64: Optional[str] = None,
    ):
        if not self._config.streaming_enabled:
            raise RuntimeError("STREAMING_ENABLED is false.")
        with self._client.responses.stream(
            model=self._config.openai_model,
            input=self._build_input(system_prompt, user_prompt, vision_image_base64),
            text={"format": structured_output_format()},
            max_output_tokens=self._config.ai_max_tokens,
            temperature=self._config.ai_temperature,
        ) as stream:
            yield from stream

    def _build_input(
        self,
        system_prompt: str,
        user_prompt: str,
        vision_image_base64: Optional[str],
    ) -> list[Dict[str, Any]]:
        user_content: Any
        if (
            self._config.vision_enabled
            and vision_image_base64
            and vision_image_base64.strip()
        ):
            user_content = [
                {"type": "input_text", "text": user_prompt},
                {
                    "type": "input_image",
                    "image_url": f"data:image/png;base64,{vision_image_base64.strip()}",
                },
            ]
        else:
            if vision_image_base64 and not self._config.vision_enabled:
                _logger.debug("Vision image supplied but VISION_ENABLED=false; ignoring.")
            user_content = user_prompt

        return [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ]


def _extract_output_text(response: Any) -> str:
    output = getattr(response, "output", None)
    if not output:
        return ""
    chunks: list[str] = []
    for item in output:
        content = getattr(item, "content", None)
        if not content:
            continue
        for part in content:
            text = getattr(part, "text", None)
            if text:
                chunks.append(str(text))
    return "".join(chunks)
