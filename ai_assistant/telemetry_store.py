from __future__ import annotations

import json
import threading
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Protocol, runtime_checkable


@dataclass(frozen=True)
class AiPersistentTelemetryEntry:
    timestamp: str
    request_id: Optional[str]
    client_identity_safe_id: str
    scope: str
    source: str
    model: Optional[str]
    prompt_version: str
    latency_ms: float
    cache_hit: bool
    fallback_reason: Optional[str]
    token_usage: Dict[str, int]
    estimated_cost: float
    remaining_ai_requests: Optional[int]
    is_premium: Optional[bool]
    assistant_name: Optional[str] = None
    persona_version: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@runtime_checkable
class AiTelemetryStoreProtocol(Protocol):
    """
    Kalıcı / toplu telemetri deposu.
    Production'da Redis veya object storage + stream önerilir.
    """

    def append(self, entry: AiPersistentTelemetryEntry) -> None: ...

    def summarize(
        self,
        *,
        client_key: Optional[str] = None,
        client_safe_id: Optional[str] = None,
    ) -> dict[str, Any]: ...

    def reset(self) -> None: ...


class InMemoryAiTelemetryStore:
    """Process içi telemetri — usage summary ve testler için."""

    def __init__(self, *, max_entries: int = 10_000) -> None:
        self._max_entries = max(100, int(max_entries))
        self._entries: List[AiPersistentTelemetryEntry] = []
        self._lock = threading.Lock()

    def append(self, entry: AiPersistentTelemetryEntry) -> None:
        with self._lock:
            self._entries.append(entry)
            if len(self._entries) > self._max_entries:
                self._entries = self._entries[-self._max_entries :]

    def summarize(
        self,
        *,
        client_key: Optional[str] = None,
        client_safe_id: Optional[str] = None,
    ) -> dict[str, Any]:
        with self._lock:
            entries = list(self._entries)
        return _aggregate_entries(
            entries,
            client_safe_id=client_safe_id,
        )

    def reset(self) -> None:
        with self._lock:
            self._entries.clear()

    @property
    def entries(self) -> List[AiPersistentTelemetryEntry]:
        with self._lock:
            return list(self._entries)


class JsonlAiTelemetryStore:
    """JSONL dosyaya append — AI_TELEMETRY_PERSIST_ENABLED=true iken kullanılır."""

    def __init__(self, path: Path) -> None:
        self._path = path
        self._lock = threading.Lock()
        self._path.parent.mkdir(parents=True, exist_ok=True)

    def append(self, entry: AiPersistentTelemetryEntry) -> None:
        line = json.dumps(entry.to_dict(), ensure_ascii=False, separators=(",", ":"))
        with self._lock:
            with self._path.open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")

    def summarize(
        self,
        *,
        client_key: Optional[str] = None,
        client_safe_id: Optional[str] = None,
    ) -> dict[str, Any]:
        entries = self._read_all()
        return _aggregate_entries(entries, client_safe_id=client_safe_id)

    def reset(self) -> None:
        with self._lock:
            if self._path.exists():
                self._path.unlink()

    def _read_all(self) -> List[AiPersistentTelemetryEntry]:
        if not self._path.exists():
            return []
        out: List[AiPersistentTelemetryEntry] = []
        with self._lock:
            for line in self._path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    raw = json.loads(line)
                    out.append(
                        AiPersistentTelemetryEntry(
                            timestamp=str(raw.get("timestamp", "")),
                            request_id=raw.get("request_id"),
                            client_identity_safe_id=str(
                                raw.get("client_identity_safe_id", "")
                            ),
                            scope=str(raw.get("scope", "")),
                            source=str(raw.get("source", "")),
                            model=raw.get("model"),
                            prompt_version=str(raw.get("prompt_version", "")),
                            latency_ms=float(raw.get("latency_ms", 0.0)),
                            cache_hit=bool(raw.get("cache_hit", False)),
                            fallback_reason=raw.get("fallback_reason"),
                            token_usage=dict(raw.get("token_usage") or {}),
                            estimated_cost=float(raw.get("estimated_cost", 0.0)),
                            remaining_ai_requests=raw.get("remaining_ai_requests"),
                            is_premium=raw.get("is_premium"),
                        )
                    )
                except (json.JSONDecodeError, TypeError, ValueError):
                    continue
        return out


