from __future__ import annotations

import unittest
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.consensus import build_consensus, circular_mean_deg
from marine_intelligence.dependencies import (
    build_marine_intelligence_service,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider, moon_phase_info
from marine_intelligence.providers.open_meteo_provider import (
    OpenMeteoProvider,
    parse_open_meteo_forecast,
    parse_open_meteo_marine,
)
from marine_intelligence.providers.reliability import ProviderReliability
from marine_intelligence.service import MarineIntelligenceService


def _sample_forecast_payload() -> Dict[str, Any]:
    return {
        "current": {
            "temperature_2m": 22.5,
            "apparent_temperature": 21.0,
            "precipitation_probability": 15,
            "precipitation": 0.0,
            "relative_humidity_2m": 65,
            "surface_pressure": 1013.2,
            "wind_speed_10m": 12.0,
            "wind_direction_10m": 180.0,
            "wind_gusts_10m": 18.0,
        },
        "hourly": {
            "time": ["2026-07-04T06:00", "2026-07-04T12:00"],
            "temperature_2m": [20.0, 24.0],
            "wind_speed_10m": [10.0, 14.0],
            "wind_gusts_10m": [16.0, 20.0],
            "precipitation_probability": [5, 10],
            "surface_pressure": [1012.0, 1013.0],
            "relative_humidity_2m": [70, 65],
        },
        "daily": {
            "time": [f"2026-07-{d:02d}" for d in range(4, 11)],
            "temperature_2m_max": [28.0, 27.0, 26.0, 25.0, 24.0, 23.0, 22.0],
            "temperature_2m_min": [18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 12.0],
            "precipitation_probability_max": [10, 20, 30, 40, 50, 60, 70],
            "weather_code": [0, 1, 2, 3, 61, 80, 95],
            "wind_speed_10m_max": [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0],
            "wind_gusts_10m_max": [20.0, 22.0, 24.0, 26.0, 28.0, 30.0, 32.0],
            "wind_direction_10m_dominant": [90, 100, 110, 120, 130, 140, 150],
        },
    }


def _sample_marine_payload() -> Dict[str, Any]:
    return {
        "current": {
            "wave_height": 0.6,
            "wave_direction": 90.0,
            "wave_period": 5.0,
            "swell_wave_height": 0.4,
            "swell_wave_direction": 270.0,
            "swell_wave_period": 8.0,
            "sea_surface_temperature": 19.5,
            "ocean_current_velocity": 0.2,
            "ocean_current_direction": 45.0,
        },
        "hourly": {
            "time": ["2026-07-04T06:00", "2026-07-04T12:00"],
            "wave_height": [0.5, 0.7],
        },
    }


def _make_config(**overrides: Any) -> MarineIntelligenceConfig:
    base = dict(
        marine_intelligence_enabled=True,
        cache_ttl_minutes=30,
        open_meteo_enabled=True,
        astronomy_local_enabled=True,
        mgm_enabled=False,
        windy_enabled=False,
        windy_app_enabled=False,
        poseidon_enabled=False,
        request_timeout_seconds=5.0,
        saved_spots_enabled=True,
        spot_storage_backend="sqlite",
        marine_ai_comment_cache_ttl_minutes=15,
        marine_catch_storage_enabled=True,
        bulk_learning_summary_enabled=True,
        marine_compare_enabled=True,
        tide_provider_enabled=False,
        tide_provider_name="world_tides",
        tide_api_key="",
        tide_api_base_url="https://www.worldtides.info/api/v3",
        tide_cache_ttl_minutes=60,
    )
    base.update(overrides)
    return MarineIntelligenceConfig(**base)


class MarineIntelligenceValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_coordinate_request_validation_lat(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 95, "lon": 27.0},
        )
        self.assertEqual(resp.status_code, 422)

    def test_coordinate_request_validation_lon(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 200},
        )
        self.assertEqual(resp.status_code, 422)


