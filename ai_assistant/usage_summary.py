from __future__ import annotations

from typing import Any, Optional

from ai_assistant.config import AiAssistantConfig
from ai_assistant.identity import ResolvedClientIdentity, resolve_client_identity
from ai_assistant.models import ClientIdentityModel
from ai_assistant.quota import peek_ai_quota
from ai_assistant.quota import AiQuotaStoreProtocol
from ai_assistant.telemetry_store import AiTelemetryStoreProtocol


def verify_usage_admin_key(
    config: AiAssistantConfig,
    *,
    provided_key: Optional[str],
) -> bool:
    """
    Admin key tanımlıysa eşleşme zorunlu.
    Tanımlı değilse local/dev modunda erişime izin ver (secret sızdırmadan).
    """
    expected = config.ai_usage_admin_key
    if not expected:
        return True
    if not provided_key:
        return False
    return provided_key.strip() == expected.strip()


def build_usage_summary(
    config: AiAssistantConfig,
    telemetry_store: AiTelemetryStoreProtocol,
    quota_store: AiQuotaStoreProtocol,
    *,
    device_id: Optional[str] = None,
    user_id: Optional[str] = None,
    client_ip: str = "unknown",
) -> dict[str, Any]:
    identity_input: Optional[ClientIdentityModel] = None
    if user_id or device_id:
        identity_input = ClientIdentityModel(
            device_id=device_id,
            user_id=user_id,
        )

    resolved = resolve_client_identity(identity_input, client_ip)
    if user_id or device_id:
        summary = telemetry_store.summarize(client_safe_id=resolved.safe_id)
    else:
        summary = telemetry_store.summarize()

    quota_remaining: Optional[int] = None
    if config.ai_quota_enabled:
        quota = peek_ai_quota(
            config,
            quota_store,
            resolved.client_key,
            is_premium=resolved.is_premium,
        )
        quota_remaining = quota.remaining

    return {
        **summary,
        "quota_remaining": quota_remaining,
        "client_identity_safe_id": resolved.safe_id,
    }
