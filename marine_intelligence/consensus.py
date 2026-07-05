from __future__ import annotations

import math
from typing import Dict, Iterable, List, Optional, Tuple

from marine_intelligence.models import ConsensusValueModel, DisagreementLevel
from marine_intelligence.providers.reliability import ProviderReliability

_SINGLE_SOURCE_MAX_CONFIDENCE = 0.6


def normalize_deg(value: float) -> float:
    return float(value) % 360.0


def circular_mean_deg(values: Iterable[float]) -> Optional[float]:
    """Açı değerleri için vektör ortalaması (0-360)."""
    entries = [(float(v), 1.0) for v in values]
    return circular_weighted_mean_deg(entries)


def circular_weighted_mean_deg(entries: Iterable[Tuple[float, float]]) -> Optional[float]:
    sin_sum = 0.0
    cos_sum = 0.0
    total_weight = 0.0
    for value, weight in entries:
        if weight <= 0:
            continue
        rad = math.radians(normalize_deg(value))
        sin_sum += weight * math.sin(rad)
        cos_sum += weight * math.cos(rad)
        total_weight += weight
    if total_weight == 0:
        return None
    mean_rad = math.atan2(sin_sum / total_weight, cos_sum / total_weight)
    return round((math.degrees(mean_rad) + 360.0) % 360.0, 2)


def _circular_spread_deg(values: List[float]) -> float:
    if len(values) <= 1:
        return 0.0
    mean = circular_mean_deg(values)
    if mean is None:
        return 0.0
    diffs = []
    for v in values:
        diff = abs(normalize_deg(v) - mean)
        diff = min(diff, 360.0 - diff)
        diffs.append(diff)
    return max(diffs)


def disagreement_level(values: List[float], *, is_angle: bool = False) -> DisagreementLevel:
    if len(values) <= 1:
        return "unknown"
    if is_angle:
        spread = _circular_spread_deg(values)
        if spread <= 5.0:
            return "low"
        if spread <= 20.0:
            return "medium"
        return "high"
    spread = max(values) - min(values)
    if spread <= 0.5:
        return "low"
    if spread <= 2.0:
        return "medium"
    return "high"


def _consensus_confidence(
    entries: List[Tuple[str, float, float]],
    reliabilities: Dict[str, ProviderReliability],
    disagreement: DisagreementLevel,
) -> float:
    if len(entries) == 1:
        return _SINGLE_SOURCE_MAX_CONFIDENCE

    agreement_bonus = {"low": 0.15, "medium": 0.05, "high": -0.1, "unknown": 0.0}[disagreement]
    runtimes = [
        reliabilities[name].runtime_confidence
        for name, _, _ in entries
        if reliabilities.get(name) is not None
    ]
    avg_runtime = sum(runtimes) / len(runtimes) if runtimes else 0.75
    base = 0.68 + 0.06 * (len(entries) - 1) + agreement_bonus
    runtime_factor = 0.65 + 0.35 * avg_runtime
    return min(0.95, round(base * runtime_factor, 3))


def build_consensus(
    field_key: str,
    provider_values: Dict[str, Optional[float]],
    reliabilities: Dict[str, ProviderReliability],
    *,
    unit: Optional[str] = None,
    is_angle: bool = False,
) -> ConsensusValueModel:
    del field_key  # reserved for telemetry / logging
    entries: List[Tuple[str, float, float]] = []
    for name, raw in provider_values.items():
        if raw is None:
            continue
        rel = reliabilities.get(name)
        weight = rel.effective_weight if rel and rel.enabled else 0.0
        if weight <= 0:
            continue
        entries.append((name, float(raw), weight))

    clean_values = {k: provider_values.get(k) for k in provider_values}
    if not entries:
        return ConsensusValueModel(
            final_value=None,
            unit=unit,
            provider_values=clean_values,
            confidence=0.0,
            source_count=0,
            disagreement_level="unknown",
        )

    values = [v for _, v, _ in entries]

    if len(entries) == 1:
        name, val, _ = entries[0]
        return ConsensusValueModel(
            final_value=val,
            unit=unit,
            provider_values={name: val},
            confidence=_consensus_confidence(entries, reliabilities, "unknown"),
            source_count=1,
            disagreement_level="unknown",
            min_value=val,
            max_value=val,
            mean_value=round(val, 3),
        )

    total_weight = sum(w for _, _, w in entries)
    if is_angle:
        final = circular_weighted_mean_deg([(v, w) for _, v, w in entries])
    else:
        final = round(sum(v * w for _, v, w in entries) / total_weight, 3) if total_weight else None

    mean_val = round(sum(values) / len(values), 3)
    disagree = disagreement_level(values, is_angle=is_angle)
    confidence = _consensus_confidence(entries, reliabilities, disagree)

    return ConsensusValueModel(
        final_value=final,
        unit=unit,
        provider_values={n: v for n, v, _ in entries},
        confidence=confidence,
        source_count=len(entries),
        disagreement_level=disagree,
        min_value=min(values),
        max_value=max(values),
        mean_value=mean_val,
    )
