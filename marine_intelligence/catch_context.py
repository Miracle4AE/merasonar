from __future__ import annotations

from typing import Any, Dict, Optional

from marine_intelligence.catch_service import CatchIntelligenceService
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol
from marine_intelligence.storage.catch_record_store import CatchRecordStoreProtocol


def build_catch_context_for_spot(
    spot_id: str,
    *,
    spot_store: SpotIntelligenceStoreProtocol,
    catch_store: CatchRecordStoreProtocol,
    catch_service: Optional[CatchIntelligenceService] = None,
) -> Dict[str, Any]:
    """Captain Atlas future hook — AI prompt'a bağlanmaz."""
    service = catch_service or CatchIntelligenceService(spot_store, catch_store)
    spot = spot_store.get_spot(spot_id)
    if spot is None:
        return {"spot_id": spot_id, "found": False}

    catches = catch_store.list_catches(spot_id=spot_id)[:10]
    summary = service.build_learning_summary(spot_id, spot=spot)
    recent = [
        {
            "species": c.species,
            "weight_kg": c.weight_kg,
            "length_cm": c.length_cm,
            "caught_at": c.caught_at,
            "bait": c.bait,
            "method": c.method,
        }
        for c in catches
    ]
    return {
        "spot_id": spot_id,
        "found": True,
        "recent_catches": recent,
        "top_species": summary.top_species,
        "catch_count": summary.catch_count,
        "last_success_date": summary.last_success_date,
        "recent_success": summary.last_success_date is not None,
        "spot_reputation": summary.spot_reputation,
        "spot_level": summary.spot_level,
        "average_weight_kg": summary.average_weight_kg,
    }
