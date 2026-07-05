from __future__ import annotations

import threading
import time
from dataclasses import dataclass
from typing import Optional, Protocol, runtime_checkable

from ai_assistant.models import AiFishingAssistantResponseModel


@dataclass
class _CacheEntry:
    expires_at: float
    response: AiFishingAssistantResponseModel


@runtime_checkable
class AiResponseCacheProtocol(Protocol):
    """
    AI yanıt önbelleği.
    Production'da Redis tabanlı implementasyon önerilir.
    """
    def get(self, fingerprint: str) -> Optional[AiFishingAssistantResponseModel]:
        ...

    def set(self, fingerprint: str, response: AiFishingAssistantResponseModel) -> None:
        ...


class InMemoryAiResponseCache:
    """TTL'li bellek içi LRU-benzeri cache — aynı analiz tekrar OpenAI'ya gitmez."""

    def __init__(self, *, ttl_seconds: int, max_entries: int = 256) -> None:
        if ttl_seconds < 1:
            raise ValueError("ttl_seconds must be >= 1.")
        if max_entries < 1:
            raise ValueError("max_entries must be >= 1.")
        self._ttl_seconds = int(ttl_seconds)
        self._max_entries = int(max_entries)
        self._store: dict[str, _CacheEntry] = {}
        self._lock = threading.RLock()

    def get(self, fingerprint: str) -> Optional[AiFishingAssistantResponseModel]:
        now = time.time()
        with self._lock:
            entry = self._store.get(fingerprint)
            if entry is None:
                return None
            if entry.expires_at <= now:
                del self._store[fingerprint]
                return None
            cached = entry.response.model_copy(update={"cache_hit": True})
            return cached

    def set(self, fingerprint: str, response: AiFishingAssistantResponseModel) -> None:
        expires_at = time.time() + float(self._ttl_seconds)
        with self._lock:
            if len(self._store) >= self._max_entries:
                self._evict_oldest()
            self._store[fingerprint] = _CacheEntry(
                expires_at=expires_at,
                response=response.model_copy(update={"cache_hit": False}),
            )

    def _evict_oldest(self) -> None:
        if not self._store:
            return
        oldest_key = min(self._store.items(), key=lambda kv: kv[1].expires_at)[0]
        del self._store[oldest_key]
