from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Optional

from ai_assistant.models import ClientIdentityModel


@dataclass(frozen=True)
class ResolvedClientIdentity:
    """Kota, telemetri ve rate limit için çözümlenmiş istemci kimliği."""

    client_key: str
    is_premium: bool
    safe_id: str
    identity_source: str  # user_id | device_id | ip


def resolve_client_identity(
    client_identity: Optional[ClientIdentityModel],
    client_ip: str,
) -> ResolvedClientIdentity:
    """
    Öncelik: user_id > device_id > IP fallback.
    Production'da Redis tabanlı kota/cache için aynı client_key kullanılır.
    """
    ip = (client_ip or "unknown").strip() or "unknown"

    if client_identity is not None:
        user_id = (client_identity.user_id or "").strip()
        if user_id:
            key = f"user:{user_id}"
            return ResolvedClientIdentity(
                client_key=key,
                is_premium=bool(client_identity.is_premium),
                safe_id=_safe_id(key),
                identity_source="user_id",
            )
        device_id = (client_identity.device_id or "").strip()
        if device_id:
            key = f"device:{device_id}"
            return ResolvedClientIdentity(
                client_key=key,
                is_premium=bool(client_identity.is_premium),
                safe_id=_safe_id(key),
                identity_source="device_id",
            )

    key = f"ip:{ip}"
    is_premium = bool(client_identity.is_premium) if client_identity else False
    return ResolvedClientIdentity(
        client_key=key,
        is_premium=is_premium,
        safe_id=_safe_id(key),
        identity_source="ip",
    )


def _safe_id(client_key: str) -> str:
    """Ham kimlik yerine log/telemetri için kısa hash."""
    return hashlib.sha256(client_key.encode("utf-8")).hexdigest()[:16]
