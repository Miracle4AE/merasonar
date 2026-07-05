from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from marine_intelligence.models import (
    SpotIntelligenceModel,
    SpotRefreshResponseModel,
)
from marine_intelligence.report_snapshot import trim_report_snapshot
from marine_intelligence.service import MarineIntelligenceService
from marine_intelligence.spot_reputation import recalculate_spot_reputation
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol


class SpotIntelligenceService:
    def __init__(
        self,
        store: SpotIntelligenceStoreProtocol,
        marine_service: MarineIntelligenceService,
    ) -> None:
        self._store = store
        self._marine_service = marine_service

    def refresh_spot(
        self,
        spot_id: str,
        *,
        force_refresh: bool = False,
        include_ai_comment: bool = False,
        client_ip: str = "unknown",
    ) -> Optional[SpotRefreshResponseModel]:
        spot = self._store.get_spot(spot_id)
        if spot is None:
            return None

        report = self._marine_service.get_coordinate_intelligence(
            spot.lat,
            spot.lon,
            force_refresh=force_refresh,
            include_ai_comment=include_ai_comment,
            client_ip=client_ip,
            spot_id=spot_id if include_ai_comment else None,
        )
        snapshot = trim_report_snapshot(report)
        report_at = datetime.now(timezone.utc).isoformat()

        self._store.update_last_report(spot_id, snapshot, report_at=report_at)
        self._store.increment_visit_count(spot_id)
        self._maybe_recalculate_reputation(spot_id)
        updated = self._store.get_spot(spot_id)
        if updated is None:
            return None

        return SpotRefreshResponseModel(
            spot=updated,
            report=report,
        )

    def delete_spot_with_catches(
        self,
        spot_id: str,
        *,
        catch_store: Optional[object] = None,
    ) -> tuple[bool, int]:
        deleted_catches = 0
        if catch_store is not None:
            deleted_catches = int(catch_store.delete_catches_for_spot(spot_id))  # type: ignore[attr-defined]
        deleted = self._store.delete_spot(spot_id)
        return deleted, deleted_catches

    def _maybe_recalculate_reputation(self, spot_id: str) -> None:
        try:
            from marine_intelligence.config import MarineIntelligenceConfig
            from marine_intelligence.dependencies import (
                get_catch_record_store,
                get_marine_intelligence_config,
            )

            cfg: MarineIntelligenceConfig = get_marine_intelligence_config()
            if not cfg.marine_catch_storage_enabled:
                return
            recalculate_spot_reputation(
                spot_id,
                spot_store=self._store,
                catch_store=get_catch_record_store(),
            )
        except Exception:
            return
