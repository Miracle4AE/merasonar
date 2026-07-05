from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from marine_intelligence.providers.base import MarineProviderSnapshot

FetchJsonFn = Callable[[str, float], Dict[str, Any]]

_FORECAST_PARAMS = [
    "temperature_2m",
    "apparent_temperature",
    "precipitation_probability",
    "precipitation",
    "relative_humidity_2m",
    "surface_pressure",
    "wind_speed_10m",
    "wind_direction_10m",
    "wind_gusts_10m",
]

_MARINE_PARAMS = [
    "wave_height",
    "wave_direction",
    "wave_period",
    "swell_wave_height",
    "swell_wave_direction",
    "swell_wave_period",
    "sea_surface_temperature",
    "ocean_current_velocity",
    "ocean_current_direction",
]

_FORECAST_HOURLY_PARAMS = list(_FORECAST_PARAMS)
_MARINE_HOURLY_PARAMS = list(_MARINE_PARAMS)
_HOURLY_FORECAST_HOURS = 24
_DAILY_FORECAST_DAYS = 7

_DAILY_FORECAST_PARAMS = [
    "temperature_2m_max",
    "temperature_2m_min",
    "precipitation_probability_max",
    "weather_code",
    "wind_speed_10m_max",
    "wind_gusts_10m_max",
    "wind_direction_10m_dominant",
]

_CARDINALS_TR = (
    "K",
    "KKD",
    "KD",
    "DKD",
    "D",
    "DGD",
    "GD",
    "GGD",
    "G",
    "GGB",
    "GB",
    "BGB",
    "B",
    "BBK",
    "BK",
    "KBK",
)


def wind_direction_text_tr(deg: Optional[float]) -> Optional[str]:
    if deg is None:
        return None
    idx = int((float(deg) + 11.25) / 22.5) % 16
    return _CARDINALS_TR[idx]


def _first_current(values: Any) -> Optional[float]:
    if values is None:
        return None
    if isinstance(values, (int, float)):
        return float(values)
    if isinstance(values, list) and values:
        for item in values:
            if item is not None:
                try:
                    return float(item)
                except (TypeError, ValueError):
                    continue
    return None


def parse_open_meteo_forecast(payload: Dict[str, Any]) -> Dict[str, Optional[float]]:
    current = payload.get("current") or {}
    return {
        "temperature_c": _first_current(current.get("temperature_2m")),
        "apparent_temperature_c": _first_current(current.get("apparent_temperature")),
        "precipitation_probability_pct": _first_current(current.get("precipitation_probability")),
        "precipitation_mm": _first_current(current.get("precipitation")),
        "relative_humidity_pct": _first_current(current.get("relative_humidity_2m")),
        "surface_pressure_hpa": _first_current(current.get("surface_pressure")),
        "wind_speed_kmh": _first_current(current.get("wind_speed_10m")),
        "wind_direction_deg": _first_current(current.get("wind_direction_10m")),
        "wind_gust_kmh": _first_current(current.get("wind_gusts_10m")),
    }


def _first_hourly(values: Any, index: int) -> Optional[float]:
    if values is None or not isinstance(values, list):
        return None
    if index >= len(values):
        return None
    item = values[index]
    if item is None:
        return None
    try:
        return float(item)
    except (TypeError, ValueError):
        return None


