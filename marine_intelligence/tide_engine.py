"""Gelgit motoru — yapılandırılmış sağlayıcı üzerinden gerçek veri."""

from __future__ import annotations

from typing import Optional

from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.tide_provider import TideProviderResult, WorldTidesTideProvider


def compute_tide(
    lat: float,
    lon: float,
    *,
    config: MarineIntelligenceConfig,
) -> Optional[TideProviderResult]:
    if not config.tide_provider_enabled:
        return None
    provider = WorldTidesTideProvider(
        enabled=True,
        api_key=config.tide_api_key,
        base_url=config.tide_api_base_url,
        timeout_seconds=config.request_timeout_seconds,
    )
    result = provider.fetch(lat, lon)
    if not result.provider_available:
        return result
    return result
