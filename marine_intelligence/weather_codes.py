"""Open-Meteo WMO weather_code → Türkçe kısa etiket."""

from __future__ import annotations

from typing import Optional

_WMO_LABELS_TR: dict[int, str] = {
    0: "Açık",
    1: "Az bulutlu",
    2: "Parçalı bulutlu",
    3: "Kapalı",
    45: "Sis",
    48: "Sis",
    51: "Çisenti",
    53: "Çisenti",
    55: "Çisenti",
    56: "Donan çisenti",
    57: "Donan çisenti",
    61: "Yağmur",
    63: "Yağmur",
    65: "Kuvvetli yağmur",
    66: "Donan yağmur",
    67: "Donan yağmur",
    71: "Kar",
    73: "Kar",
    75: "Kuvvetli kar",
    77: "Kar taneleri",
    80: "Sağanak",
    81: "Sağanak",
    82: "Kuvvetli sağanak",
    85: "Kar sağanağı",
    86: "Kuvvetli kar sağanağı",
    95: "Gök gürültülü",
    96: "Gök gürültülü",
    99: "Gök gürültülü",
}


def weather_label_tr(code: Optional[int]) -> Optional[str]:
    if code is None:
        return None
    return _WMO_LABELS_TR.get(int(code), "Değişken")