def parse_open_meteo_hourly_series(
    forecast_payload: Dict[str, Any],
    marine_payload: Dict[str, Any],
    *,
    max_hours: int = _HOURLY_FORECAST_HOURS,
) -> List[Dict[str, Optional[float]]]:
    """Hourly blok varsa ilk N saati parse eder — yoksa boş liste."""
    forecast_hourly = forecast_payload.get("hourly") or {}
    marine_hourly = marine_payload.get("hourly") or {}
    times = forecast_hourly.get("time") or marine_hourly.get("time")
    if not isinstance(times, list) or not times:
        return []

    series: List[Dict[str, Optional[float]]] = []
    for idx, raw_time in enumerate(times[:max_hours]):
        time_utc = str(raw_time)
        time_label = time_utc
        if "T" in time_label:
            time_label = time_label.split("T", 1)[1][:5]
        series.append(
            {
                "time": time_label,
                "time_utc": time_utc,
                "wind_speed_kmh": _first_hourly(forecast_hourly.get("wind_speed_10m"), idx),
                "gust_kmh": _first_hourly(forecast_hourly.get("wind_gusts_10m"), idx),
                "wave_height_m": _first_hourly(marine_hourly.get("wave_height"), idx),
                "precipitation_probability_pct": _first_hourly(
                    forecast_hourly.get("precipitation_probability"), idx
                ),
                "surface_pressure_hpa": _first_hourly(
                    forecast_hourly.get("surface_pressure"), idx
                ),
                "temperature_c": _first_hourly(forecast_hourly.get("temperature_2m"), idx),
                "relative_humidity_pct": _first_hourly(
                    forecast_hourly.get("relative_humidity_2m"), idx
                ),
                "swell_height_m": _first_hourly(marine_hourly.get("swell_wave_height"), idx),
                "sea_surface_temperature_c": _first_hourly(
                    marine_hourly.get("sea_surface_temperature"), idx
                ),
            }
        )
    return series


def parse_open_meteo_daily_series(
    forecast_payload: Dict[str, Any],
    *,
    max_days: int = _DAILY_FORECAST_DAYS,
) -> List[Dict[str, Optional[float]]]:
    """7 günlük daily forecast — Open-Meteo daily bloğu."""
    daily = forecast_payload.get("daily") or {}
    times = daily.get("time")
    if not isinstance(times, list) or not times:
        return []

    series: List[Dict[str, Optional[float]]] = []
    for idx, raw_date in enumerate(times[:max_days]):
        date_label = str(raw_date)
        if "T" in date_label:
            date_label = date_label.split("T", 1)[0]
        temp_max = _first_hourly(daily.get("temperature_2m_max"), idx)
        temp_min = _first_hourly(daily.get("temperature_2m_min"), idx)
        precip = _first_hourly(daily.get("precipitation_probability_max"), idx)
        wind_max = _first_hourly(daily.get("wind_speed_10m_max"), idx)
        gust_max = _first_hourly(daily.get("wind_gusts_10m_max"), idx)
        wind_dir = _first_hourly(daily.get("wind_direction_10m_dominant"), idx)
        weather_code = daily.get("weather_code")
        code_val: Optional[int] = None
        if isinstance(weather_code, list) and idx < len(weather_code):
            try:
                code_val = int(weather_code[idx]) if weather_code[idx] is not None else None
            except (TypeError, ValueError):
                code_val = None
        series.append(
            {
                "date": date_label,
                "temp_max_c": temp_max,
                "temp_min_c": temp_min,
                "precipitation_probability_pct": precip,
                "wind_max_kmh": wind_max,
                "wind_gust_max_kmh": gust_max,
                "wind_direction_deg": wind_dir,
                "weather_code": code_val,
            }
        )
    return series


