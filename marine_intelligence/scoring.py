from __future__ import annotations

from typing import Optional

from marine_intelligence.models import FishingScoreModel


def _clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def compute_fishing_score(
    *,
    wind_speed_kmh: Optional[float],
    wind_gust_kmh: Optional[float],
    wave_height_m: Optional[float],
    swell_height_m: Optional[float],
    rain_probability_pct: Optional[float],
    moon_illumination_pct: Optional[float],
    confidence: float,
) -> FishingScoreModel:
    suitability = 70.0
    risk = 20.0

    if wind_speed_kmh is not None:
        if wind_speed_kmh <= 15:
            suitability += 10
            wind_comment = "Rüzgar hafif — balıkçılık için genelde uygun."
        elif wind_speed_kmh <= 30:
            wind_comment = "Rüzgar orta — dikkatli olun."
            suitability -= 5
            risk += 10
        else:
            wind_comment = "Rüzgar güçlü — risk artıyor."
            suitability -= 20
            risk += 25
    else:
        wind_comment = "Rüzgar verisi sınırlı."

    if wind_gust_kmh is not None and wind_speed_kmh is not None and wind_gust_kmh > wind_speed_kmh + 15:
        risk += 10
        wind_comment += " Ani rüzgar artışları olabilir."

    if wave_height_m is not None:
        if wave_height_m <= 0.8:
            wave_comment = "Dalga yüksekliği düşük — genelde uygun."
            suitability += 8
        elif wave_height_m <= 1.5:
            wave_comment = "Dalga orta seviyede."
            suitability -= 5
            risk += 8
        else:
            wave_comment = "Dalga yüksek — denize çıkmak riskli olabilir."
            suitability -= 18
            risk += 22
    else:
        wave_comment = "Dalga verisi sınırlı."

    if swell_height_m is not None:
        if swell_height_m <= 1.0:
            swell_comment = "Swell düşük."
            suitability += 5
        elif swell_height_m <= 2.0:
            swell_comment = "Swell orta."
            suitability -= 3
            risk += 5
        else:
            swell_comment = "Swell yüksek — dikkat."
            suitability -= 10
            risk += 12
    else:
        swell_comment = "Swell verisi sınırlı."

    if rain_probability_pct is not None:
        if rain_probability_pct >= 60:
            suitability -= 12
            risk += 8
        elif rain_probability_pct >= 30:
            suitability -= 5

    if moon_illumination_pct is not None:
        if moon_illumination_pct <= 30:
            moon_comment = "Ay ışığı düşük — gece balıkçılığı için olumlu olabilir."
            suitability += 5
        elif moon_illumination_pct >= 80:
            moon_comment = "Ay ışığı yüksek — balık aktivitesi değişebilir."
            suitability -= 3
        else:
            moon_comment = "Ay evresi orta düzeyde."
    else:
        moon_comment = "Ay verisi mevcut değil."

    suitability_score = _clamp_score(suitability)
    risk_score = _clamp_score(risk)
    best_hours = "Sabah erken veya akşamüstü genelde daha sakin olabilir."
    if suitability_score >= 70:
        advice = "Koşullar genel olarak olumlu görünüyor; yine de yerel uyarıları kontrol edin."
    elif suitability_score >= 45:
        advice = "Koşullar karışık — planınızı esnek tutun."
    else:
        advice = "Koşullar zorlayıcı olabilir; güvenliği önceliklendirin."

    return FishingScoreModel(
        suitability_score=suitability_score,
        risk_score=risk_score,
        best_hours_tr=best_hours,
        wind_comment_tr=wind_comment,
        wave_comment_tr=wave_comment,
        swell_comment_tr=swell_comment,
        moon_comment_tr=moon_comment,
        general_advice_tr=advice,
        confidence=min(1.0, max(0.0, confidence)),
    )
