from __future__ import annotations

import threading
import time
from dataclasses import dataclass
from typing import Any, Dict, Generic, Optional, Tuple, TypeVar

T = TypeVar("T")


@dataclass
class _CacheEntry(Generic[T]):
    value: T
    expires_at: float


class MarineIntelligenceCache:
    """In-memory TTL cache — production'da Redis ile değiştirilebilir."""

    def __init__(self, ttl_seconds: int) -> None:
        self._ttl = max(1, ttl_seconds)
        self._store: Dict[str, _CacheEntry[Any]] = {}
        self._lock = threading.Lock()

    @staticmethod
    def build_key(
        lat: float,
        lon: float,
        provider_set: str,
        fingerprint: str = "",
    ) -> str:
        fp = fingerprint or "default"
        return f"{round(lat, 4)}:{round(lon, 4)}:{provider_set}:{fp}"

    def get(self, key: str) -> Tuple[Optional[Any], bool]:
        now = time.monotonic()
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None, False
            if entry.expires_at <= now:
                del self._store[key]
                return None, False
            return entry.value, True

    def set(self, key: str, value: Any) -> None:
        expires = time.monotonic() + self._ttl
        with self._lock:
            self._store[key] = _CacheEntry(value=value, expires_at=expires)

    def clear(self) -> None:
        with self._lock:
            self._store.clear()
