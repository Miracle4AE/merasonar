from __future__ import annotations

import time
from collections import Counter
from datetime import datetime, timezone
from math import cos, isfinite, pi, sin
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple

import requests
from requests.adapters import HTTPAdapter
from requests.exceptions import RequestException, Timeout
from urllib3.util.retry import Retry


class MarineDataClientError(RuntimeError):
    """Raised when marine data enrichment cannot proceed due to invalid inputs."""


class MarineDataClient:
    """
    Lightweight client for marine/environmental enrichment around hotspot coordinates.

    Integrations:
    - Open-Meteo Marine API for sea state.
    - OpenTopoData GEBCO dataset for bathymetric depth.
    - OBIS occurrence API for likely fish species.
    """

    MARINE_API_URL = "https://marine-api.open-meteo.com/v1/marine"
    BATHYMETRY_API_URL = "https://api.opentopodata.org/v1/gebco2020"
    OBIS_API_URL = "https://api.obis.org/v3/occurrence"
    GBIF_OCCURRENCE_URL = "https://api.gbif.org/v1/occurrence/search"
    DIDIM_MAVISEHIR_LAT = 37.3720
    DIDIM_MAVISEHIR_LON = 27.2677

    _FISH_CLASS_TOKENS = frozenset(
        {"Teleostei", "Chondrichthyes", "Myxini", "Elasmobranchii", "Actinopterygii"}
    )
    _FORBIDDEN_REGIONAL_PHRASES = frozenset(
        ("fish are here", "guaranteed", "definitely"),
    )

    def __init__(
        self,
        timeout_seconds: float = 8.0,
        max_retries: int = 3,
        backoff_factor: float = 0.5,
        user_agent: str = "marine-data-client/1.0",
    ) -> None:
        if timeout_seconds <= 0.0:
            raise ValueError("timeout_seconds must be > 0.")
        if max_retries < 0:
            raise ValueError("max_retries must be >= 0.")
        if backoff_factor < 0.0:
            raise ValueError("backoff_factor must be >= 0.")

        self.timeout_seconds = float(timeout_seconds)
        self.max_retries = int(max_retries)
        self.backoff_factor = float(backoff_factor)

        self.session = requests.Session()
        self.session.headers.update({"User-Agent": user_agent, "Accept": "application/json"})
        retry = Retry(
            total=max_retries,
            connect=max_retries,
            read=max_retries,
            status=max_retries,
            backoff_factor=backoff_factor,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset({"GET"}),
            raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry)
        self.session.mount("https://", adapter)
        self.session.mount("http://", adapter)

    def get_sea_state(self, lat: float, lon: float) -> Dict[str, Any]:
        """
        Fetch wave, current, and surface water temperature near a coordinate.

        Returns API-backed payload when possible and falls back to a realistic
        Didim Mavisehir marine simulation for missing fields.
        """
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": "wave_height,ocean_current_velocity,sea_surface_temperature",
            "hourly": "wave_height,ocean_current_velocity,sea_surface_temperature",
            "timezone": "UTC",
            "forecast_days": 1,
        }
        simulated = self._simulate_didim_mavisehir_sea_state(lat=lat, lon=lon)

        try:
            payload = self._request_json(self.MARINE_API_URL, params=params)
            current = payload.get("current", {}) if isinstance(payload, Mapping) else {}
            hourly = payload.get("hourly", {}) if isinstance(payload, Mapping) else {}

            wave_height = self._as_float(current.get("wave_height"))
            current_velocity = self._as_float(current.get("ocean_current_velocity"))
            water_temp = self._as_float(current.get("sea_surface_temperature"))

            # Fallback to first hourly value if current block is missing.
            if wave_height is None:
                wave_height = self._first_hourly_value(hourly, "wave_height")
            if current_velocity is None:
                current_velocity = self._first_hourly_value(hourly, "ocean_current_velocity")
            if water_temp is None:
                water_temp = self._first_hourly_value(hourly, "sea_surface_temperature")

            current_speed_knots = current_velocity * 1.94384 if current_velocity is not None else None
            source = "open_meteo_marine+didim_model"
            return {
                "wave_height_m": self._rounded_or_simulated(wave_height, simulated["wave_height_m"], 2),
                "ocean_current_velocity_mps": self._rounded_or_simulated(
                    current_velocity,
                    simulated["ocean_current_velocity_mps"],
                    3,
                ),
                "water_temperature_c": self._rounded_or_simulated(
                    water_temp,
                    simulated["water_temperature_c"],
                    1,
                ),
                "wind_speed_knots": simulated["wind_speed_knots"],
                "wind_direction_deg": simulated["wind_direction_deg"],
                "current_speed_knots": self._rounded_or_simulated(
                    current_speed_knots,
                    simulated["current_speed_knots"],
                    2,
                ),
                "current_direction_deg": simulated["current_direction_deg"],
                "pressure_hpa": simulated["pressure_hpa"],
                "source": source,
                "fallback": False,
                "simulated_components": [
                    "wind_speed_knots",
                    "wind_direction_deg",
                    "current_direction_deg",
                    "pressure_hpa",
                ],
            }
        except Exception as exc:  # pragma: no cover - defensive path
            fallback = dict(simulated)
            fallback["source"] = "didim_mavisehir_simulation"
            fallback["fallback"] = True
            fallback["reason"] = "sea_state_unavailable"
            fallback["error"] = str(exc)
            return fallback

    def get_bathymetry_depth(self, lat: float, lon: float) -> Dict[str, Any]:
        """
        Fetch GEBCO depth/elevation for coordinate and normalize to depth meters.

        Convention:
        - Positive `depth_m` means meters below sea level.
        """
        params = {"locations": f"{lat:.8f},{lon:.8f}"}
        default = self._fallback_depth(reason="bathymetry_unavailable")

        try:
            payload = self._request_json(self.BATHYMETRY_API_URL, params=params)
            if not isinstance(payload, Mapping):
                return default

            results = payload.get("results", [])
            if not isinstance(results, list) or not results:
                return default

            first = results[0] if isinstance(results[0], Mapping) else {}
            elevation = self._as_float(first.get("elevation"))
            if elevation is None:
                return default

            depth_m = max(0.0, -elevation) if elevation < 0.0 else 0.0
            return {
                "depth_m": float(depth_m),
                "raw_elevation_m": float(elevation),
                "dataset": str(first.get("dataset", "gebco2020")),
                "source": "opentopodata_gebco2020",
                "fallback": False,
            }
        except Exception as exc:  # pragma: no cover - defensive path
            fallback = dict(default)
            fallback["error"] = str(exc)
            return fallback

    def get_marine_biodiversity(self, lat: float, lon: float, radius_km: float = 5.0) -> Dict[str, Any]:
        """
        Fetch likely fish species near location from OBIS occurrences.

        Uses a radius-derived WKT polygon and returns top 5 species by frequency.
        """
        if radius_km <= 0.0:
            raise ValueError("radius_km must be > 0.")

        polygon_wkt = self._square_wkt(lat=lat, lon=lon, radius_km=radius_km)
        params = {
            "geometry": polygon_wkt,
            "size": 500,
            "start": 0,
            "class": "Teleostei",
        }
        default = self._fallback_species(reason="biodiversity_unavailable")

        try:
            payload = self._request_json(self.OBIS_API_URL, params=params)
            if not isinstance(payload, Mapping):
                return default

            raw_results = payload.get("results", [])
            if not isinstance(raw_results, list):
                return default

            fish_classes = {"Teleostei", "Chondrichthyes", "Myxini", "Elasmobranchii", "Actinopterygii"}
            species_counter: Counter[str] = Counter()
            for record in raw_results:
                if not isinstance(record, Mapping):
                    continue
                class_name = str(record.get("class", "")).strip()
                if class_name and class_name not in fish_classes:
                    continue
                name = str(record.get("species") or record.get("scientificName") or "").strip()
                if name:
                    species_counter[name] += 1

            top_species = [
                {"species": species, "occurrence_count": int(count)}
                for species, count in species_counter.most_common(5)
            ]

            return {
                "radius_km": float(radius_km),
                "query_geometry_wkt": polygon_wkt,
                "top_species": top_species,
                "total_records_considered": int(sum(species_counter.values())),
                "source": "obis_occurrence",
                "fallback": False,
            }
        except Exception as exc:  # pragma: no cover - defensive path
            fallback = dict(default)
            fallback["error"] = str(exc)
            return fallback

    def enrich_hotspot_data(self, hotspot_dict: Mapping[str, Any]) -> Dict[str, Any]:
        """
        Enrich one hotspot dictionary with sea state, depth verification, and likely species.

        Required input:
        - hotspot_dict["geo_coordinate"] = {"lat": ..., "lon": ...}
        """
        lat, lon = self._extract_hotspot_coordinates(hotspot_dict)

        sea_state = self.get_sea_state(lat=lat, lon=lon)
        depth = self.get_bathymetry_depth(lat=lat, lon=lon)
        biodiversity = self.get_marine_biodiversity(lat=lat, lon=lon, radius_km=5.0)

        enriched = dict(hotspot_dict)
        enriched["sea_state"] = sea_state
        enriched["confirmed_depth"] = depth
        enriched["likely_species"] = biodiversity
        return enriched

    def get_regional_species_bundle_for_bounds(
        self,
        top_left_lat: float,
        top_left_lon: float,
        bottom_right_lat: float,
        bottom_right_lon: float,
    ) -> Tuple[Optional[str], List[str]]:
        """
        OBIS-first species names plus optional explanatory text for the chart rectangle.

        Second element lists up to 12 occurrence names ordered by frequency-ish merge
        (used for hotspot-level structure matching).

        FishBase must not substitute OBIS/GBIF geographic evidence (not invoked here).
        """
        empty: Tuple[Optional[str], List[str]] = (None, [])
        if not all(isfinite(v) for v in (top_left_lat, top_left_lon, bottom_right_lat, bottom_right_lon)):
            return empty
        if not (-90.0 <= top_left_lat <= 90.0 and -90.0 <= bottom_right_lat <= 90.0):
            return empty
        if not (-180.0 <= top_left_lon <= 180.0 and -180.0 <= bottom_right_lon <= 180.0):
            return empty
        min_lat = min(top_left_lat, bottom_right_lat)
        max_lat = max(top_left_lat, bottom_right_lat)
        min_lon = min(top_left_lon, bottom_right_lon)
        max_lon = max(top_left_lon, bottom_right_lon)
        if abs(max_lat - min_lat) < 1e-7 or abs(max_lon - min_lon) < 1e-7:
            return empty
        wkt = self._bounds_to_polygon_wkt(min_lat=min_lat, max_lat=max_lat, min_lon=min_lon, max_lon=max_lon)
        ordered: List[str] = []
        seen: Set[str] = set()

        obis_names = self._species_names_obis_polygon(wkt)
        for name in obis_names:
            if name not in seen:
                seen.add(name)
                ordered.append(name)
        supplemented_gbif = False
        if len(ordered) < 2:
            supplemented_gbif = True
            for name in self._species_names_gbif_polygon(wkt):
                if name not in seen:
                    seen.add(name)
                    ordered.append(name)
                if len(ordered) >= 12:
                    break

        names_for_match = ordered[:12]
        if not names_for_match:
            return empty

        trimmed_text = names_for_match[:6]
        text = self._format_regional_context(trimmed_text, supplemented_gbif=supplemented_gbif)
        safe_text = text if text and self._assert_safe_regional_text(text) else None
        return (safe_text, names_for_match)

    def get_regional_species_context_for_bounds(
        self,
        top_left_lat: float,
        top_left_lon: float,
        bottom_right_lat: float,
        bottom_right_lon: float,
    ) -> Optional[str]:
        """
        Produce cautious English text summarizing OBIS-first (then GBIF) occurrence names
        for the chart bounding box. Not proof of presence at a specific spot.
        """
        ctx, _names = self.get_regional_species_bundle_for_bounds(
            top_left_lat,
            top_left_lon,
            bottom_right_lat,
            bottom_right_lon,
        )
        return ctx

    def _try_request_json(
        self, url: str, params: Mapping[str, Any], *, short_timeout: Optional[float] = None
    ) -> Optional[Dict[str, Any]]:
        t = float(short_timeout) if short_timeout is not None else self.timeout_seconds
        try:
            response = self.session.get(url, params=params, timeout=t)
            if response.status_code >= 400:
                return None
            data = response.json()
            return data if isinstance(data, dict) else None
        except Exception:
            return None

    @staticmethod
    def _bounds_to_polygon_wkt(
        *,
        min_lat: float,
        max_lat: float,
        min_lon: float,
        max_lon: float,
    ) -> str:
        return (
            "POLYGON(("
            f"{min_lon:.6f} {min_lat:.6f},"
            f"{max_lon:.6f} {min_lat:.6f},"
            f"{max_lon:.6f} {max_lat:.6f},"
            f"{min_lon:.6f} {max_lat:.6f},"
            f"{min_lon:.6f} {min_lat:.6f}"
            "))"
        )

    def _species_names_obis_polygon(self, polygon_wkt: str) -> List[str]:
        params = {
            "geometry": polygon_wkt,
            "size": 500,
            "start": 0,
            "class": "Teleostei",
        }
        payload = self._try_request_json(self.OBIS_API_URL, params)
        if not isinstance(payload, Mapping):
            return []

        raw_results = payload.get("results", [])
        if not isinstance(raw_results, list):
            return []

        species_counter: Counter[str] = Counter()
        for record in raw_results:
            if not isinstance(record, Mapping):
                continue
            cls = str(record.get("class") or "").strip()
            if cls and cls not in MarineDataClient._FISH_CLASS_TOKENS:
                continue
            name = str(record.get("species") or record.get("scientificName") or "").strip()
            if name:
                species_counter[name] += 1

        return [species for species, _ in species_counter.most_common(12)]

    def _species_names_gbif_polygon(self, polygon_wkt: str) -> List[str]:
        params = {
            "geometry": polygon_wkt,
            "limit": 300,
            "hasCoordinate": "true",
        }
        payload = self._try_request_json(self.GBIF_OCCURRENCE_URL, params, short_timeout=min(12.0, self.timeout_seconds + 4.0))
        if not isinstance(payload, Mapping):
            return []

        raw = payload.get("results", [])
        if not isinstance(raw, list):
            return []

        species_counter: Counter[str] = Counter()
        for record in raw:
            if not isinstance(record, Mapping):
                continue
            gbif_class = str(record.get("class") or "").strip()
            if gbif_class and gbif_class not in MarineDataClient._FISH_CLASS_TOKENS:
                continue
            name = str(record.get("species") or record.get("scientificName") or "").strip()
            if not name or len(name) < 3:
                continue
            species_counter[name] += 1

        return [species for species, _ in species_counter.most_common(12)]

    def _format_regional_context(self, names: Sequence[str], *, supplemented_gbif: bool) -> str:
        if not names:
            return ""
        if len(names) == 1:
            body = names[0]
        elif len(names) == 2:
            body = f"{names[0]} and {names[1]}"
        else:
            body = ", ".join(names[:-1]) + ", and " + names[-1]
        source_clause = (
            "Nearby occurrence data includes OBIS-derived listings for this chart polygon."
            if not supplemented_gbif
            else "Nearby occurrence data includes OBIS listings where present and supplementary GBIF occurrence records where OBIS coverage is sparse."
        )
        return (
            f"Regional records suggest species such as {body} commonly appear in public occurrence databases for this general area. "
            f"{source_clause} "
            "These are not proof of species at any exact fishing location."
        )

    def _assert_safe_regional_text(self, text: str) -> bool:
        stripped = text.strip()
        if not stripped:
            return False
        low = stripped.lower()
        return not any(bad in low for bad in MarineDataClient._FORBIDDEN_REGIONAL_PHRASES)

    def _request_json(self, url: str, params: Mapping[str, Any]) -> Dict[str, Any]:
        """
        Execute resilient GET request with retries and timeout handling.
        """
        last_error: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            try:
                response = self.session.get(url, params=params, timeout=self.timeout_seconds)
                response.raise_for_status()
                data = response.json()
                if not isinstance(data, dict):
                    raise MarineDataClientError("Unexpected non-dict JSON response.")
                return data
            except (Timeout, RequestException, ValueError) as exc:
                last_error = exc
                if attempt >= self.max_retries:
                    break
                sleep_s = self.backoff_factor * (2 ** attempt)
                if sleep_s > 0.0:
                    time.sleep(sleep_s)

        raise MarineDataClientError(f"Request failed after retries: {last_error}")

    @staticmethod
    def _extract_hotspot_coordinates(hotspot_dict: Mapping[str, Any]) -> Tuple[float, float]:
        if not isinstance(hotspot_dict, Mapping):
            raise ValueError("hotspot_dict must be a mapping.")

        geo = hotspot_dict.get("geo_coordinate")
        if isinstance(geo, Mapping) and "lat" in geo and "lon" in geo:
            return float(geo["lat"]), float(geo["lon"])

        if "lat" in hotspot_dict and "lon" in hotspot_dict:
            return float(hotspot_dict["lat"]), float(hotspot_dict["lon"])

        raise ValueError("Hotspot dictionary must contain geo coordinates under 'geo_coordinate' or 'lat/lon'.")

    @staticmethod
    def _square_wkt(lat: float, lon: float, radius_km: float) -> str:
        lat_deg = radius_km / 111.32
        lon_scale = max(0.01, cos(lat * pi / 180.0))
        lon_deg = radius_km / (111.32 * lon_scale)

        min_lat = lat - lat_deg
        max_lat = lat + lat_deg
        min_lon = lon - lon_deg
        max_lon = lon + lon_deg

        return (
            f"POLYGON(({min_lon:.6f} {min_lat:.6f},"
            f"{min_lon:.6f} {max_lat:.6f},"
            f"{max_lon:.6f} {max_lat:.6f},"
            f"{max_lon:.6f} {min_lat:.6f},"
            f"{min_lon:.6f} {min_lat:.6f}))"
        )

    @staticmethod
    def _first_hourly_value(hourly: Mapping[str, Any], key: str) -> Optional[float]:
        values = hourly.get(key) if isinstance(hourly, Mapping) else None
        if isinstance(values, list) and values:
            return MarineDataClient._as_float(values[0])
        return None

    @staticmethod
    def _as_float(value: Any) -> Optional[float]:
        try:
            if value is None:
                return None
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _fallback_sea_state(reason: str) -> Dict[str, Any]:
        return {
            "wave_height_m": None,
            "ocean_current_velocity_mps": None,
            "water_temperature_c": None,
            "wind_speed_knots": None,
            "wind_direction_deg": None,
            "current_speed_knots": None,
            "current_direction_deg": None,
            "pressure_hpa": None,
            "source": "fallback",
            "fallback": True,
            "reason": reason,
        }

    @classmethod
    def _simulate_didim_mavisehir_sea_state(cls, lat: float, lon: float) -> Dict[str, Any]:
        now_utc = datetime.now(timezone.utc)
        hour = now_utc.hour + (now_utc.minute / 60.0)
        day_of_year = now_utc.timetuple().tm_yday

        distance_factor = min(
            1.0,
            (
                abs(lat - cls.DIDIM_MAVISEHIR_LAT) * 111.0
                + abs(lon - cls.DIDIM_MAVISEHIR_LON) * 88.0
            )
            / 30.0,
        )
        coastal_damping = max(0.82, 1.0 - (distance_factor * 0.10))

        meltemi_strength = max(0.0, sin(((day_of_year - 140) / 183.0) * pi))
        diurnal_breeze = sin(((hour - 13.0) / 24.0) * 2.0 * pi)
        synoptic_pulse = sin(((day_of_year + (hour / 24.0)) / 9.5) * 2.0 * pi)

        wind_speed_knots = (9.5 + (8.0 * meltemi_strength) + (2.8 * diurnal_breeze) + (1.7 * synoptic_pulse))
        wind_speed_knots = min(24.0, max(5.0, wind_speed_knots * coastal_damping))

        base_wind_direction = 305.0 - (12.0 * meltemi_strength)
        wind_direction_deg = (base_wind_direction + (8.0 * synoptic_pulse) + (4.0 * diurnal_breeze)) % 360.0

        current_speed_knots = 0.35 + (0.22 * meltemi_strength) + (0.10 * sin(((hour - 3.0) / 12.0) * pi))
        current_speed_knots = min(1.25, max(0.18, current_speed_knots * (0.94 + distance_factor * 0.08)))

        current_direction_deg = (188.0 + (24.0 * meltemi_strength) + (14.0 * synoptic_pulse)) % 360.0
        wave_height_m = 0.32 + (0.045 * wind_speed_knots) + (0.18 * meltemi_strength) + (0.05 * synoptic_pulse)
        wave_height_m = min(1.8, max(0.2, wave_height_m * coastal_damping))

        water_temperature_c = 19.0 + (6.3 * sin(((day_of_year - 172) / 365.0) * 2.0 * pi)) - (0.18 * wind_speed_knots)
        pressure_hpa = 1014.0 + (5.2 * sin(((day_of_year + 20.0) / 14.0) * 2.0 * pi)) - (0.35 * diurnal_breeze)

        return {
            "wave_height_m": round(wave_height_m, 2),
            "ocean_current_velocity_mps": round(current_speed_knots / 1.94384, 3),
            "water_temperature_c": round(water_temperature_c, 1),
            "wind_speed_knots": round(wind_speed_knots, 1),
            "wind_direction_deg": int(round(wind_direction_deg)) % 360,
            "current_speed_knots": round(current_speed_knots, 2),
            "current_direction_deg": int(round(current_direction_deg)) % 360,
            "pressure_hpa": round(pressure_hpa, 1),
            "source": "didim_mavisehir_simulation",
            "fallback": False,
        }

    @staticmethod
    def _rounded_or_simulated(
        value: Optional[float],
        simulated_value: Optional[float],
        digits: int,
    ) -> Optional[float]:
        if value is None:
            return simulated_value
        return round(value, digits)

    @staticmethod
    def _fallback_depth(reason: str) -> Dict[str, Any]:
        return {
            "depth_m": None,
            "raw_elevation_m": None,
            "dataset": None,
            "source": "fallback",
            "fallback": True,
            "reason": reason,
        }

    @staticmethod
    def _fallback_species(reason: str) -> Dict[str, Any]:
        return {
            "radius_km": None,
            "query_geometry_wkt": None,
            "top_species": [],
            "total_records_considered": 0,
            "source": "fallback",
            "fallback": True,
            "reason": reason,
        }
