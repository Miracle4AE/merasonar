from __future__ import annotations

from typing import Dict, List, Optional

from marine_intelligence.models import (
    ProviderComparisonEntryModel,
    ProviderComparisonModel,
    ProviderComparisonSummaryModel,
)
from marine_intelligence.providers.base import MarineProviderSnapshot
from marine_intelligence.providers.reliability import ProviderReliability, ProviderReliabilityRegistry

_WIND_METRIC_ALIASES = {
    "speed_kmh": "wind_speed_kmh",
    "direction_deg": "wind_direction_deg",
    "gust_kmh": "wind_gust_kmh",
}


def _metrics_from_snapshot(snap: MarineProviderSnapshot) -> List[str]:
    metrics: List[str] = []
    for key, value in (snap.weather or {}).items():
        if value is not None:
            metrics.append(key)
    for key, value in (snap.wind or {}).items():
        if value is not None:
            metrics.append(_WIND_METRIC_ALIASES.get(key, key))
    for key, value in (snap.marine or {}).items():
        if value is not None:
            metrics.append(key)
    if snap.astronomy:
        metrics.append("astronomy")
    return sorted(set(metrics))


def _status_from_snapshot(snap: MarineProviderSnapshot, provider_status: Dict[str, str]) -> str:
    if snap.provider_name in provider_status:
        return provider_status[snap.provider_name]
    if snap.success:
        return "ok"
    if snap.error == "disabled":
        return "disabled"
    if snap.error == "not_implemented":
        return "not_implemented"
    return "failed"


def build_provider_comparison(
    snapshots: List[MarineProviderSnapshot],
    registry: ProviderReliabilityRegistry,
    provider_status: Dict[str, str],
) -> ProviderComparisonModel:
    entries: List[ProviderComparisonEntryModel] = []
    healthy = partial = failed = 0
    confidence_values: List[float] = []

    snapshot_by_name = {s.provider_name: s for s in snapshots}

    for rel in registry.list_all():
        if not rel.enabled and rel.provider_name not in snapshot_by_name:
            continue
        snap = snapshot_by_name.get(rel.provider_name)
        status = _status_from_snapshot(snap, provider_status) if snap else "disabled"
        if status == "ok":
            healthy += 1
            confidence_values.append(rel.runtime_confidence)
        elif status in {"failed", "not_implemented"}:
            failed += 1
        elif status == "partial":
            partial += 1

        entries.append(
            ProviderComparisonEntryModel(
                name=rel.provider_name,
                enabled=rel.enabled,
                status=status if snap or rel.enabled else "disabled",
                weight=round(rel.static_weight, 2),
                confidence=rel.runtime_confidence,
                last_success=rel.last_success.isoformat() if rel.last_success else None,
                last_failure=rel.last_failure.isoformat() if rel.last_failure else None,
                metrics_provided=_metrics_from_snapshot(snap) if snap and snap.success else [],
            )
        )

    overall = round(sum(confidence_values) / len(confidence_values), 2) if confidence_values else 0.0
    return ProviderComparisonModel(
        providers=entries,
        summary=ProviderComparisonSummaryModel(
            provider_count=len([e for e in entries if e.enabled]),
            healthy_count=healthy,
            partial_count=partial,
            failed_count=failed,
            overall_provider_confidence=overall,
        ),
    )
