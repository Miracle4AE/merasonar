from __future__ import annotations

import math
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, Optional

from marine_intelligence.providers.base import MarineProviderSnapshot

_MOON_PHASES_TR = (
    "Yeni Ay",
    "Ilk Hilal",
    "Ilkbahar Dorugu",
    "Son Hilal",
    "Dolunay",
    "Son Hilal",
    "Sonbahar Dorugu",
    "Ilk Hilal",
)


def _julian_day(dt: datetime) -> float:
    y = dt.year
    m = dt.month
    d = dt.day + (dt.hour + dt.minute / 60.0 + dt.second / 3600.0) / 24.0
    if m <= 2:
        y -= 1
        m += 12
    a = int(y / 100)
    b = 2 - a + int(a / 4)
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + b - 1524.5


def _sun_times_utc(lat: float, lon: float, day: date) -> tuple[datetime, datetime]:
    """Basit güneş doğuş/batış — NOAA yaklaşık formül."""
    jd = _julian_day(datetime(day.year, day.month, day.day, 12, tzinfo=timezone.utc))
    n = jd - 2451545.0 + 0.0008
    mean_anomaly = (357.5291 + 0.98560028 * n) % 360
    center = 1.9148 * math.sin(math.radians(mean_anomaly)) + 0.02 * math.sin(
        math.radians(2 * mean_anomaly)
    )
    ecliptic_lon = (mean_anomaly + center + 180 + 102.9372) % 360
    decl = math.degrees(
        math.asin(math.sin(math.radians(23.44)) * math.sin(math.radians(ecliptic_lon)))
    )
    hour_angle = math.degrees(
        math.acos(
            max(
                -1.0,
                min(
                    1.0,
                    (math.sin(math.radians(-0.833)) - math.sin(math.radians(lat)) * math.sin(math.radians(decl)))
                    / (math.cos(math.radians(lat)) * math.cos(math.radians(decl))),
                ),
            )
        )
    )
    solar_noon = 720 - 4 * lon - equation_of_time(n)
    sunrise_min = solar_noon - hour_angle * 4
    sunset_min = solar_noon + hour_angle * 4
    base = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
    sunrise = base + timedelta(minutes=sunrise_min)
    sunset = base + timedelta(minutes=sunset_min)
    return sunrise, sunset


def equation_of_time(n: float) -> float:
    mean_anomaly = math.radians(357.5291 + 0.98560028 * n)
    ecliptic_lon = math.radians(
        (mean_anomaly * 180 / math.pi + 1.9148 * math.sin(mean_anomaly) + 102.9372) % 360
    )
    return 4 * math.degrees(
        math.sin(2 * ecliptic_lon)
        - 2 * 0.0167 * math.sin(mean_anomaly)
        + 4 * 0.0167 * math.sin(mean_anomaly) * math.cos(2 * ecliptic_lon)
        - 0.5 * 0.0167**2 * math.sin(4 * ecliptic_lon)
        - 1.25 * 0.0167**2 * math.sin(2 * mean_anomaly)
    )


def moon_phase_info(at_time: datetime) -> tuple[str, float]:
    """Deterministik ay evresi ve aydınlanma yüzdesi."""
    known_new_moon = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
    synodic = 29.530588853
    days = (at_time - known_new_moon).total_seconds() / 86400.0
    age = days % synodic
    phase_index = int((age / synodic) * 8) % 8
    illumination = round(50 * (1 - math.cos(2 * math.pi * age / synodic)), 1)
    return _MOON_PHASES_TR[phase_index], illumination


def moon_altitude_deg(lat: float, lon: float, at_time: datetime) -> float:
    jd = _julian_day(at_time)
    days = jd - 2451545.0
    moon_lon = (218.316 + 13.176396 * days) % 360
    moon_lat = 5.128 * math.sin(math.radians(days * 0.985))
    ra = math.radians(moon_lon)
    dec = math.radians(moon_lat)
    lst = (100.46 + 0.985647 * days + lon + at_time.hour * 15 + at_time.minute / 4) % 360
    ha = math.radians(lst - moon_lon)
    lat_r = math.radians(lat)
    alt = math.degrees(
        math.asin(
            max(
                -1.0,
                min(1.0, math.sin(lat_r) * math.sin(dec) + math.cos(lat_r) * math.cos(dec) * math.cos(ha)),
            )
        )
    )
    return round(alt, 2)


class AstronomyLocalProvider:
    provider_name = "astronomy_local"

    def __init__(
        self,
        *,
        enabled: bool = True,
        reference_time: Optional[datetime] = None,
    ) -> None:
        self._enabled = enabled
        self._reference_time = reference_time

    def fetch(self, lat: float, lon: float) -> MarineProviderSnapshot:
        if not self._enabled:
            return MarineProviderSnapshot(
                provider_name=self.provider_name,
                success=False,
                error="disabled",
            )
        at_time = self._reference_time or datetime.now(timezone.utc)
        sunrise, sunset = _sun_times_utc(lat, lon, at_time.date())
        phase, illumination = moon_phase_info(at_time)
        astronomy: Dict[str, Any] = {
            "sunrise": sunrise.isoformat(),
            "sunset": sunset.isoformat(),
            "moon_phase": phase,
            "moon_illumination_pct": illumination,
            "moonrise": None,
            "moonset": None,
            "moon_altitude_deg": moon_altitude_deg(lat, lon, at_time),
        }
        return MarineProviderSnapshot(
            provider_name=self.provider_name,
            success=True,
            astronomy=astronomy,
        )
