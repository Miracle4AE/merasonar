from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from marine_intelligence.decision_engine import compute_go_score_from_fishing, decision_from_scores
from marine_intelligence.models import (
    AstronomyBlockModel,
    DecisionModel,
    FishingScoreModel,
    MarineBlockModel,
    ScenarioBundleModel,
    ScenarioItemModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.scoring import compute_fishing_score

_SENSITIVITY_LABELS = {
    "wind_plus_5": "Rüzgar",
    "gust_plus_10": "Ani rüzgar",
    "wave_plus_0_5": "Dalga",
    "rain_plus_30": "Yağış",
    "moon_high": "Ay ışığı",
}

_SCENARIO_DEFS: Tuple[Tuple[str, str, Dict[str, Any]], ...] = (
    ("wind_plus_5", "Rüzgar 5 km/h artsa?", {"wind_speed_kmh": "+5"}),
    ("gust_plus_10", "Ani rüzgar 10 km/h artsa?", {"gust_kmh": "+10"}),
    ("wave_plus_0_5", "Dalga 0.5 m artsa?", {"wave_height_m": "+0.5"}),
    ("rain_plus_30", "Yağış ihtimali %30 artsa?", {"precipitation_probability_pct": "+30"}),
    ("moon_high", "Ay ışığı yüksek olsaydı?", {"moon_illumination_pct": "high"}),
)

_DECISION_LABEL_TR = {
    "excellent": "çok uygun",
    "good": "uygun",
    "borderline": "sınırda",
    "poor": "zayıf",
    "unsafe": "riskli",
}


def _clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def _value(model: Optional[object]) -> Optional[float]:
    if model is None:
        return None
    final = getattr(model, "final_value", None)
    return float(final) if final is not None else None


def _delta_summary_tr(
    scenario_id: str,
    delta_go: int,
    delta_risk: int,
    decision: str,
    *,
    low_confidence: bool,
) -> str:
    label = _DECISION_LABEL_TR.get(decision, decision)
    if low_confidence:
        return f"Veri sınırlı — {scenario_id.replace('_', ' ')} senaryosu yaklaşık olarak {label} seviyesine işaret edebilir."
    if delta_go <= -10 or delta_risk >= 10:
        return f"Bu değişim kararı {label} seviyesine çekebilir — kesin sonuç garantisi yok."
    if delta_go >= 5 and delta_risk <= 0:
        return f"Koşullar hâlâ {label} görünebilir; yine de yerel uyarıları kontrol edin."
    return f"Karar {label} yönünde değişebilir — yaklaşık bir tahmindir."


def _apply_changed(
    base: Optional[float],
    change: Any,
    *,
    clamp_max: Optional[float] = None,
) -> Optional[float]:
    if change == "high":
        return 90.0
    if isinstance(change, str) and change.startswith("+"):
        try:
            delta = float(change[1:])
        except ValueError:
            return base
        if base is None:
            return None
        result = base + delta
        if clamp_max is not None:
            result = min(result, clamp_max)
        return result
    return base


def compute_scenarios(
    *,
    base_decision: Optional[DecisionModel],
    fishing_score: FishingScoreModel,
    wind: WindBlockModel,
    marine: MarineBlockModel,
    weather: WeatherBlockModel,
    astronomy: AstronomyBlockModel,
    confidence: float,
    partial_data: bool,
    reason_codes: Optional[List[str]] = None,
) -> Optional[ScenarioBundleModel]:
    if base_decision is None or base_decision.go_score is None:
        return None

    base_go = base_decision.go_score
    base_risk = fishing_score.risk_score
    wind_speed = _value(wind.speed_kmh)
    gust = _value(wind.gust_kmh)
    wave = _value(marine.wave_height_m)
    swell = _value(marine.swell_height_m)
    rain = _value(weather.precipitation_probability_pct)
    moon = astronomy.moon_illumination_pct

    items: List[ScenarioItemModel] = []
    for scenario_id, title_tr, changed in _SCENARIO_DEFS:
        mod_wind = _apply_changed(wind_speed, changed.get("wind_speed_kmh"))
        mod_gust = _apply_changed(gust, changed.get("gust_kmh"))
        mod_wave = _apply_changed(wave, changed.get("wave_height_m"))
        mod_rain = _apply_changed(
            rain,
            changed.get("precipitation_probability_pct"),
            clamp_max=100.0,
        )
        mod_moon = moon
        if changed.get("moon_illumination_pct") == "high":
            mod_moon = 90.0 if moon is not None else 85.0

        missing_inputs = (
            (changed.get("wind_speed_kmh") and mod_wind is None)
            or (changed.get("gust_kmh") and mod_gust is None)
            or (changed.get("wave_height_m") and mod_wave is None)
            or (changed.get("precipitation_probability_pct") and mod_rain is None)
        )

        scenario_score = compute_fishing_score(
            wind_speed_kmh=mod_wind,
            wind_gust_kmh=mod_gust,
            wave_height_m=mod_wave,
            swell_height_m=swell,
            rain_probability_pct=mod_rain,
            moon_illumination_pct=mod_moon,
            confidence=confidence if not missing_inputs else min(confidence, 0.5),
        )
        resulting_go = compute_go_score_from_fishing(
            scenario_score,
            confidence if not missing_inputs else min(confidence, 0.5),
            partial_data=partial_data,
            extra_reason_codes=reason_codes,
        )
        resulting_risk = scenario_score.risk_score
        delta_go = resulting_go - base_go
        delta_risk = resulting_risk - base_risk
        scenario_decision = decision_from_scores(resulting_go, resulting_risk, confidence)

        items.append(
            ScenarioItemModel(
                scenario_id=scenario_id,
                title_tr=title_tr,
                changed_inputs=changed,
                resulting_go_score=resulting_go,
                resulting_risk_score=resulting_risk,
                decision=scenario_decision,
                delta_go_score=delta_go,
                delta_risk_score=delta_risk,
                delta_summary_tr=_delta_summary_tr(
                    scenario_id,
                    delta_go,
                    delta_risk,
                    scenario_decision,
                    low_confidence=missing_inputs,
                ),
            )
        )

    return ScenarioBundleModel(base_go_score=base_go, items=items)


def most_sensitive_factor_from_scenarios(
    bundle: Optional[ScenarioBundleModel],
) -> Optional[str]:
    if bundle is None or not bundle.items:
        return None
    ranked = sorted(
        bundle.items,
        key=lambda item: abs(item.delta_go_score or 0) + abs(item.delta_risk_score or 0),
        reverse=True,
    )
    top = ranked[0]
    label = _SENSITIVITY_LABELS.get(top.scenario_id)
    if not label:
        return None
    return f"Bu nokta en çok {label.lower()} artışına duyarlı görünüyor."
