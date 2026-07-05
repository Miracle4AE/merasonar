from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.decision_engine import compute_decision_timeline
from marine_intelligence.dependencies import reset_marine_intelligence_singletons
from marine_intelligence.models import (
    AstronomyBlockModel,
    ConsensusSummaryModel,
    ConsensusValueModel,
    DecisionModel,
    FishingScoreModel,
    HourlyForecastPointModel,
    MarineBlockModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider
from marine_intelligence.providers.open_meteo_provider import (
    OpenMeteoProvider,
    parse_open_meteo_hourly_series,
)
from marine_intelligence.report_snapshot import trim_report_snapshot
from marine_intelligence.scenario_engine import compute_scenarios, most_sensitive_factor_from_scenarios
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore
from tests.test_marine_intelligence_faz7a import _sample_forecast_payload, _sample_marine_payload
from tests.test_marine_intelligence_faz7c import _mock_marine_service
from tests.test_marine_intelligence_faz7e import _consensus_value, _good_weather_wind_marine


def _sample_hourly_forecast_payload() -> Dict[str, Any]:
    base = _sample_forecast_payload()
    base["hourly"] = {
        "time": [f"2024-06-15T{h:02d}:00" for h in range(12)],
        "wind_speed_10m": [10.0 + h for h in range(12)],
        "wind_gusts_10m": [14.0 + h for h in range(12)],
        "precipitation_probability": [10 + h * 2 for h in range(12)],
        "surface_pressure": [1013.0] * 12,
    }
    return base


def _sample_hourly_marine_payload() -> Dict[str, Any]:
    base = _sample_marine_payload()
    base["hourly"] = {
        "time": [f"2024-06-15T{h:02d}:00" for h in range(12)],
        "wave_height": [0.5 + h * 0.05 for h in range(12)],
    }
    return base


def _base_decision() -> DecisionModel:
    return DecisionModel(
        fishing_decision="good",
        go_score=76,
        wait_score=24,
        best_action_tr="Test",
        short_summary_tr="Test",
    )


def _scenario_inputs() -> dict[str, Any]:
    weather, wind, marine = _good_weather_wind_marine()
    return {
        "base_decision": _base_decision(),
        "fishing_score": FishingScoreModel(suitability_score=80, risk_score=25, confidence=0.85),
        "wind": wind,
        "marine": marine,
        "weather": weather,
        "astronomy": AstronomyBlockModel(moon_illumination_pct=25.0),
        "confidence": 0.85,
        "partial_data": False,
    }


class ScenarioEngineTests(unittest.TestCase):
    def test_default_five_scenarios(self) -> None:
        bundle = compute_scenarios(**_scenario_inputs())
        self.assertIsNotNone(bundle)
        assert bundle is not None
        self.assertEqual(len(bundle.items), 5)
        ids = {item.scenario_id for item in bundle.items}
        self.assertEqual(
            ids,
            {"wind_plus_5", "gust_plus_10", "wave_plus_0_5", "rain_plus_30", "moon_high"},
        )
        self.assertEqual(bundle.base_go_score, 76)

    def test_wind_plus_5_reduces_go_score(self) -> None:
        weather, wind, marine = _good_weather_wind_marine()
        windy = WindBlockModel(
            speed_kmh=_consensus_value(28.0),
            gust_kmh=_consensus_value(32.0),
        )
        bundle = compute_scenarios(
            base_decision=_base_decision(),
            fishing_score=FishingScoreModel(suitability_score=80, risk_score=25, confidence=0.85),
            wind=windy,
            marine=marine,
            weather=weather,
            astronomy=AstronomyBlockModel(moon_illumination_pct=25.0),
            confidence=0.85,
            partial_data=False,
        )
        assert bundle is not None
        wind_item = next(i for i in bundle.items if i.scenario_id == "wind_plus_5")
        self.assertLess(wind_item.delta_go_score or 0, 0)

    def test_wave_plus_0_5_increases_risk(self) -> None:
        bundle = compute_scenarios(**_scenario_inputs())
        assert bundle is not None
        wave_item = next(i for i in bundle.items if i.scenario_id == "wave_plus_0_5")
        self.assertGreater(wave_item.delta_risk_score or 0, 0)

    def test_moon_high_produces_summary(self) -> None:
        bundle = compute_scenarios(**_scenario_inputs())
        assert bundle is not None
        moon_item = next(i for i in bundle.items if i.scenario_id == "moon_high")
        self.assertTrue(moon_item.delta_summary_tr)
        self.assertIn("Ay", moon_item.title_tr)

    def test_missing_data_scenario_safe(self) -> None:
        weather = WeatherBlockModel()
        wind = WindBlockModel()
        marine = MarineBlockModel()
        bundle = compute_scenarios(
            base_decision=_base_decision(),
            fishing_score=FishingScoreModel(suitability_score=50, risk_score=30, confidence=0.4),
            wind=wind,
            marine=marine,
            weather=weather,
            astronomy=AstronomyBlockModel(),
            confidence=0.4,
            partial_data=True,
        )
        self.assertIsNotNone(bundle)
        assert bundle is not None
        self.assertEqual(len(bundle.items), 5)
        for item in bundle.items:
            self.assertIsNotNone(item.delta_summary_tr)

    def test_most_sensitive_factor(self) -> None:
        bundle = compute_scenarios(**_scenario_inputs())
        label = most_sensitive_factor_from_scenarios(bundle)
        self.assertIsNotNone(label)
        self.assertIn("duyarlı", label or "")


class HourlyTimelineTests(unittest.TestCase):
    def test_parse_open_meteo_hourly_series(self) -> None:
        series = parse_open_meteo_hourly_series(
            _sample_hourly_forecast_payload(),
            _sample_hourly_marine_payload(),
        )
        self.assertEqual(len(series), 12)
        self.assertEqual(series[0]["time"], "00:00")

    def test_timeline_uses_hourly_when_available(self) -> None:
        hourly: List[HourlyForecastPointModel] = [
            HourlyForecastPointModel.model_validate(row)
            for row in parse_open_meteo_hourly_series(
                _sample_hourly_forecast_payload(),
                _sample_hourly_marine_payload(),
            )
        ]
        weather, wind, marine = _good_weather_wind_marine()
        timeline = compute_decision_timeline(
            base_decision=_base_decision(),
            fishing_score=FishingScoreModel(suitability_score=80, risk_score=25, confidence=0.85),
            partial_data=False,
            hourly_series=hourly,
            wind=wind,
            marine=marine,
            weather=weather,
            astronomy=AstronomyBlockModel(moon_illumination_pct=25.0),
        )
        self.assertGreaterEqual(len(timeline), 4)
        self.assertLessEqual(len(timeline), 6)
        self.assertNotEqual([item.time for item in timeline], ["06:00", "09:00", "12:00", "15:00"])

    def test_timeline_fallback_preserved(self) -> None:
        timeline = compute_decision_timeline(
            base_decision=_base_decision(),
            fishing_score=FishingScoreModel(suitability_score=80, risk_score=25, confidence=0.85),
            partial_data=False,
            hourly_series=None,
        )
        self.assertEqual(len(timeline), 4)
        self.assertEqual([item.time for item in timeline], ["06:00", "09:00", "12:00", "15:00"])


class CoordinateScenarioEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_coordinate_includes_scenario(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: _mock_marine_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIsNotNone(body["scenario"])
        self.assertEqual(len(body["scenario"]["items"]), 5)
        self.assertIsNotNone(body["scenario"]["base_go_score"])
        self.assertIsNotNone(body["explainability"].get("most_sensitive_factor_tr"))


class SavedSpotScenarioSnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        self._tmpdir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.db_path = os.path.join(self._tmpdir.name, "spots.db")
        self.store = SqliteSpotIntelligenceStore(self.db_path)
        self.marine_service = _mock_marine_service()
        self.spot_service = SpotIntelligenceService(self.store, self.marine_service)

        from marine_intelligence.dependencies import (
            get_spot_intelligence_service,
            get_spot_intelligence_store,
        )

        main.app.dependency_overrides[get_spot_intelligence_store] = lambda: self.store
        main.app.dependency_overrides[get_spot_intelligence_service] = lambda: self.spot_service

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()
        self._tmpdir.cleanup()

    def test_refresh_snapshot_includes_scenario(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Scenario Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={},
        )
        snapshot = resp.json()["spot"]["last_report"]
        self.assertIn("scenario", snapshot)
        self.assertEqual(len(snapshot["scenario"]["items"]), 5)

    def test_trim_snapshot_scenario(self) -> None:
        report = self.marine_service.get_coordinate_intelligence(37.0, 27.0)
        snapshot = trim_report_snapshot(report)
        self.assertIn("scenario", snapshot)
        self.assertIn("items", snapshot["scenario"])


class HourlyProviderIntegrationTests(unittest.TestCase):
    def test_provider_attaches_hourly_when_present(self) -> None:
        def fake_fetch(url: str, timeout: float) -> Dict[str, Any]:
            if "marine-api" in url:
                return _sample_hourly_marine_payload()
            return _sample_hourly_forecast_payload()

        provider = OpenMeteoProvider(fetch_json=fake_fetch)
        snap = provider.fetch(37.0, 27.0)
        self.assertTrue(snap.success)
        self.assertEqual(len(snap.hourly_series), 12)


if __name__ == "__main__":
    unittest.main()
