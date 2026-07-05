from __future__ import annotations

import threading
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Protocol, runtime_checkable

from ai_assistant.config import AiAssistantConfig


@dataclass(frozen=True)
class QuotaResult:
    allowed: bool
    remaining: int
    daily_limit: int
    is_premium: bool
    consumed: bool = False


@runtime_checkable
class AiQuotaStoreProtocol(Protocol):
    """
    Günlük AI kota deposu.
    Production'da Redis implementasyonu önerilir (TTL = gün sonu).
    """

    def check_and_consume(
        self,
        client_key: str,
        *,
        daily_limit: int,
        enabled: bool,
    ) -> QuotaResult: ...

    def peek(
        self,
        client_key: str,
        *,
        daily_limit: int,
        enabled: bool,
    ) -> QuotaResult: ...

    def reset(self) -> None: ...


class InMemoryAiQuotaStore:
    """Günlük kota — bellek içi; tek process / geliştirme için."""

    def __init__(self) -> None:
        self._counts: dict[str, int] = {}
        self._lock = threading.Lock()

    def check_and_consume(
        self,
        client_key: str,
        *,
        daily_limit: int,
        enabled: bool,
    ) -> QuotaResult:
        if not enabled:
            return QuotaResult(
                allowed=True,
                remaining=daily_limit,
                daily_limit=daily_limit,
                is_premium=False,
                consumed=False,
            )

        key = _daily_key(client_key)
        limit = max(1, int(daily_limit))

        with self._lock:
            used = self._counts.get(key, 0)
            if used >= limit:
                return QuotaResult(
                    allowed=False,
                    remaining=0,
                    daily_limit=limit,
                    is_premium=False,
                    consumed=False,
                )
            self._counts[key] = used + 1
            remaining = max(0, limit - self._counts[key])
            return QuotaResult(
                allowed=True,
                remaining=remaining,
                daily_limit=limit,
                is_premium=False,
                consumed=True,
            )

    def peek(
        self,
        client_key: str,
        *,
        daily_limit: int,
        enabled: bool,
    ) -> QuotaResult:
        if not enabled:
            return QuotaResult(
                allowed=True,
                remaining=daily_limit,
                daily_limit=daily_limit,
                is_premium=False,
                consumed=False,
            )

        key = _daily_key(client_key)
        limit = max(1, int(daily_limit))
        with self._lock:
            used = self._counts.get(key, 0)
            remaining = max(0, limit - used)
            return QuotaResult(
                allowed=used < limit,
                remaining=remaining,
                daily_limit=limit,
                is_premium=False,
                consumed=False,
            )

    def reset(self) -> None:
        with self._lock:
            self._counts.clear()


def daily_limit_for_client(config: AiAssistantConfig, *, is_premium: bool) -> int:
    if is_premium:
        return max(1, config.ai_premium_daily_limit)
    return max(1, config.ai_free_daily_limit)


def check_ai_quota(
    config: AiAssistantConfig,
    store: AiQuotaStoreProtocol,
    client_key: str,
    *,
    is_premium: bool,
) -> QuotaResult:
    limit = daily_limit_for_client(config, is_premium=is_premium)
    result = store.check_and_consume(
        client_key,
        daily_limit=limit,
        enabled=config.ai_quota_enabled,
    )
    return QuotaResult(
        allowed=result.allowed,
        remaining=result.remaining,
        daily_limit=limit,
        is_premium=is_premium,
        consumed=result.consumed,
    )


def peek_ai_quota(
    config: AiAssistantConfig,
    store: AiQuotaStoreProtocol,
    client_key: str,
    *,
    is_premium: bool,
) -> QuotaResult:
    limit = daily_limit_for_client(config, is_premium=is_premium)
    result = store.peek(
        client_key,
        daily_limit=limit,
        enabled=config.ai_quota_enabled,
    )
    return QuotaResult(
        allowed=result.allowed,
        remaining=result.remaining,
        daily_limit=limit,
        is_premium=is_premium,
        consumed=False,
    )


def _daily_key(client_key: str) -> str:
    day = datetime.now(timezone.utc).date().isoformat()
    return f"{client_key}:{day}"
