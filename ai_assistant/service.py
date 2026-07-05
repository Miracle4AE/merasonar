from __future__ import annotations

import json
import logging
import time
from typing import Optional

from pydantic import ValidationError

from ai_assistant.cache import AiResponseCacheProtocol
from ai_assistant.config import AiAssistantConfig
from ai_assistant.context_builder import AiAssistantContextBuilder
from ai_assistant.cost_guard import estimate_context_cost_usd
from ai_assistant.fallback import AiAssistantFallbackBuilder
from ai_assistant.captain_atlas import resolve_assistant_for_scope
from ai_assistant.openai_errors import classify_openai_failure, sanitize_log_message
from ai_assistant.identity import ResolvedClientIdentity
from ai_assistant.models import (
    AiAssistantTelemetryModel,
    AiFishingAssistantRequestModel,
    AiFishingAssistantResponseModel,
    AiStructuredPayloadModel,
    TRUST_NOTE_TR,
)
from ai_assistant.openai_client import OpenAIResponsesClientProtocol
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from ai_assistant.telemetry import AiTelemetryLogger, AiTelemetryRecord
from ai_assistant.telemetry_store import (
    AiTelemetryStoreProtocol,
    build_persistent_entry,
)

_logger = logging.getLogger(__name__)

_REPAIR_HINT = (
    "Önceki yanıt geçerli JSON şemasına uymadı. Yalnızca şemaya uygun, eksiksiz JSON "
    "üret; ek metin ekleme."
)


