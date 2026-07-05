from __future__ import annotations

import re
from typing import Any

try:
    from openai import (
        APIConnectionError,
        APITimeoutError,
        AuthenticationError,
        BadRequestError,
        PermissionDeniedError,
        RateLimitError,
    )
except ImportError:  # pragma: no cover
    APIConnectionError = APITimeoutError = AuthenticationError = None  # type: ignore
    BadRequestError = PermissionDeniedError = RateLimitError = None  # type: ignore

_KEY_PATTERN = re.compile(r"sk-[A-Za-z0-9_\-]{8,}")


def sanitize_log_message(message: str) -> str:
    """API anahtarı ve Authorization içeriğini loglardan temizler."""
    cleaned = _KEY_PATTERN.sub("sk-***", message or "")
    cleaned = re.sub(
        r"(?i)(authorization\s*[:=]\s*)([^\s,]+)",
        r"\1***",
        cleaned,
    )
    return cleaned


def classify_openai_failure(exc: BaseException) -> str:
    """OpenAI/SDK hatalarını güvenli fallback_reason kodlarına eşler."""
    if AuthenticationError is not None and isinstance(exc, AuthenticationError):
        return "openai_auth_failed"
    if PermissionDeniedError is not None and isinstance(exc, PermissionDeniedError):
        return "openai_permission_denied"
    if RateLimitError is not None and isinstance(exc, RateLimitError):
        status = getattr(exc, "status_code", None)
        if status == 429:
            body = getattr(exc, "body", None)
            code = _extract_error_code(body)
            if code in {"insufficient_quota", "billing_hard_limit_reached"}:
                return "openai_quota_exceeded"
        return "openai_rate_limited"
    if APITimeoutError is not None and isinstance(exc, APITimeoutError):
        return "openai_timeout"
    if APIConnectionError is not None and isinstance(exc, APIConnectionError):
        return "openai_network_error"
    if BadRequestError is not None and isinstance(exc, BadRequestError):
        body = getattr(exc, "body", None)
        code = _extract_error_code(body)
        message = sanitize_log_message(str(exc)).lower()
        if code == "invalid_json_schema" or "invalid schema" in message:
            return "openai_schema_invalid"
        if "model" in message and (
            "not found" in message or "does not exist" in message or "not available" in message
        ):
            return "openai_model_not_available"
        return "openai_bad_request"
    message = sanitize_log_message(str(exc)).lower()
    if "timeout" in message or "timed out" in message:
        return "openai_timeout"
    if "401" in message or "invalid api key" in message or "incorrect api key" in message:
        return "openai_auth_failed"
    if "429" in message or "rate limit" in message:
        return "openai_rate_limited"
    if "quota" in message:
        return "openai_quota_exceeded"
    return "upstream_failure"


def _extract_error_code(body: Any) -> str | None:
    if not isinstance(body, dict):
        return None
    err = body.get("error")
    if isinstance(err, dict):
        code = err.get("code") or err.get("type")
        return str(code) if code else None
    return None


def log_ai_config_startup(config: Any) -> None:
    """Startup'ta sanitize AI yapılandırma özeti — key değeri asla loglanmaz."""
    import logging

    logger = logging.getLogger("merasonar.ai")
    logger.info(
        "AI config: enabled=%s key_present=%s model=%s timeout=%s prompt_version=%s "
        "streaming=%s rate_limit=%s quota=%s runtime_ready=%s",
        getattr(config, "ai_assistant_enabled", False),
        bool(getattr(config, "openai_api_key", None)),
        getattr(config, "openai_model", None) or "(missing)",
        getattr(config, "ai_timeout_seconds", None),
        getattr(config, "prompt_version", None),
        getattr(config, "streaming_enabled", False),
        getattr(config, "ai_rate_limit_enabled", False),
        getattr(config, "ai_quota_enabled", False),
        config.is_operational() if hasattr(config, "is_operational") else False,
    )
    if getattr(config, "ai_assistant_enabled", False) and not getattr(
        config, "openai_api_key", None
    ):
        logger.warning("OpenAI key missing — Captain Atlas fallback aktif olacak.")
    if getattr(config, "ai_assistant_enabled", False) and not getattr(
        config, "openai_model", None
    ):
        logger.warning("OpenAI model missing — Captain Atlas fallback aktif olacak.")
    if getattr(config, "streaming_enabled", False):
        logger.warning(
            "STREAMING_ENABLED=true — Faz 1'de AI fallback kullanılır; false yapın."
        )
