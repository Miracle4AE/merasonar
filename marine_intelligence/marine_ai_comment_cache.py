from __future__ import annotations

import hashlib
import json
import threading
import time
from dataclasses import dataclass
from typing import Optional, Protocol, runtime_checkable

from marine_intelligence.models import MarineAiCommentModel, MarineCoordinateResponseModel


@runtime_checkable
class MarineAiCommentCacheProtocol(Protocol):
    def get(self, key: str) -> Optional[MarineAiCommentModel]:
        ...

    def set(self, key: str, comment: MarineAiCommentModel) -> None:
        ...


@dataclass
class _CacheEntry:
    expires_at: float
    comment: MarineAiCommentModel


class MarineAiCommentCache:
    """Marine AI yorum önbelleği — AI Assistant cache'den ayrı tutulur."""

    def __init__(self, *, ttl_seconds: int, max_entries: int = 128) -> None:
        if ttl_seconds < 1:
            raise ValueError("ttl_seconds must be >= 1.")
        if max_entries < 1:
            raise ValueError("max_entries must be >= 1.")
        self._ttl_seconds = int(ttl_seconds)
        self._max_entries = int(max_entries)
        self._store: dict[str, _CacheEntry] = {}
        self._lock = threading.RLock()

    def get(self, key: str) -> Optional[MarineAiCommentModel]:
        now = time.time()
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            if entry.expires_at <= now:
                del self._store[key]
                return None
            return entry.comment.model_copy(update={"cache_hit": True})

    def set(self, key: str, comment: MarineAiCommentModel) -> None:
        if comment.source == "fallback":
            return
        expires_at = time.time() + float(self._ttl_seconds)
        with self._lock:
            if len(self._store) >= self._max_entries:
                self._evict_oldest()
            self._store[key] = _CacheEntry(
                expires_at=expires_at,
                comment=comment.model_copy(update={"cache_hit": False}),
            )

    def _evict_oldest(self) -> None:
        if not self._store:
            return
        oldest_key = min(self._store.items(), key=lambda kv: kv[1].expires_at)[0]
        del self._store[oldest_key]


def _decision_fingerprint(report: MarineCoordinateResponseModel) -> str:
    decision = report.decision
    if decision is None:
        return "none"
    payload = {
        "go_score": decision.go_score,
        "wait_score": decision.wait_score,
        "fishing_decision": decision.fishing_decision,
        "reason_codes": sorted(decision.decision_reason_codes or []),
    }
    return json.dumps(payload, sort_keys=True, ensure_ascii=False)


def _scenario_fingerprint(report: MarineCoordinateResponseModel) -> str:
    scenario = report.scenario
    if scenario is None:
        return "none"
    items = [
        {
            "scenario_id": item.scenario_id,
            "delta_go_score": item.delta_go_score,
            "delta_risk_score": item.delta_risk_score,
        }
        for item in scenario.items[:5]
    ]
    payload = {"base_go_score": scenario.base_go_score, "items": items}
    return json.dumps(payload, sort_keys=True, ensure_ascii=False)


def _timeline_fingerprint(report: MarineCoordinateResponseModel) -> str:
    timeline = report.decision_timeline or []
    items = [
        {
            "time": item.time,
            "go_score": item.go_score,
            "is_best_slot": item.is_best_slot,
        }
        for item in timeline[:6]
    ]
    return json.dumps(items, sort_keys=True, ensure_ascii=False)


def build_marine_ai_comment_cache_key(
    report: MarineCoordinateResponseModel,
    *,
    persona_version: str,
    user_question: Optional[str] = None,
    catch_context: Optional[dict] = None,
) -> str:
    normalized_question = (user_question or "").strip().lower()
    catch_fp = "none"
    if catch_context:
        catch_fp = json.dumps(
            {
                "catch_count": catch_context.get("catch_count"),
                "top_species": catch_context.get("top_species"),
                "spot_reputation": catch_context.get("spot_reputation"),
                "recent_count": len(catch_context.get("recent_catches") or []),
            },
            sort_keys=True,
            ensure_ascii=False,
        )
    payload = {
        "scope": "marine_coordinate",
        "lat": round(float(report.coordinate.lat), 4),
        "lon": round(float(report.coordinate.lon), 4),
        "decision_fp": _decision_fingerprint(report),
        "scenario_fp": _scenario_fingerprint(report),
        "timeline_fp": _timeline_fingerprint(report),
        "persona_version": persona_version,
        "user_question": normalized_question or None,
        "catch_fp": catch_fp,
    }
    raw = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()
