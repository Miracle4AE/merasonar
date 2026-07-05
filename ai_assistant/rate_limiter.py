from __future__ import annotations

import time
from collections import defaultdict, deque
from dataclasses import dataclass
from threading import Lock
from typing import Deque, Dict, Protocol, runtime_checkable

from ai_assistant.config import AiAssistantConfig


@dataclass(frozen=True)
class RateLimitResult:
    allowed: bool
    remaining: int


@runtime_checkable
class AiRateLimiterProtocol(Protocol):
    """
    Dakikalık rate limit arayüzü.
    Production'da Redis tabanlı implementasyon önerilir.
    """

    def check(self, client_ip: str, *, enabled: bool) -> RateLimitResult: ...

    def reset(self) -> None: ...


class InMemoryAiRateLimiter:
    """Basit IP bazlı dakikalık rate limit — Faz 4 in-memory altyapı."""

    def __init__(self, *, limit_per_minute: int) -> None:
        self._limit = max(1, int(limit_per_minute))
        self._events: Dict[str, Deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def check(self, client_ip: str, *, enabled: bool) -> RateLimitResult:
        if not enabled:
            return RateLimitResult(allowed=True, remaining=self._limit)

        key = (client_ip or "unknown").strip() or "unknown"
        now = time.monotonic()
        window_start = now - 60.0

        with self._lock:
            bucket = self._events[key]
            while bucket and bucket[0] < window_start:
                bucket.popleft()
            if len(bucket) >= self._limit:
                return RateLimitResult(allowed=False, remaining=0)
            bucket.append(now)
            remaining = max(0, self._limit - len(bucket))
            return RateLimitResult(allowed=True, remaining=remaining)

    def reset(self) -> None:
        with self._lock:
            self._events.clear()


def check_ai_rate_limit(
    config: AiAssistantConfig,
    limiter: AiRateLimiterProtocol,
    client_ip: str,
) -> RateLimitResult:
    return limiter.check(client_ip, enabled=config.ai_rate_limit_enabled)