class AiAssistantService:
    """
    AI Assistant uygulama servisi — cache, OpenAI, guardrails ve fallback orkestrasyonu.
    """

    def __init__(
        self,
        config: AiAssistantConfig,
        *,
        context_builder: AiAssistantContextBuilder,
        prompt_builder: AiAssistantPromptBuilder,
        guardrails: AiAssistantGuardrails,
        fallback_builder: AiAssistantFallbackBuilder,
        cache: AiResponseCacheProtocol,
        telemetry: AiTelemetryLogger,
        telemetry_store: AiTelemetryStoreProtocol,
        openai_client: Optional[OpenAIResponsesClientProtocol] = None,
    ) -> None:
        self._config = config
        self._context_builder = context_builder
        self._prompt_builder = prompt_builder
        self._guardrails = guardrails
        self._fallback_builder = fallback_builder
        self._cache = cache
        self._telemetry = telemetry
        self._telemetry_store = telemetry_store
        self._openai_client = openai_client

    def handle(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        client_identity: ResolvedClientIdentity,
        rate_limit_remaining: Optional[int] = None,
        quota_remaining: Optional[int] = None,
    ) -> AiFishingAssistantResponseModel:
        started = time.perf_counter()
        prompt_version = self._prompt_builder.prompt_version

        if request.scope == "hotspot_detail" and request.focus_hotspot_id is None:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="missing_focus_hotspot_id",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        if request.scope == "live_context" and request.live_context is None:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="missing_live_context",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        if request.scope == "marine_coordinate" and request.marine_context is None:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="missing_marine_context",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        if request.scope == "marine_compare" and request.marine_compare_context is None:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="missing_marine_compare_context",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        fingerprint = self._context_builder.build_fingerprint(
            request,
            prompt_version=prompt_version,
        )
        cached = None if request.force_refresh else self._cache.get(fingerprint)
        if cached is not None and cached.source != "fallback":
            processing_ms = int((time.perf_counter() - started) * 1000)
            response = cached.model_copy(update={"processing_ms": processing_ms})
            record = self._build_telemetry_record(
                request=request,
                response=response,
                latency_ms=0.0,
                input_tokens=0,
                output_tokens=0,
                processing_ms=processing_ms,
            )
            return self._finalize_response(
                response,
                request,
                client_identity=client_identity,
                record=record,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        if not self._config.is_operational() or self._openai_client is None:
            reason = "ai_disabled_or_not_configured"
            if not self._config.ai_assistant_enabled:
                reason = "ai_assistant_disabled"
            elif not self._config.openai_api_key:
                reason = "missing_api_key"
            elif not self._config.openai_model:
                reason = "missing_model"
            elif not self._config.is_openai_configured():
                reason = "openai_not_configured"
            _logger.info("AI fallback [%s]: operational check failed", reason)
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason=reason,
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        if self._config.streaming_enabled:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="streaming_not_implemented_in_phase_1",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        context = self._context_builder.build(request)
        cost_estimate = estimate_context_cost_usd(context, self._config)
        if cost_estimate.exceeded:
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason="cost_guard_exceeded",
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
                estimated_cost_usd=cost_estimate.estimated_cost_usd,
            )

        vision_b64 = request.chart_image_base64 if self._config.vision_enabled else None

        try:
            response = self._invoke_openai_with_retry(
                request=request,
                client_identity=client_identity,
                context=context,
                vision_b64=vision_b64,
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )
            if response.source != "fallback":
                self._cache.set(fingerprint, response)
            return response
        except Exception as exc:
            reason = classify_openai_failure(exc)
            _logger.warning(
                "AI assistant upstream failure [%s]: %s",
                reason,
                sanitize_log_message(str(exc)),
            )
            return self._finalize_fallback(
                request,
                client_identity=client_identity,
                reason=reason,
                started=started,
                prompt_version=prompt_version,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

    def _invoke_openai_with_retry(
        self,
        *,
        request: AiFishingAssistantRequestModel,
        client_identity: ResolvedClientIdentity,
        context: dict,
        vision_b64: Optional[str],
        started: float,
        prompt_version: str,
        rate_limit_remaining: Optional[int],
        quota_remaining: Optional[int],
    ) -> AiFishingAssistantResponseModel:
        assert self._openai_client is not None
        last_error: Optional[str] = None

        for attempt in range(2):
            repair_hint = _REPAIR_HINT if attempt == 1 else None
            bundle = self._prompt_builder.build(context, repair_hint=repair_hint)
            generation = self._openai_client.generate_structured(
                system_prompt=bundle.system_prompt,
                user_prompt=bundle.user_prompt,
                vision_image_base64=vision_b64,
            )
            try:
                payload = AiStructuredPayloadModel.model_validate_json(generation.output_text)
            except (ValidationError, json.JSONDecodeError) as exc:
                last_error = f"schema_parse_failed:{exc}"
                _logger.warning(
                    "AI structured parse failed (attempt %s): %s",
                    attempt + 1,
                    exc,
                )
                continue

            violation = self._guardrails.validate_payload(payload)
            if violation:
                payload = self._guardrails.sanitize_payload(payload)
                violation_after = self._guardrails.validate_payload(payload)
                if violation_after:
                    last_error = f"guardrail_violation:{violation_after}"
                    continue

            processing_ms = int((time.perf_counter() - started) * 1000)
            response = AiFishingAssistantResponseModel(
                source="ai",
                model=generation.model,
                cache_hit=False,
                locale="tr",
                trust_note_tr=TRUST_NOTE_TR,
                prompt_version=prompt_version,
                summary_tr=payload.summary_tr,
                confidence=payload.confidence,
                recommended_actions=payload.recommended_actions,
                hotspot_insights=payload.hotspot_insights,
                conditions_comment_tr=payload.conditions_comment_tr,
                species_comment_tr=payload.species_comment_tr,
                limitations_tr=payload.limitations_tr,
                safety_reminders_tr=payload.safety_reminders_tr,
                fallback_reason=None,
                processing_ms=processing_ms,
            )
            record = self._build_telemetry_record(
                request=request,
                response=response,
                latency_ms=generation.latency_ms,
                input_tokens=generation.input_tokens,
                output_tokens=generation.output_tokens,
                processing_ms=processing_ms,
            )
            return self._finalize_response(
                response,
                request,
                client_identity=client_identity,
                record=record,
                rate_limit_remaining=rate_limit_remaining,
                quota_remaining=quota_remaining,
            )

        raise RuntimeError(last_error or "structured_output_failed")

    def _finalize_fallback(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        client_identity: ResolvedClientIdentity,
        reason: str,
        started: float,
        prompt_version: str,
        rate_limit_remaining: Optional[int] = None,
        quota_remaining: Optional[int] = None,
        estimated_cost_usd: Optional[float] = None,
    ) -> AiFishingAssistantResponseModel:
        processing_ms = int((time.perf_counter() - started) * 1000)
        response = self._fallback_builder.build(
            request,
            prompt_version=prompt_version,
            reason=reason,
            processing_ms=processing_ms,
        )
        record = self._build_telemetry_record(
            request=request,
            response=response,
            latency_ms=0.0,
            input_tokens=0,
            output_tokens=0,
            processing_ms=processing_ms,
            estimated_cost_override=estimated_cost_usd,
        )
        return self._finalize_response(
            response,
            request,
            client_identity=client_identity,
            record=record,
            rate_limit_remaining=rate_limit_remaining,
            quota_remaining=quota_remaining,
        )

    def _finalize_response(
        self,
        response: AiFishingAssistantResponseModel,
        request: AiFishingAssistantRequestModel,
        *,
        client_identity: ResolvedClientIdentity,
        record: AiTelemetryRecord,
        rate_limit_remaining: Optional[int],
        quota_remaining: Optional[int],
    ) -> AiFishingAssistantResponseModel:
        self._telemetry.log(record)
        enriched = self._enrich_response(
            response,
            request,
            client_identity=client_identity,
            record=record,
            rate_limit_remaining=rate_limit_remaining,
            quota_remaining=quota_remaining,
        )
        self._persist_telemetry(
            request=request,
            client_identity=client_identity,
            record=record,
            quota_remaining=quota_remaining,
            is_premium=client_identity.is_premium,
        )
        return enriched

    def _persist_telemetry(
        self,
        *,
        request: AiFishingAssistantRequestModel,
        client_identity: ResolvedClientIdentity,
        record: AiTelemetryRecord,
        quota_remaining: Optional[int],
        is_premium: bool,
    ) -> None:
        entry = build_persistent_entry(
            request_id=request.client_request_id,
            client_safe_id=client_identity.safe_id,
            scope=record.scope,
            source=record.source,
            model=record.model,
            prompt_version=record.prompt_version,
            latency_ms=record.latency_ms,
            cache_hit=record.cache_hit,
            fallback_reason=record.fallback_reason,
            token_usage=dict(record.token_usage),
            estimated_cost=record.estimated_cost_usd,
            remaining_ai_requests=quota_remaining,
            is_premium=is_premium if self._config.ai_quota_enabled else None,
            assistant_name=record.assistant_name,
            persona_version=record.persona_version,
        )
        self._telemetry_store.append(entry)

    def _build_telemetry_record(
        self,
        *,
        request: AiFishingAssistantRequestModel,
        response: AiFishingAssistantResponseModel,
        latency_ms: float,
        input_tokens: int,
        output_tokens: int,
        processing_ms: int,
        estimated_cost_override: Optional[float] = None,
    ) -> AiTelemetryRecord:
        record = self._telemetry.build_record(
            model=response.model,
            latency_ms=latency_ms,
            cache_hit=response.cache_hit,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            processing_time_ms=processing_ms,
            prompt_version=response.prompt_version,
            source=response.source,
            scope=request.scope,
            fallback_reason=response.fallback_reason,
            client_request_id=request.client_request_id,
        )
        if estimated_cost_override is not None:
            return AiTelemetryRecord(
                event=record.event,
                model=record.model,
                latency_ms=record.latency_ms,
                cache_hit=record.cache_hit,
                input_tokens=record.input_tokens,
                output_tokens=record.output_tokens,
                total_tokens=record.total_tokens,
                estimated_cost_usd=estimated_cost_override,
                processing_time_ms=record.processing_time_ms,
                prompt_version=record.prompt_version,
                source=record.source,
                scope=record.scope,
                fallback_reason=record.fallback_reason,
                client_request_id=record.client_request_id,
                token_usage=record.token_usage,
                assistant_name=record.assistant_name,
                persona_version=record.persona_version,
            )
        return record

    def _enrich_response(
        self,
        response: AiFishingAssistantResponseModel,
        request: AiFishingAssistantRequestModel,
        *,
        client_identity: ResolvedClientIdentity,
        record: AiTelemetryRecord,
        rate_limit_remaining: Optional[int],
        quota_remaining: Optional[int],
    ) -> AiFishingAssistantResponseModel:
        telemetry = AiAssistantTelemetryModel(
            event=record.event,
            scope=record.scope,
            source=record.source,
            model=record.model,
            prompt_version=record.prompt_version,
            assistant_name=record.assistant_name,
            persona_version=record.persona_version,
            latency_ms=record.latency_ms,
            cache_hit=record.cache_hit,
            fallback_reason=record.fallback_reason,
            token_usage=dict(record.token_usage),
            estimated_cost=record.estimated_cost_usd if record.estimated_cost_usd > 0 else None,
        )
        remaining = _resolve_remaining(
            config=self._config,
            rate_limit_remaining=rate_limit_remaining,
            quota_remaining=quota_remaining,
        )
        is_premium_feature: Optional[bool] = None
        if self._config.ai_quota_enabled:
            is_premium_feature = client_identity.is_premium
        assistant_name, persona_version, tone = resolve_assistant_for_scope(request.scope)
        return response.model_copy(
            update={
                "mode": request.scope,
                "focus_hotspot_id": request.focus_hotspot_id,
                "telemetry": telemetry,
                "remaining_ai_requests": remaining,
                "is_premium_feature": is_premium_feature,
                "assistant_name": assistant_name,
                "persona_version": persona_version,
                "tone": tone,
            }
        )


def _resolve_remaining(
    *,
    config: AiAssistantConfig,
    rate_limit_remaining: Optional[int],
    quota_remaining: Optional[int],
) -> Optional[int]:
    if config.ai_quota_enabled and quota_remaining is not None:
        return quota_remaining
    if config.ai_rate_limit_enabled and rate_limit_remaining is not None:
        return rate_limit_remaining
    return None
