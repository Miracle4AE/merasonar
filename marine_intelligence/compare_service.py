from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from marine_intelligence.compare_engine import compute_comparison
from marine_intelligence.marine_compare_comment import generate_marine_compare_comment
from marine_intelligence.models import (
    MarineCompareRequestModel,
    MarineCompareResponseModel,
    MarineCompareSideInputModel,
    MarineCoordinateResponseModel,
)
from marine_intelligence.service import MarineIntelligenceService
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol

_logger = logging.getLogger(__name__)

MAX_COMPARE_LABEL_LEN = 80


class MarineCompareService:
    def __init__(
        self,
        marine_service: MarineIntelligenceService,
        spot_store: SpotIntelligenceStoreProtocol,
    ) -> None:
        self._marine_service = marine_service
        self._spot_store = spot_store

    def compare(
        self,
        body: MarineCompareRequestModel,
        *,
        client_ip: str = "unknown",
    ) -> Optional[MarineCompareResponseModel]:
        left_resolved = self._resolve_side(body.left)
        if left_resolved is None:
            return None
        right_resolved = self._resolve_side(body.right)
        if right_resolved is None:
            return None

        left_lat, left_lon, left_label, left_spot_id = left_resolved
        right_lat, right_lon, right_label, right_spot_id = right_resolved

        left_report = self._marine_service.get_coordinate_intelligence(
            left_lat,
            left_lon,
            force_refresh=body.force_refresh,
            include_ai_comment=False,
            client_ip=client_ip,
            spot_id=left_spot_id,
        )
        right_report = self._marine_service.get_coordinate_intelligence(
            right_lat,
            right_lon,
            force_refresh=body.force_refresh,
            include_ai_comment=False,
            client_ip=client_ip,
            spot_id=right_spot_id,
        )

        comparison = compute_comparison(
            left_report,
            right_report,
            left_label=left_label,
            right_label=right_label,
        )

        captain_comment = None
        if body.include_ai_comment:
            left_catch = _optional_catch_context(left_spot_id)
            right_catch = _optional_catch_context(right_spot_id)
            captain_comment = generate_marine_compare_comment(
                left_report=left_report,
                right_report=right_report,
                comparison=comparison,
                left_label=left_label,
                right_label=right_label,
                left_catch_context=left_catch,
                right_catch_context=right_catch,
                client_ip=client_ip,
            )

        updated_at = datetime.now(timezone.utc).isoformat()
        return MarineCompareResponseModel(
            left_report=left_report,
            right_report=right_report,
            comparison=comparison,
            captain_comment=captain_comment,
            updated_at=updated_at,
        )

    def _resolve_side(
        self,
        side: MarineCompareSideInputModel,
    ) -> Optional[Tuple[float, float, str, Optional[str]]]:
        if side.spot_id:
            spot = self._spot_store.get_spot(side.spot_id)
            if spot is None:
                return None
            label = (side.label or spot.name).strip()[:MAX_COMPARE_LABEL_LEN]
            return spot.lat, spot.lon, label or spot.name, spot.id

        if side.lat is None or side.lon is None:
            return None
        label = (side.label or f"{side.lat:.4f}, {side.lon:.4f}").strip()
        return float(side.lat), float(side.lon), label[:MAX_COMPARE_LABEL_LEN], None


def _optional_catch_context(spot_id: Optional[str]) -> Optional[Dict[str, Any]]:
    if not spot_id:
        return None
    try:
        from marine_intelligence.catch_context import build_catch_context_for_spot
        from marine_intelligence.dependencies import (
            get_catch_record_store,
            get_marine_intelligence_config,
            get_spot_intelligence_store,
        )

        if not get_marine_intelligence_config().marine_catch_storage_enabled:
            return None
        ctx = build_catch_context_for_spot(
            spot_id,
            spot_store=get_spot_intelligence_store(),
            catch_store=get_catch_record_store(),
        )
        if not ctx.get("found") or int(ctx.get("catch_count") or 0) <= 0:
            return None
        return {
            "catch_count": ctx.get("catch_count"),
            "top_species": ctx.get("top_species"),
            "spot_reputation": ctx.get("spot_reputation"),
            "spot_level": ctx.get("spot_level"),
        }
    except Exception as exc:
        _logger.debug("Compare catch context skipped for %s: %s", spot_id, exc)
        return None
