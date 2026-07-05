from __future__ import annotations

from typing import List, Optional

from marine_intelligence.models import (
    ConsensusSummaryModel,
    ConsensusValueModel,
    ExplainabilityModel,
    MarineBlockModel,
    WeatherBlockModel,
    WindBlockModel,
)

_REASON_FACTOR_MAP = {
    "low_wind": ("positive", "Rüzgar düşük — koşullar yönetilebilir görünüyor."),
    "moderate_wave": ("positive", "Dalga yüksekliği düşük-orta seviyede."),
    "good_moon_window": ("positive", "Ay ışığı düşük — gece balıkçılığı için olumlu olabilir."),
    "high_gust": ("negative", "Ani rüzgar değerleri dikkat gerektiriyor."),
    "high_risk": ("negative", "Risk göstergeleri yüksek — dikkatli olun."),
    "single_provider_uncertainty": (
        "uncertainty",
        "Veri yalnızca tek sağlayıcıdan geldiği için güven orta seviyede.",
    ),
    "partial_data": (
        "uncertainty",
        "Bazı sağlayıcılardan veri alınamadı — karar sınırlı veriye dayanıyor.",
    ),
}


def _value(model: Optional[ConsensusValueModel]) -> Optional[float]:
    return model.final_value if model is not None else None


def _append_unique(bucket: List[str], text: str) -> None:
    if text and text not in bucket:
        bucket.append(text)


def compute_explainability(
    *,
    weather: WeatherBlockModel,
    wind: WindBlockModel,
    marine: MarineBlockModel,
    consensus_summary: ConsensusSummaryModel,
    partial_data: bool,
    decision_reason_codes: Optional[List[str]] = None,
    most_sensitive_factor_tr: Optional[str] = None,
) -> ExplainabilityModel:
    positive: List[str] = []
    negative: List[str] = []
    uncertainty: List[str] = []

    codes = list(decision_reason_codes or [])
    if partial_data and "partial_data" not in codes:
        codes.append("partial_data")

    for code in codes:
        mapped = _REASON_FACTOR_MAP.get(code)
        if mapped is None:
            continue
        kind, message = mapped
        if kind == "positive":
            _append_unique(positive, message)
        elif kind == "negative":
            _append_unique(negative, message)
        else:
            _append_unique(uncertainty, message)

    wind_speed = _value(wind.speed_kmh)
    gust = _value(wind.gust_kmh)
    wave = _value(marine.wave_height_m)
    swell = _value(marine.swell_height_m)
    rain = _value(weather.precipitation_probability_pct)

    if "low_wind" not in codes and wind_speed is not None:
        if wind_speed <= 15:
            _append_unique(positive, "Rüzgar seviyesi yönetilebilir görünüyor.")
        elif wind_speed <= 30:
            _append_unique(uncertainty, "Rüzgar orta seviyede — deneyime göre değerlendirin.")
        else:
            _append_unique(negative, "Rüzgar güçlü — denize çıkmadan önce koşulları tekrar kontrol edin.")

    if "high_gust" not in codes and gust is not None and wind_speed is not None and gust > wind_speed + 10:
        _append_unique(negative, "Ani rüzgar değerleri dikkat gerektiriyor.")

    if "moderate_wave" not in codes and wave is not None:
        if wave <= 0.8:
            _append_unique(positive, "Dalga yüksekliği düşük-orta seviyede.")
        elif wave <= 1.5:
            _append_unique(uncertainty, "Dalga yüksekliği orta — küçük tekneler için yorucu olabilir.")
        else:
            _append_unique(negative, "Dalga yüksekliği küçük tekneler için yorucu olabilir.")

    if swell is not None and swell > 1.5:
        _append_unique(negative, "Swell yüksek — açık deniz koşulları zorlayıcı olabilir.")

    if rain is not None:
        if rain >= 60:
            _append_unique(negative, "Yağış ihtimali yüksek.")
        elif rain >= 30:
            _append_unique(uncertainty, "Yağış ihtimali artıyor.")

    if (
        "single_provider_uncertainty" not in codes
        and consensus_summary.overall_confidence <= 0.6
    ):
        _append_unique(
            uncertainty,
            "Veri yalnızca tek sağlayıcıdan geldiği için güven orta seviyede.",
        )

    for group in consensus_summary.disagreement_groups:
        _append_unique(uncertainty, f"{group} grubunda sağlayıcılar arasında fark var.")

    if partial_data and not any("sağlayıcı" in u for u in uncertainty):
        reason = consensus_summary.partial_data_reason or "Bazı sağlayıcılardan veri alınamadı."
        _append_unique(uncertainty, reason)

    if not positive and not negative and not uncertainty:
        _append_unique(uncertainty, "Yeterli veri yok — yorum sınırlı.")

    if most_sensitive_factor_tr:
        _append_unique(uncertainty, most_sensitive_factor_tr)

    summary_parts: List[str] = []
    if positive:
        summary_parts.append("Olumlu: " + positive[0])
    if negative:
        summary_parts.append("Dikkat: " + negative[0])
    if uncertainty and not summary_parts:
        summary_parts.append(uncertainty[0])
    explanation_summary = (
        " ".join(summary_parts) if summary_parts else "Koşullar genel olarak değerlendirildi."
    )

    return ExplainabilityModel(
        positive_factors=positive,
        negative_factors=negative,
        uncertainty_factors=uncertainty,
        explanation_summary_tr=explanation_summary,
        most_sensitive_factor_tr=most_sensitive_factor_tr,
    )