def enrich_daily_forecast_days(days: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Gün etiketi ve hava özeti ekler — sahte skor üretmez."""
    from datetime import date

    from marine_intelligence.weather_codes import weather_label_tr

    _day_names = ("Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz")
    today = date.today()
    enriched: List[Dict[str, Any]] = []
    for raw in days:
        item = dict(raw)
        date_str = str(item.get("date") or "").split("T", 1)[0]
        try:
            day_date = date.fromisoformat(date_str)
            delta = (day_date - today).days
            if delta == 0:
                item["day_label"] = "Bugün"
            elif delta == 1:
                item["day_label"] = "Yarın"
            else:
                item["day_label"] = _day_names[day_date.weekday()]
        except ValueError:
            item["day_label"] = date_str[-5:] if len(date_str) >= 5 else date_str
        code = item.get("weather_code")
        if code is not None:
            item["weather_label_tr"] = weather_label_tr(int(code))
        wind_deg = item.get("wind_direction_deg")
        if wind_deg is not None:
            item["wind_direction_text"] = wind_direction_text_tr(float(wind_deg))
        enriched.append(item)
    return enriched


def parse_open_meteo_marine(payload: Dict[str, Any]) -> Dict[str, Optional[float]]:
    current = payload.get("current") or {}
    return {
        "wave_height_m": _first_current(current.get("wave_height")),
        "wave_direction_deg": _first_current(current.get("wave_direction")),
        "wave_period_s": _first_current(current.get("wave_period")),
        "swell_height_m": _first_current(current.get("swell_wave_height")),
        "swell_direction_deg": _first_current(current.get("swell_wave_direction")),
        "swell_period_s": _first_current(current.get("swell_wave_period")),
        "sea_surface_temperature_c": _first_current(current.get("sea_surface_temperature")),
        "ocean_current_velocity_mps": _first_current(current.get("ocean_current_velocity")),
        "ocean_current_direction_deg": _first_current(current.get("ocean_current_direction")),
    }


class OpenMeteoProvider:
    provider_name = "open_meteo"

    def __init__(
        self,
        *,
        enabled: bool = True,
        timeout_seconds: float = 10.0,
        fetch_json: Optional[FetchJsonFn] = None,
    ) -> None:
        self._enabled = enabled
        self._timeout = timeout_seconds
        self._fetch_json = fetch_json or self._default_fetch_json

    def fetch(self, lat: float, lon: float) -> MarineProviderSnapshot:
        if not self._enabled:
            return MarineProviderSnapshot(
                provider_name=self.provider_name,
                success=False,
                error="disabled",
            )
        try:
            forecast = self._fetch_json(
                self._build_forecast_url(lat, lon),
                self._timeout,
            )
            marine = self._fetch_json(
                self._build_marine_url(lat, lon),
                self._timeout,
            )
            weather_parsed = parse_open_meteo_forecast(forecast)
            marine_parsed = parse_open_meteo_marine(marine)
            wind = {
                "speed_kmh": weather_parsed.pop("wind_speed_kmh", None),
                "direction_deg": weather_parsed.pop("wind_direction_deg", None),
                "gust_kmh": weather_parsed.pop("wind_gust_kmh", None),
            }
            hourly = parse_open_meteo_hourly_series(forecast, marine)
            daily = parse_open_meteo_daily_series(forecast)
            return MarineProviderSnapshot(
                provider_name=self.provider_name,
                success=True,
                weather=weather_parsed,
                wind=wind,
                marine=marine_parsed,
                hourly_series=hourly,
                daily_series=daily,
            )
        except Exception as exc:  # noqa: BLE001 — provider failure must not crash service
            return MarineProviderSnapshot(
                provider_name=self.provider_name,
                success=False,
                error=str(exc),
            )

    @staticmethod
    def _build_forecast_url(lat: float, lon: float) -> str:
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": ",".join(_FORECAST_PARAMS),
            "hourly": ",".join(_FORECAST_HOURLY_PARAMS),
            "daily": ",".join(_DAILY_FORECAST_PARAMS),
            "forecast_hours": str(_HOURLY_FORECAST_HOURS),
            "forecast_days": str(_DAILY_FORECAST_DAYS),
            "timezone": "UTC",
        }
        return f"https://api.open-meteo.com/v1/forecast?{urlencode(params)}"

    @staticmethod
    def _build_marine_url(lat: float, lon: float) -> str:
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": ",".join(_MARINE_PARAMS),
            "hourly": ",".join(_MARINE_HOURLY_PARAMS),
            "forecast_hours": str(_HOURLY_FORECAST_HOURS),
            "timezone": "UTC",
        }
        return f"https://marine-api.open-meteo.com/v1/marine?{urlencode(params)}"

    @staticmethod
    def _default_fetch_json(url: str, timeout: float) -> Dict[str, Any]:
        req = Request(url, headers={"User-Agent": "MeraSonar-MarineIntelligence/1.0"})
        with urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
