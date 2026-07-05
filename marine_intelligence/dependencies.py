from __future__ import annotations

import os
from functools import lru_cache
from typing import Optional

from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.catch_service import CatchIntelligenceService
from marine_intelligence.compare_service import MarineCompareService
from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.marine_ai_comment_cache import MarineAiCommentCache
from marine_intelligence.service import MarineIntelligenceService
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol
from marine_intelligence.storage.catch_record_store import (
    CatchRecordStoreProtocol,
    SqliteCatchRecordStore,
)
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore


def _default_spot_storage_path() -> str:
    return os.getenv("MARINE_SPOT_STORAGE_PATH", "run_logs/marine_spots.db")


@lru_cache(maxsize=1)
def get_marine_intelligence_config() -> MarineIntelligenceConfig:
    return MarineIntelligenceConfig.from_env()


_cache_instance: Optional[MarineIntelligenceCache] = None
_ai_comment_cache_instance: Optional[MarineAiCommentCache] = None
_service_instance: Optional[MarineIntelligenceService] = None
_spot_store_instance: Optional[SpotIntelligenceStoreProtocol] = None
_spot_service_instance: Optional[SpotIntelligenceService] = None
_catch_store_instance: Optional[CatchRecordStoreProtocol] = None
_catch_service_instance: Optional[CatchIntelligenceService] = None
_compare_service_instance: Optional[MarineCompareService] = None


def get_marine_intelligence_cache() -> MarineIntelligenceCache:
    global _cache_instance
    if _cache_instance is None:
        cfg = get_marine_intelligence_config()
        _cache_instance = MarineIntelligenceCache(ttl_seconds=cfg.cache_ttl_minutes * 60)
    return _cache_instance


def build_marine_intelligence_service(
    *,
    config: Optional[MarineIntelligenceConfig] = None,
    cache: Optional[MarineIntelligenceCache] = None,
    providers: Optional[list] = None,
    reliability_registry: Optional[object] = None,
) -> MarineIntelligenceService:
    cfg = config or get_marine_intelligence_config()
    kwargs: dict = {
        "config": cfg,
        "cache": cache or get_marine_intelligence_cache(),
        "providers": providers,
    }
    if reliability_registry is not None:
        kwargs["reliability_registry"] = reliability_registry
    return MarineIntelligenceService(**kwargs)


def get_marine_ai_comment_cache() -> MarineAiCommentCache:
    global _ai_comment_cache_instance
    if _ai_comment_cache_instance is None:
        cfg = get_marine_intelligence_config()
        _ai_comment_cache_instance = MarineAiCommentCache(
            ttl_seconds=cfg.marine_ai_comment_cache_ttl_minutes * 60,
        )
    return _ai_comment_cache_instance


def get_marine_intelligence_service() -> MarineIntelligenceService:
    global _service_instance
    if _service_instance is None:
        _service_instance = build_marine_intelligence_service()
    return _service_instance


def build_spot_intelligence_store(
    *,
    db_path: Optional[str] = None,
) -> SpotIntelligenceStoreProtocol:
    return SqliteSpotIntelligenceStore(db_path or _default_spot_storage_path())


def get_spot_intelligence_store() -> SpotIntelligenceStoreProtocol:
    global _spot_store_instance
    if _spot_store_instance is None:
        _spot_store_instance = build_spot_intelligence_store()
    return _spot_store_instance


def build_spot_intelligence_service(
    *,
    store: Optional[SpotIntelligenceStoreProtocol] = None,
    marine_service: Optional[MarineIntelligenceService] = None,
) -> SpotIntelligenceService:
    return SpotIntelligenceService(
        store=store or get_spot_intelligence_store(),
        marine_service=marine_service or get_marine_intelligence_service(),
    )


def get_spot_intelligence_service() -> SpotIntelligenceService:
    global _spot_service_instance
    if _spot_service_instance is None:
        _spot_service_instance = build_spot_intelligence_service()
    return _spot_service_instance


def build_catch_record_store(
    *,
    db_path: Optional[str] = None,
) -> CatchRecordStoreProtocol:
    return SqliteCatchRecordStore(db_path or _default_spot_storage_path())


def get_catch_record_store() -> CatchRecordStoreProtocol:
    global _catch_store_instance
    if _catch_store_instance is None:
        _catch_store_instance = build_catch_record_store()
    return _catch_store_instance


def build_catch_intelligence_service(
    *,
    spot_store: Optional[SpotIntelligenceStoreProtocol] = None,
    catch_store: Optional[CatchRecordStoreProtocol] = None,
) -> CatchIntelligenceService:
    return CatchIntelligenceService(
        spot_store=spot_store or get_spot_intelligence_store(),
        catch_store=catch_store or get_catch_record_store(),
    )


def get_catch_intelligence_service() -> CatchIntelligenceService:
    global _catch_service_instance
    if _catch_service_instance is None:
        _catch_service_instance = build_catch_intelligence_service()
    return _catch_service_instance


def build_marine_compare_service(
    *,
    marine_service: Optional[MarineIntelligenceService] = None,
    spot_store: Optional[SpotIntelligenceStoreProtocol] = None,
) -> MarineCompareService:
    return MarineCompareService(
        marine_service=marine_service or get_marine_intelligence_service(),
        spot_store=spot_store or get_spot_intelligence_store(),
    )


def get_marine_compare_service() -> MarineCompareService:
    global _compare_service_instance
    if _compare_service_instance is None:
        _compare_service_instance = build_marine_compare_service()
    return _compare_service_instance


def reset_marine_intelligence_singletons() -> None:
    """Test helper — singleton'ları sıfırlar."""
    global _cache_instance, _ai_comment_cache_instance, _service_instance
    global _spot_store_instance, _spot_service_instance
    global _catch_store_instance, _catch_service_instance, _compare_service_instance
    _cache_instance = None
    _ai_comment_cache_instance = None
    _service_instance = None
    _spot_store_instance = None
    _spot_service_instance = None
    _catch_store_instance = None
    _catch_service_instance = None
    _compare_service_instance = None
    get_marine_intelligence_config.cache_clear()
