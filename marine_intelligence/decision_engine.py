from __future__ import annotations

from typing import List, Optional, Tuple

from marine_intelligence.models import (
    AstronomyBlockModel,
    ConsensusSummaryModel,
    DecisionModel,
    DecisionTimelineItemModel,
    FishingDecisionLevel,
    FishingScoreModel,
    HourlyForecastPointModel,
    MarineBlockModel,
    ProviderComparisonModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.scoring import compute_fishing_score

_STANDARD_TIMES: Tuple[str, ...] = ("06:00", "09:00", "12:00", "15:00")
# Sabah daha olumlu, öğleden sonra daha zorlayıcı — deterministik varyasyon.
_GO_DELTA_BY_SLOT: Tuple[int, ...] = (8, 3, -4, -8)
_RISK_DELTA_BY_SLOT: Tuple[int, ...] = (-5, -2, 4, 6)


def _clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def _value(model: Optional[object]) -> Optional[float]:
    if model is None:
        return None
    final = getattr(model, "final_value", None)
    return float(final) if final is not None else None


def _collect_reason_codes(
    *,
    wind_speed: Optional[float],
    gust: Optional[float],
    wave: Optional[float],
    swell: Optional[float],
    rain: Optional[float],
    moon_illumination: Optional[float],
    consensus_summary: ConsensusSummaryModel,
    partial_data: bool,
    risk_score: int,
) -> List[str]:
    codes: List[str] = []
    if wind_speed is not None and wind_speed <= 15:
        codes.append("low_wind")
    if gust is not None and wind_speed is not None and gust > wind_speed + 10:
        codes.append("high_gust")
    if wave is not None and wave <= 1.0:
        codes.append("moderate_wave")
    elif wave is not None and wave > 1.5:
        codes.append("high_risk")
    if swell is not None and swell > 1.5:
        codes.append("high_risk")
    if rain is not None and rain >= 50:
        codes.append("high_risk")
    if moon_illumination is not None and moon_illumination <= 35:
        codes.append("good_moon_window")
    if consensus_summary.overall_confidence <= 0.6:
        codes.append("single_provider_uncertainty")
    if partial_data:
        codes.append("partial_data")
    if risk_score >= 60 and "high_risk" not in codes:
        codes.append("high_risk")
    return list(dict.fromkeys(codes))


def decision_from_scores(
    go_score: int,
    risk_score: int,
    confidence: float,
) -> FishingDecisionLevel:
    return _decision_from_scores(go_score, risk_score, confidence)


def compute_go_score_from_fishing(
    fishing_score: FishingScoreModel,
    confidence: float,
    *,
    partial_data: bool = False,
    extra_reason_codes: Optional[List[str]] = None,
) -> int:
    suitability = fishing_score.suitability_score
    risk = fishing_score.risk_score
    reason_codes = list(extra_reason_codes or [])
    go_score = _clamp_score(suitability * (1.0 - risk / 250.0) * (0.65 + 0.35 * confidence))
    if "high_risk" in reason_codes and risk >= 45:
        go_score = _clamp_score(go_score - 15)
    if "single_provider_uncertainty" in reason_codes:
        go_score = _clamp_score(go_score - 8)
    if partial_data:
        go_score = _clamp_score(go_score - 5)
    return go_score


def _decision_from_scores(
    go_score: int,
    risk_score: int,
    confidence: float,
) -> FishingDecisionLevel:
    adjusted_go = go_score
    if confidence <= 0.55:
        adjusted_go -= 12
    elif confidence <= 0.65:
        adjusted_go -= 6

    if risk_score >= 75 or adjusted_go < 20:
        return "unsafe"
    if risk_score >= 55 and adjusted_go >= 55:
        return "borderline"
    if risk_score >= 50 or adjusted_go < 35:
        return "poor"
    if adjusted_go >= 78 and risk_score <= 30:
        return "excellent"
    if adjusted_go >= 62 and risk_score <= 45:
        return "good"
    return "borderline"


def _best_action_tr(decision: FishingDecisionLevel, reason_codes: List[str]) -> str:
    if decision == "excellent":
        return "Koşullar genel olarak olumlu — planınızı güvenlik ekipmanıyla uygulayabilirsiniz."
    if decision == "good":
        return "Denize çıkmak mümkün görünüyor; hava değişimini takip edin."
    if decision == "borderline":
        if "partial_data" in reason_codes:
            return "Veri eksik — karar vermeden önce yerel koşulları doğrulayın."
        return "Koşullar karışık — kısa bir keşif veya alternatif saat düşünün."
    if decision == "poor":
        return "Bugün zorlayıcı olabilir — ertelemek veya kıyı alternatiflerini değerlendirmek mantıklı."
    return "Güvenlik öncelikli — denize çıkmamanız önerilir."


def _short_summary_tr(
    decision: FishingDecisionLevel,
    go_score: int,
    risk_score: int,
) -> str:
    labels = {
        "excellent": "Koşullar çok uygun görünüyor",
        "good": "Koşullar uygun görünüyor",
        "borderline": "Koşullar sınırda",
        "poor": "Koşullar zayıf",
        "unsafe": "Koşullar riskli",
    }
    return f"{labels[decision]} (git: {go_score}, risk: {risk_score}). Kesin sonuç garantisi yok."


def compute_decision(
    *,
    fishing_score: FishingScoreModel,
    consensus_summary: ConsensusSummaryModel,
    provider_comparison: Optional[ProviderComparisonModel],
    weather: WeatherBlockModel,
    wind: WindBlockModel,
    marine: MarineBlockModel,
    astronomy: AstronomyBlockModel,
    partial_data: bool,
) -> DecisionModel:
    del provider_comparison  # gelecek faz ağırlıklandırması için rezerve

    suitability = fishing_score.suitability_score
    risk = fishing_score.risk_score
    confidence = max(fishing_score.confidence, consensus_summary.overall_confidence)

    wind_speed = _value(wind.speed_kmh)
    gust = _value(wind.gust_kmh)
    wave = _value(marine.wave_height_m)
    swell = _value(marine.swell_height_m)
    rain = _value(weather.precipitation_probability_pct)
    moon = astronomy.moon_illumination_pct

    reason_codes = _collect_reason_codes(
        wind_speed=wind_speed,
        gust=gust,
        wave=wave,
        swell=swell,
        rain=rain,
        moon_illumination=moon,
        consensus_summary=consensus_summary,
        partial_data=partial_data,
        risk_score=risk,
    )

    go_score = _clamp_score(suitability * (1.0 - risk / 250.0) * (0.65 + 0.35 * confidence))
    wait_score = _clamp_score(100 - go_score + risk * 0.35)

    if "high_risk" in reason_codes and risk >= 45:
        go_score = _clamp_score(go_score - 15)
        wait_score = _clamp_score(wait_score + 10)

    if "single_provider_uncertainty" in reason_codes:
        go_score = _clamp_score(go_score - 8)

    if partial_data:
        go_score = _clamp_score(go_score - 5)
        wait_score = _clamp_score(wait_score + 5)

    fishing_decision = _decision_from_scores(go_score, risk, confidence)

    return DecisionModel(
        fishing_decision=fishing_decision,
        go_score=go_score,
        wait_score=wait_score,
        best_action_tr=_best_action_tr(fishing_decision, reason_codes),
        decision_reason_codes=reason_codes,
        short_summary_tr=_short_summary_tr(fishing_decision, go_score, risk),
    )


def _slot_reason_tr(time: str, decision: FishingDecisionLevel, go_score: int) -> str:
    if time == "06:00":
        return "Sabah saatlerinde rüzgar genelde daha uygun görünüyor."
    if time == "09:00":
        return "Sabah geç saatlerinde koşullar hâlâ kabul edilebilir olabilir."
    if time == "12:00":
        if decision in {"borderline", "poor", "unsafe"}:
            return "Öğle saatlerinde rüzgar ve dalga artışı beklenebilir."
        return "Öğle saatlerinde koşullar orta seviyede."
    if go_score >= 65:
        return "Öğleden sonra kısa bir pencere olabilir; dikkatli olun."
    return "Öğleden sonra koşullar zorlaşabilir."


def _hourly_reason_tr(
    *,
    wind_speed: Optional[float],
    wave: Optional[float],
    decision: FishingDecisionLevel,
    go_score: int,
) -> str:
    if wind_speed is not None and wind_speed > 25:
        return "Bu saatte rüzgar güçlü görünüyor — dikkatli olun."
    if wave is not None and wave > 1.2:
        return "Bu saatte dalga yüksekliği artmış olabilir."
    if decision in {"excellent", "good"} and go_score >= 70:
        return "Bu saat penceresi görece uygun görünüyor."
    if decision in {"borderline", "poor"}:
        return "Bu saatte koşullar sınırda veya zayıf olabilir."
    return "Saatlik tahmine göre koşullar değişebilir — kesin sonuç yok."


def _select_hourly_indices(count: int) -> List[int]:
    if count >= 12:
        return [0, 2, 4, 6, 8, 10]
    if count >= 8:
        return [0, 2, 4, 6]
    if count >= 4:
        step = max(1, count // 4)
        return [min(i * step, count - 1) for i in range(4)]
    return []


def _timeline_from_hourly(
    *,
    hourly_series: List[HourlyForecastPointModel],
    base_wind_speed: Optional[float],
    base_gust: Optional[float],
    base_wave: Optional[float],
    base_swell: Optional[float],
    base_rain: Optional[float],
    moon_illumination: Optional[float],
    confidence: float,
    partial_data: bool,
    reason_codes: Optional[List[str]] = None,
) -> List[DecisionTimelineItemModel]:
    indices = _select_hourly_indices(len(hourly_series))
    if not indices:
        return []

    items: List[DecisionTimelineItemModel] = []
    for idx in indices:
        point = hourly_series[idx]
        wind_speed = point.wind_speed_kmh if point.wind_speed_kmh is not None else base_wind_speed
        gust = point.gust_kmh if point.gust_kmh is not None else base_gust
        wave = point.wave_height_m if point.wave_height_m is not None else base_wave
        rain = (
            point.precipitation_probability_pct
            if point.precipitation_probability_pct is not None
            else base_rain
        )
        slot_score = compute_fishing_score(
            wind_speed_kmh=wind_speed,
            wind_gust_kmh=gust,
            wave_height_m=wave,
            swell_height_m=base_swell,
            rain_probability_pct=rain,
            moon_illumination_pct=moon_illumination,
            confidence=confidence,
        )
        slot_go = compute_go_score_from_fishing(
            slot_score,
            confidence,
            partial_data=partial_data,
            extra_reason_codes=reason_codes,
        )
        slot_risk = slot_score.risk_score
        slot_decision = _decision_from_scores(slot_go, slot_risk, confidence)
        items.append(
            DecisionTimelineItemModel(
                time=point.time,
                go_score=slot_go,
                risk_score=slot_risk,
                decision=slot_decision,
                reason_tr=_hourly_reason_tr(
                    wind_speed=wind_speed,
                    wave=wave,
                    decision=slot_decision,
                    go_score=slot_go,
                ),
            )
        )
    return items


def _mark_best_slot(items: List[DecisionTimelineItemModel]) -> List[DecisionTimelineItemModel]:
    if not items:
        return items
    best_idx = 0
    best_score = items[0].go_score if items[0].go_score is not None else -1
    for idx, item in enumerate(items):
        score = item.go_score if item.go_score is not None else -1
        if score > best_score:
            best_score = score
            best_idx = idx
    if best_score < 0:
        return items
    marked: List[DecisionTimelineItemModel] = []
    for idx, item in enumerate(items):
        marked.append(
            item.model_copy(update={"is_best_slot": idx == best_idx and best_score >= 50})
        )
    return marked


def compute_decision_timeline(
    *,
    base_decision: DecisionModel,
    fishing_score: FishingScoreModel,
    partial_data: bool,
    hourly_series: Optional[List[HourlyForecastPointModel]] = None,
    wind: Optional[WindBlockModel] = None,
    marine: Optional[MarineBlockModel] = None,
    weather: Optional[WeatherBlockModel] = None,
    astronomy: Optional[AstronomyBlockModel] = None,
    reason_codes: Optional[List[str]] = None,
) -> List[DecisionTimelineItemModel]:
    """Hourly seri varsa ondan slot seçer; yoksa 06/09/12/15 fallback."""
    confidence = fishing_score.confidence
    if hourly_series:
        hourly_items = _timeline_from_hourly(
            hourly_series=hourly_series,
            base_wind_speed=_value(wind.speed_kmh) if wind else None,
            base_gust=_value(wind.gust_kmh) if wind else None,
            base_wave=_value(marine.wave_height_m) if marine else None,
            base_swell=_value(marine.swell_height_m) if marine else None,
            base_rain=_value(weather.precipitation_probability_pct) if weather else None,
            moon_illumination=astronomy.moon_illumination_pct if astronomy else None,
            confidence=confidence,
            partial_data=partial_data,
            reason_codes=reason_codes,
        )
        if hourly_items:
            return _mark_best_slot(hourly_items)

    base_go = base_decision.go_score or fishing_score.suitability_score
    base_risk = fishing_score.risk_score

    items: List[DecisionTimelineItemModel] = []
    for idx, time in enumerate(_STANDARD_TIMES):
        go_delta = _GO_DELTA_BY_SLOT[idx]
        risk_delta = _RISK_DELTA_BY_SLOT[idx]
        if partial_data and idx >= 2:
            go_delta -= 3
            risk_delta += 2

        slot_go = _clamp_score(base_go + go_delta)
        slot_risk = _clamp_score(base_risk + risk_delta)
        slot_decision = _decision_from_scores(slot_go, slot_risk, confidence)

        items.append(
            DecisionTimelineItemModel(
                time=time,
                go_score=slot_go,
                risk_score=slot_risk,
                decision=slot_decision,
                reason_tr=_slot_reason_tr(time, slot_decision, slot_go),
            )
        )
    return _mark_best_slot(items)
