from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List, Optional

from marine_intelligence.catch_snapshot import snapshots_from_last_report
from marine_intelligence.models import (
    BulkLearningSummariesResponseModel,
    CatchDeleteResponseModel,
    CatchListResponseModel,
    CatchRecordModel,
    CreateCatchRequestModel,
    CreateCatchResponseModel,
    LearningSummaryModel,
    PatchCatchRequestModel,
    SpotIntelligenceModel,
    UpdateCatchResponseModel,
)
from marine_intelligence.spot_reputation import (
    compute_spot_reputation,
    learning_summary_message_tr,
    recalculate_spot_reputation,
    spot_level_from_reputation,
)
from marine_intelligence.storage.base import SpotIntelligenceStoreProtocol
from marine_intelligence.storage.catch_record_store import CatchRecordStoreProtocol


class CatchIntelligenceService:
    def __init__(
        self,
        spot_store: SpotIntelligenceStoreProtocol,
        catch_store: CatchRecordStoreProtocol,
    ) -> None:
        self._spot_store = spot_store
        self._catch_store = catch_store

    def create_catch(
        self,
        spot_id: str,
        body: CreateCatchRequestModel,
    ) -> Optional[CreateCatchResponseModel]:
        spot = self._spot_store.get_spot(spot_id)
        if spot is None:
            return None

        snapshots = snapshots_from_last_report(spot.last_report)
        catch = self._catch_store.create_catch(
            spot_id=spot_id,
            species=body.species,
            caught_at=body.caught_at,
            length_cm=body.length_cm,
            weight_kg=body.weight_kg,
            bait=body.bait,
            method=body.method,
            notes=body.notes,
            **snapshots,
        )

        updated_spot = self._recalculate_spot(spot_id)
        if updated_spot is None:
            return None

        learning = self.build_learning_summary(spot_id, spot=updated_spot)
        return CreateCatchResponseModel(
            catch=catch,
            spot=updated_spot,
            learning_summary=learning,
        )

    def update_catch(
        self,
        catch_id: str,
        body: PatchCatchRequestModel,
    ) -> Optional[UpdateCatchResponseModel]:
        existing = self._catch_store.get_catch(catch_id)
        if existing is None:
            return None

        if not any(
            getattr(body, field) is not None
            for field in (
                "species",
                "length_cm",
                "weight_kg",
                "bait",
                "method",
                "caught_at",
                "notes",
            )
        ):
            spot = self._spot_store.get_spot(existing.spot_id)
            if spot is None:
                return None
            learning = self.build_learning_summary(existing.spot_id, spot=spot)
            return UpdateCatchResponseModel(
                catch=existing,
                spot=spot,
                learning_summary=learning,
            )

        catch = self._catch_store.update_catch(
            catch_id,
            species=body.species,
            length_cm=body.length_cm,
            weight_kg=body.weight_kg,
            bait=body.bait,
            method=body.method,
            caught_at=body.caught_at,
            notes=body.notes,
        )
        if catch is None:
            return None

        updated_spot = self._recalculate_spot(existing.spot_id)
        if updated_spot is None:
            return None

        learning = self.build_learning_summary(existing.spot_id, spot=updated_spot)
        return UpdateCatchResponseModel(
            catch=catch,
            spot=updated_spot,
            learning_summary=learning,
        )

    def list_catches(self, spot_id: str) -> Optional[CatchListResponseModel]:
        spot = self._spot_store.get_spot(spot_id)
        if spot is None:
            return None
        catches = self._catch_store.list_catches(spot_id=spot_id)
        summary = self.build_learning_summary(spot_id, spot=spot)
        return CatchListResponseModel(
            catches=catches,
            count=len(catches),
            summary=summary,
        )

    def delete_catch(self, catch_id: str) -> Optional[CatchDeleteResponseModel]:
        existing = self._catch_store.get_catch(catch_id)
        if existing is None:
            return None
        spot_id = existing.spot_id
        deleted = self._catch_store.delete_catch(catch_id)
        if not deleted:
            return None

        updated_spot = self._recalculate_spot(spot_id)
        learning = self.build_learning_summary(spot_id, spot=updated_spot) if updated_spot else None
        return CatchDeleteResponseModel(
            deleted=True,
            id=catch_id,
            spot_id=spot_id,
            learning_summary=learning,
        )

    def bulk_learning_summaries(
        self,
        spot_ids: List[str],
    ) -> BulkLearningSummariesResponseModel:
        summaries: Dict[str, Optional[LearningSummaryModel]] = {}
        missing: List[str] = []
        for spot_id in spot_ids:
            spot = self._spot_store.get_spot(spot_id)
            if spot is None:
                summaries[spot_id] = None
                missing.append(spot_id)
                continue
            summaries[spot_id] = self.build_learning_summary(spot_id, spot=spot)
        return BulkLearningSummariesResponseModel(
            summaries=summaries,
            missing_spot_ids=missing,
        )

    def build_learning_summary(
        self,
        spot_id: str,
        *,
        spot: Optional[SpotIntelligenceModel] = None,
    ) -> LearningSummaryModel:
        spot = spot or self._spot_store.get_spot(spot_id)
        summary_data = self._catch_store.summary_for_spot(spot_id)
        catch_count = int(summary_data["catch_count"])
        reputation = int(spot.spot_reputation) if spot and spot.spot_reputation is not None else None
        if reputation is None and catch_count > 0 and spot is not None:
            reputation, _ = compute_spot_reputation(
                catch_count=catch_count,
                visit_count=spot.visit_count,
                has_recent_success=bool(summary_data.get("last_success_date")),
                go_score=_go_score_from_spot(spot),
            )
        level = spot_level_from_reputation(reputation) if reputation is not None else None
        return LearningSummaryModel(
            spot_id=spot_id,
            catch_count=catch_count,
            top_species=summary_data.get("top_species"),
            last_success_date=summary_data.get("last_success_date"),
            average_weight_kg=summary_data.get("average_weight_kg"),
            spot_reputation=reputation,
            spot_level=level,
            message_tr=learning_summary_message_tr(
                catch_count=catch_count,
                spot_level=level or "Bronze",
            ),
        )

    def _recalculate_spot(self, spot_id: str) -> Optional[SpotIntelligenceModel]:
        result = recalculate_spot_reputation(
            spot_id,
            spot_store=self._spot_store,
            catch_store=self._catch_store,
        )
        if result is None:
            return None
        updated, _, _ = result
        return updated


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
