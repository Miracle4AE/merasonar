from __future__ import annotations

import os
from dataclasses import dataclass
from typing import List, Optional


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    return int(raw)


def _env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    return float(raw)


def _env_str(name: str, default: str) -> str:
    raw = os.getenv(name)
    if raw is None or not raw.strip():
        return default
    return raw.strip()


@dataclass(frozen=True)
class MarineIntelligenceConfig:
    marine_intelligence_enabled: bool
    cache_ttl_minutes: int
    open_meteo_enabled: bool
    astronomy_local_enabled: bool
    mgm_enabled: bool
    windy_enabled: bool
    windy_app_enabled: bool
    poseidon_enabled: bool
    request_timeout_seconds: float
    saved_spots_enabled: bool
    spot_storage_backend: str
    marine_ai_comment_cache_ttl_minutes: int
    marine_catch_storage_enabled: bool
    bulk_learning_summary_enabled: bool
    marine_compare_enabled: bool
    tide_provider_enabled: bool
    tide_provider_name: str
    tide_api_key: str
    tide_api_base_url: str
    tide_cache_ttl_minutes: int

    @classmethod
    def from_env(cls) -> MarineIntelligenceConfig:
        return cls(
            marine_intelligence_enabled=_env_bool("MARINE_INTELLIGENCE_ENABLED", default=True),
            cache_ttl_minutes=_env_int("MARINE_INTELLIGENCE_CACHE_TTL_MINUTES", default=30),
            open_meteo_enabled=_env_bool("OPEN_METEO_ENABLED", default=True),
            astronomy_local_enabled=_env_bool("ASTRONOMY_LOCAL_ENABLED", default=True),
            mgm_enabled=_env_bool("MGM_ENABLED", default=False),
            windy_enabled=_env_bool("WINDY_ENABLED", default=False),
            windy_app_enabled=_env_bool("WINDY_APP_ENABLED", default=False),
            poseidon_enabled=_env_bool("POSEIDON_ENABLED", default=False),
            request_timeout_seconds=_env_float("MARINE_INTELLIGENCE_TIMEOUT_SECONDS", default=10.0),
            saved_spots_enabled=_env_bool("MARINE_SAVED_SPOTS_ENABLED", default=True),
            spot_storage_backend=_env_str("MARINE_SPOT_STORAGE_BACKEND", default="sqlite"),
            marine_ai_comment_cache_ttl_minutes=_env_int(
                "MARINE_AI_COMMENT_CACHE_TTL_MINUTES", default=15
            ),
            marine_catch_storage_enabled=_env_bool("MARINE_CATCH_STORAGE_ENABLED", default=True),
            bulk_learning_summary_enabled=_env_bool("MARINE_BULK_LEARNING_SUMMARY_ENABLED", default=True),
            marine_compare_enabled=_env_bool("MARINE_COMPARE_ENABLED", default=True),
            tide_provider_enabled=_env_bool("TIDE_PROVIDER_ENABLED", default=False),
            tide_provider_name=_env_str("TIDE_PROVIDER_NAME", default="world_tides"),
            tide_api_key=_env_str("TIDE_API_KEY", default=""),
            tide_api_base_url=_env_str(
                "TIDE_API_BASE_URL",
                default="https://www.worldtides.info/api/v3",
            ),
            tide_cache_ttl_minutes=_env_int("TIDE_CACHE_TTL_MINUTES", default=60),
        )

    def enabled_provider_names(self) -> List[str]:
        names: List[str] = []
        if self.open_meteo_enabled:
            names.append("open_meteo")
        if self.astronomy_local_enabled:
            names.append("astronomy_local")
        if self.mgm_enabled:
            names.append("mgm")
        if self.windy_enabled:
            names.append("windy")
        if self.windy_app_enabled:
            names.append("windy_app")
        if self.poseidon_enabled:
            names.append("poseidon")
        return names

    def health_payload(self) -> dict[str, bool | int | list[str] | str]:
        payload: dict[str, bool | int | list[str] | str] = {
            "enabled": self.marine_intelligence_enabled,
            "cache_ttl_minutes": self.cache_ttl_minutes,
            "providers_enabled": self.enabled_provider_names(),
            "saved_spots_enabled": self.saved_spots_enabled,
            "marine_ai_comment_cache_ttl_minutes": self.marine_ai_comment_cache_ttl_minutes,
            "catch_intelligence_enabled": self.marine_catch_storage_enabled,
            "bulk_learning_summary_enabled": self.bulk_learning_summary_enabled,
            "marine_compare_enabled": self.marine_compare_enabled,
            "tide_provider_enabled": self.tide_provider_enabled,
            "tide_provider_name": self.tide_provider_name,
        }
        if self.saved_spots_enabled:
            payload["saved_spots_storage"] = self.spot_storage_backend
        return payload
