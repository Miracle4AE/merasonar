from __future__ import annotations

from typing import Any, Dict, List, Optional, Protocol

from marine_intelligence.models import SpotIntelligenceModel


class SpotIntelligenceStoreProtocol(Protocol):
    def create_spot(
        self,
        *,
        name: str,
        lat: float,
        lon: float,
        note: Optional[str] = None,
        favorite: bool = False,
        personal_tags: Optional[List[str]] = None,
    ) -> SpotIntelligenceModel:
        ...

    def list_spots(self, *, favorite: Optional[bool] = None) -> List[SpotIntelligenceModel]:
        ...

    def get_spot(self, spot_id: str) -> Optional[SpotIntelligenceModel]:
        ...

    def update_spot(
        self,
        spot_id: str,
        *,
        name: Optional[str] = None,
        note: Optional[str] = None,
        favorite: Optional[bool] = None,
        personal_tags: Optional[List[str]] = None,
    ) -> Optional[SpotIntelligenceModel]:
        ...

    def delete_spot(self, spot_id: str) -> bool:
        ...

    def update_last_report(
        self,
        spot_id: str,
        report: Dict[str, Any],
        *,
        report_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        ...

    def increment_visit_count(self, spot_id: str) -> Optional[SpotIntelligenceModel]:
        ...

    def apply_catch_success(
        self,
        spot_id: str,
        *,
        caught_at: str,
        species: str,
        weight_kg: Optional[float],
        spot_reputation: float,
        spot_reputation_factors: List[str],
        reputation_updated_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        ...

    def apply_spot_learning_state(
        self,
        spot_id: str,
        *,
        last_success_date: Optional[str],
        last_success_species: Optional[str],
        last_success_weight: Optional[float],
        spot_reputation: float,
        spot_reputation_factors: List[str],
        reputation_updated_at: str,
    ) -> Optional[SpotIntelligenceModel]:
        ...
