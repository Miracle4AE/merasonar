from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional, Tuple

from marine_intelligence.models import SpotIntelligenceModel
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol
from marine_intelligence.storage.catch_record_store import CatchRecordStoreProtocol


def clamp(value: float, low: float, high: float) -> int:
    return int(max(low, min(high, round(value))))


def spot_level_from_reputation(reputation: int) -> str:
    if reputation >= 90:
        return "Legendary"
    if reputation >= 75:
        return "Elite"
    if reputation >= 60:
        return "Gold"
    if reputation >= 40:
        return "Silver"
    return "Bronze"


def compute_spot_reputation(
    *,
    catch_count: int,
    visit_count: int,
    has_recent_success: bool,
    go_score: Optional[int],
) -> Tuple[int, List[str]]:
    recent_bonus = 10 if has_recent_success else 0
    go_bonus = 0
    if go_score is not None:
        go_bonus = max(0, min(20, int((go_score - 50) / 2)))
    score = clamp(40 + catch_count * 8 + recent_bonus + go_bonus, 0, 100)
    factors = [
        f"catch_count:{catch_count}",
        f"visit_count:{visit_count}",
    ]
    if recent_bonus:
        factors.append("recent_success")
    if go_bonus:
        factors.append(f"go_score_bonus:{go_bonus}")
    return score, factors


def learning_summary_message_tr(*, catch_count: int, spot_level: str) -> str:
    if catch_count <= 0:
        return "Bu spot için henüz av kaydı yok."
    if catch_count == 1:
        return "Bu spot için ilk av kaydı oluştu."
    if spot_level in {"Gold", "Elite", "Legendary"}:
        return "Bu spot için birkaç başarılı kayıt oluşmaya başladı."
    return f"Bu spot için {catch_count} av kaydı mevcut."


def _go_score_from_spot(spot: SpotIntelligenceModel) -> Optional[int]:
    report = spot.last_report or {}
    decision = report.get("decision") or {}
    go_score = decision.get("go_score")
    if go_score is None:
        return None
    try:
        return int(go_score)
    except (TypeError, ValueError):
        return None


def recalculate_spot_reputation(
    spot_id: str,
    *,
    spot_store: SpotIntelligenceStoreProtocol,
    catch_store: CatchRecordStoreProtocol,
) -> Optional[Tuple[SpotIntelligenceModel, int, List[str]]]:
    """Catch değişikliklerinden sonra spot reputation ve last_success alanlarını yeniden hesaplar."""
    spot = spot_store.get_spot(spot_id)
    if spot is None:
        return None

    summary_data = catch_store.summary_for_spot(spot_id)
    catch_count = int(summary_data["catch_count"])
    has_recent = bool(summary_data.get("last_success_date"))
    reputation, factors = compute_spot_reputation(
        catch_count=catch_count,
        visit_count=spot.visit_count,
        has_recent_success=has_recent,
        go_score=_go_score_from_spot(spot),
    )
    now = datetime.now(timezone.utc).isoformat()
    updated = spot_store.apply_spot_learning_state(
        spot_id,
        last_success_date=summary_data.get("last_success_date"),
        last_success_species=summary_data.get("last_success_species"),
        last_success_weight=summary_data.get("last_success_weight"),
        spot_reputation=float(reputation),
        spot_reputation_factors=factors,
        reputation_updated_at=now,
    )
    if updated is None:
        return None
    return updated, reputation, factors