class CompositeAiTelemetryStore:
    """Bellek + isteğe bağlı JSONL — usage summary bellekten, kalıcılık dosyadan."""

    def __init__(
        self,
        memory: InMemoryAiTelemetryStore,
        *,
        jsonl: Optional[JsonlAiTelemetryStore] = None,
    ) -> None:
        self._memory = memory
        self._jsonl = jsonl

    def append(self, entry: AiPersistentTelemetryEntry) -> None:
        self._memory.append(entry)
        if self._jsonl is not None:
            self._jsonl.append(entry)

    def summarize(
        self,
        *,
        client_key: Optional[str] = None,
        client_safe_id: Optional[str] = None,
    ) -> dict[str, Any]:
        if self._jsonl is not None:
            return self._jsonl.summarize(client_safe_id=client_safe_id)
        return self._memory.summarize(client_safe_id=client_safe_id)

    def reset(self) -> None:
        self._memory.reset()
        if self._jsonl is not None:
            self._jsonl.reset()


def build_persistent_entry(
    *,
    request_id: Optional[str],
    client_safe_id: str,
    scope: str,
    source: str,
    model: Optional[str],
    prompt_version: str,
    latency_ms: float,
    cache_hit: bool,
    fallback_reason: Optional[str],
    token_usage: Dict[str, int],
    estimated_cost: float,
    remaining_ai_requests: Optional[int],
    is_premium: Optional[bool],
    assistant_name: Optional[str] = None,
    persona_version: Optional[str] = None,
) -> AiPersistentTelemetryEntry:
    return AiPersistentTelemetryEntry(
        timestamp=datetime.now(timezone.utc).isoformat(),
        request_id=request_id,
        client_identity_safe_id=client_safe_id,
        scope=scope,
        source=source,
        model=model,
        prompt_version=prompt_version,
        latency_ms=latency_ms,
        cache_hit=cache_hit,
        fallback_reason=fallback_reason,
        token_usage=dict(token_usage),
        estimated_cost=estimated_cost,
        remaining_ai_requests=remaining_ai_requests,
        is_premium=is_premium,
        assistant_name=assistant_name,
        persona_version=persona_version,
    )


def _aggregate_entries(
    entries: List[AiPersistentTelemetryEntry],
    *,
    client_safe_id: Optional[str],
) -> dict[str, Any]:
    filtered = entries
    if client_safe_id:
        filtered = [e for e in entries if e.client_identity_safe_id == client_safe_id]

    total = len(filtered)
    ai_count = sum(1 for e in filtered if e.source == "ai")
    fallback_count = sum(1 for e in filtered if e.source == "fallback")
    cache_hits = sum(1 for e in filtered if e.cache_hit)
    cache_hit_rate = round(cache_hits / total, 4) if total else 0.0
    estimated_total_cost = round(sum(e.estimated_cost for e in filtered), 6)

    by_scope: Dict[str, int] = {}
    by_model: Dict[str, int] = {}
    for entry in filtered:
        by_scope[entry.scope] = by_scope.get(entry.scope, 0) + 1
        model_key = entry.model or "unknown"
        by_model[model_key] = by_model.get(model_key, 0) + 1

    return {
        "total_requests": total,
        "ai_requests": ai_count,
        "fallback_requests": fallback_count,
        "cache_hit_rate": cache_hit_rate,
        "estimated_total_cost": estimated_total_cost,
        "by_scope": by_scope,
        "by_model": by_model,
    }