class OpenMeteoProviderTests(unittest.TestCase):
    def test_parse_forecast_mock(self) -> None:
        parsed = parse_open_meteo_forecast(_sample_forecast_payload())
        self.assertEqual(parsed["temperature_c"], 22.5)
        self.assertEqual(parsed["wind_speed_kmh"], 12.0)
        self.assertEqual(parsed["wind_direction_deg"], 180.0)

    def test_parse_marine_mock(self) -> None:
        parsed = parse_open_meteo_marine(_sample_marine_payload())
        self.assertEqual(parsed["wave_height_m"], 0.6)
        self.assertEqual(parsed["swell_direction_deg"], 270.0)

    def test_provider_fetch_with_injected_json(self) -> None:
        calls: list[str] = []

        def fake_fetch(url: str, timeout: float) -> Dict[str, Any]:
            calls.append(url)
            if "marine-api" in url:
                return _sample_marine_payload()
            return _sample_forecast_payload()

        provider = OpenMeteoProvider(fetch_json=fake_fetch)
        snap = provider.fetch(37.0, 27.0)
        self.assertTrue(snap.success)
        self.assertEqual(snap.weather["temperature_c"], 22.5)
        self.assertEqual(snap.marine["wave_height_m"], 0.6)
        self.assertEqual(len(calls), 2)


class AstronomyLocalTests(unittest.TestCase):
    def test_deterministic_moon_phase(self) -> None:
        at = datetime(2024, 6, 15, 12, 0, tzinfo=timezone.utc)
        phase1, illum1 = moon_phase_info(at)
        phase2, illum2 = moon_phase_info(at)
        self.assertEqual(phase1, phase2)
        self.assertEqual(illum1, illum2)

    def test_provider_deterministic_output(self) -> None:
        ref = datetime(2024, 6, 15, 6, 0, tzinfo=timezone.utc)
        provider = AstronomyLocalProvider(reference_time=ref)
        snap = provider.fetch(37.0, 27.0)
        self.assertTrue(snap.success)
        self.assertIsNotNone(snap.astronomy["sunrise"])
        self.assertIsNotNone(snap.astronomy["moon_phase"])
        self.assertIsNotNone(snap.astronomy["moon_illumination_pct"])


class ConsensusTests(unittest.TestCase):
    def test_single_source_confidence_capped(self) -> None:
        rel = {"open_meteo": ProviderReliability("open_meteo", 1.0, 0.8, enabled=True)}
        result = build_consensus("temperature_c", {"open_meteo": 20.0}, rel, unit="°C")
        self.assertEqual(result.final_value, 20.0)
        self.assertEqual(result.source_count, 1)
        self.assertEqual(result.confidence, 0.6)
        self.assertEqual(result.disagreement_level, "unknown")

    def test_multi_source_weighted(self) -> None:
        rel = {
            "open_meteo": ProviderReliability("open_meteo", 1.0, 0.8, enabled=True),
            "windy": ProviderReliability("windy", 0.5, 0.7, enabled=True),
        }
        result = build_consensus(
            "wave_height_m",
            {"open_meteo": 1.0, "windy": 2.0},
            rel,
            unit="m",
        )
        self.assertEqual(result.source_count, 2)
        # effective weights: open_meteo 0.8, windy 0.35
        expected = round((1.0 * 0.8 + 2.0 * 0.35) / 1.15, 3)
        self.assertEqual(result.final_value, expected)
        self.assertGreater(result.confidence, 0.6)

    def test_direction_vector_average(self) -> None:
        mean = circular_mean_deg([350.0, 10.0])
        self.assertIsNotNone(mean)
        self.assertTrue(abs(mean) < 5.0 or mean > 355.0)


class MarineIntelligenceEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def _mock_service(self) -> MarineIntelligenceService:
        ref = datetime(2024, 6, 15, 6, 0, tzinfo=timezone.utc)

        def fake_fetch(url: str, timeout: float) -> Dict[str, Any]:
            if "marine-api" in url:
                return _sample_marine_payload()
            return _sample_forecast_payload()

        providers = [
            OpenMeteoProvider(fetch_json=fake_fetch),
            AstronomyLocalProvider(reference_time=ref),
        ]
        cache = MarineIntelligenceCache(ttl_seconds=1800)
        return build_marine_intelligence_service(
            config=_make_config(),
            cache=cache,
            providers=providers,
        )

    def test_coordinate_endpoint_success_mock(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: self._mock_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.12345, "lon": 27.12345},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["coordinate"]["lat"], 37.12345)
        self.assertIsNotNone(body["weather"]["temperature_c"]["final_value"])
        self.assertIsNotNone(body["marine"]["wave_height_m"]["final_value"])
        self.assertIsNotNone(body["astronomy"]["sunrise"])
        self.assertIsNotNone(body["fishing_score"]["suitability_score"])
        self.assertFalse(body["cache_hit"])
        tide = body["tide"]
        self.assertIsNotNone(tide)
        self.assertFalse(tide["tide_provider_available"])
        self.assertIn("summary_tr", tide)
        self.assertIn("display_mode", tide)
        historical = body.get("historical")
        self.assertIsNotNone(historical)
        self.assertGreaterEqual(historical.get("day_count", 0), 7)
        self.assertEqual(len(historical.get("days", [])), 7)
        self.assertIn("day_label", historical["days"][0])
        self.assertIsNotNone(body["decision"])
        self.assertIsNotNone(body["decision_timeline"])
        self.assertIsNone(body["ai_comment"])
        self.assertIsNotNone(body["provider_comparison"])
        self.assertIsNotNone(body["explainability"])

    def test_coordinate_endpoint_partial_data_provider_failure(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        def failing_fetch(url: str, timeout: float) -> Dict[str, Any]:
            raise ConnectionError("network down")

        providers = [
            OpenMeteoProvider(fetch_json=failing_fetch),
            AstronomyLocalProvider(
                reference_time=datetime(2024, 6, 15, 6, 0, tzinfo=timezone.utc)
            ),
        ]
        service = build_marine_intelligence_service(
            config=_make_config(),
            cache=MarineIntelligenceCache(ttl_seconds=60),
            providers=providers,
        )
        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: service
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertTrue(body["partial_data"])
        self.assertEqual(body["provider_status"]["providers"]["open_meteo"], "failed")
        self.assertEqual(body["provider_status"]["providers"]["astronomy_local"], "ok")

    def test_cache_hit_and_miss(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        service = self._mock_service()
        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: service
        first = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 36.5, "lon": 28.5},
        )
        second = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 36.5, "lon": 28.5},
        )
        self.assertFalse(first.json()["cache_hit"])
        self.assertTrue(second.json()["cache_hit"])

    def test_force_refresh_bypasses_cache(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        service = self._mock_service()
        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: service
        self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 36.6, "lon": 28.6},
        )
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 36.6, "lon": 28.6, "force_refresh": True},
        )
        self.assertFalse(resp.json()["cache_hit"])

    def test_health_marine_intelligence_fields(self) -> None:
        resp = self.client.get("/health")
        self.assertEqual(resp.status_code, 200)
        mi = resp.json().get("marine_intelligence")
        self.assertIsNotNone(mi)
        self.assertIn("enabled", mi)
        self.assertIn("cache_ttl_minutes", mi)
        self.assertIn("providers_enabled", mi)
        self.assertNotIn("api_key", str(mi).lower())


class MarineIntelligenceCacheUnitTests(unittest.TestCase):
    def test_cache_key_rounding(self) -> None:
        fp = "w-open_meteo:1.00"
        key1 = MarineIntelligenceCache.build_key(37.123456, 27.987654, "open_meteo", fp)
        key2 = MarineIntelligenceCache.build_key(37.123459, 27.987659, "open_meteo", fp)
        self.assertEqual(key1, key2)


if __name__ == "__main__":
    unittest.main()
