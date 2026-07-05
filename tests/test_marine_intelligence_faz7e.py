from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.decision_engine import compute_decision, compute_decision_timeline
from marine_intelligence.dependencies import (
    build_marine_intelligence_service,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.explainability_engine import compute_explainability
from marine_intelligence.models import (
    AstronomyBlockModel,
    ConsensusSummaryModel,
    ConsensusValueModel,
    DecisionModel,
    FishingScoreModel,
    MarineBlockModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider
from marine_intelligence.providers.open_meteo_provider import OpenMeteoProvider
from marine_intelligence.report_snapshot import trim_report_snapshot
from marine_intelligence.service import MarineIntelligenceService
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore
from tests.test_marine_intelligence_faz7a import (
    _make_config,
    _sample_forecast_payload,
    _sample_marine_payload,
)


def _mock_marine_service() -> MarineIntelligenceService:
    ref = datetime(2024, 6, 15, 6, 0, tzinfo=timezone.utc)

    def fake_fetch(url: str, timeout: float) -> Dict[str, Any]:
        if "marine-api" in url:
            return _sample_marine_payload()
        return _sample_forecast_payload()

    providers = [
        OpenMeteoProvider(fetch_json=fake_fetch),
        AstronomyLocalProvider(reference_time=ref),
    ]
    return build_marine_intelligence_service(
        config=_make_config(),
        cache=MarineIntelligenceCache(ttl_seconds=60),
        providers=providers,
    )


def _consensus_value(value: float) -> ConsensusValueModel:
    return ConsensusValueModel(
        final_value=value,
        confidence=0.85,
        source_count=1,
        disagreement_level="low",
    )


def _good_weather_wind_marine() -> tuple[WeatherBlockModel, WindBlockModel, MarineBlockModel]:
    return (
        WeatherBlockModel(precipitation_probability_pct=_consensus_value(10.0)),
        WindBlockModel(
            speed_kmh=_consensus_value(10.0),
            gust_kmh=_consensus_value(14.0),
        ),
        MarineBlockModel(
            wave_height_m=_consensus_value(0.5),
            swell_height_m=_consensus_value(0.3),
        ),
    )


class DecisionEngineTests(unittest.TestCase):
    def _decide(
        self,
        *,
        suitability: int,
        risk: int,
        confidence: float = 0.85,
        partial_data: bool = False,
        wind_speed: float = 10.0,
        wave: float = 0.5,
        gust: float = 14.0,
        rain: float = 10.0,
        moon: float = 25.0,
        overall_confidence: float = 0.85,
    ) -> DecisionModel:
        weather, wind, marine = _good_weather_wind_marine()
        weather = WeatherBlockModel(precipitation_probability_pct=_consensus_value(rain))
        wind = WindBlockModel(
            speed_kmh=_consensus_value(wind_speed),
            gust_kmh=_consensus_value(gust),
        )
        marine = MarineBlockModel(
            wave_height_m=_consensus_value(wave),
            swell_height_m=_consensus_value(0.3),
        )
        fishing_score = FishingScoreModel(
            suitability_score=suitability,
            risk_score=risk,
            confidence=confidence,
        )
        consensus = ConsensusSummaryModel(
            overall_confidence=overall_confidence,
            provider_count=1,
            partial_providers=partial_data,
        )
        astronomy = AstronomyBlockModel(moon_illumination_pct=moon)
        return compute_decision(
            fishing_score=fishing_score,
            consensus_summary=consensus,
            provider_comparison=None,
            weather=weather,
            wind=wind,
            marine=marine,
            astronomy=astronomy,
            partial_data=partial_data,
        )

    def test_decision_excellent(self) -> None:
        result = self._decide(suitability=90, risk=15)
        self.assertEqual(result.fishing_decision, "excellent")
        self.assertIsNotNone(result.go_score)
        self.assertGreaterEqual(result.go_score or 0, 70)

    def test_decision_good(self) -> None:
        result = self._decide(suitability=72, risk=30)
        self.assertIn(result.fishing_decision, {"good", "borderline"})

    def test_decision_borderline(self) -> None:
        result = self._decide(suitability=65, risk=52)
        self.assertIn(result.fishing_decision, {"borderline", "poor"})

    def test_decision_poor(self) -> None:
        result = self._decide(suitability=45, risk=55, overall_confidence=0.5, confidence=0.5)
        self.assertIn(result.fishing_decision, {"poor", "borderline", "unsafe"})

    def test_decision_unsafe_high_risk(self) -> None:
        result = self._decide(suitability=50, risk=80, wave=2.5, gust=45.0, wind_speed=40.0)
        self.assertEqual(result.fishing_decision, "unsafe")
        self.assertIn("high_risk", result.decision_reason_codes)

    def test_high_risk_degrades_decision(self) -> None:
        low_risk = self._decide(suitability=80, risk=20)
        high_risk = self._decide(suitability=80, risk=65, wave=2.0)
        self.assertLess(high_risk.go_score or 0, low_risk.go_score or 0)

    def test_low_confidence_degrades(self) -> None:
        high_conf = self._decide(suitability=78, risk=25, overall_confidence=0.9, confidence=0.9)
        low_conf = self._decide(suitability=78, risk=25, overall_confidence=0.5, confidence=0.5)
        self.assertIn("single_provider_uncertainty", low_conf.decision_reason_codes)
        levels = {"excellent": 4, "good": 3, "borderline": 2, "poor": 1, "unsafe": 0}
        self.assertLessEqual(
            levels.get(low_conf.fishing_decision or "", 0),
            levels.get(high_conf.fishing_decision or "", 0) + 1,
        )

    def test_partial_data_reason_code(self) -> None:
        result = self._decide(suitability=70, risk=25, partial_data=True)
        self.assertIn("partial_data", result.decision_reason_codes)

    def test_timeline_four_item_fallback(self) -> None:
        decision = self._decide(suitability=75, risk=25)
        fishing_score = FishingScoreModel(suitability_score=75, risk_score=25, confidence=0.8)
        timeline = compute_decision_timeline(
            base_decision=decision,
            fishing_score=fishing_score,
            partial_data=False,
        )
        self.assertEqual(len(timeline), 4)
        self.assertEqual([item.time for item in timeline], ["06:00", "09:00", "12:00", "15:00"])
        for item in timeline:
            self.assertIsNotNone(item.go_score)
            self.assertIsNotNone(item.decision)
            self.assertTrue(item.reason_tr)


class ExplainabilityDecisionAlignmentTests(unittest.TestCase):
    def test_reason_codes_reflected_in_explainability(self) -> None:
        weather, wind, marine = _good_weather_wind_marine()
        consensus = ConsensusSummaryModel(overall_confidence=0.5, provider_count=1)
        codes = ["low_wind", "partial_data", "single_provider_uncertainty"]
        result = compute_explainability(
            weather=weather,
            wind=wind,
            marine=marine,
            consensus_summary=consensus,
            partial_data=True,
            decision_reason_codes=codes,
        )
        joined = " ".join(
            result.positive_factors + result.negative_factors + result.uncertainty_factors
        )
        self.assertIn("Rüzgar düşük", joined)
        self.assertIn("tek sağlayıcı", joined.lower())
        self.assertIn("sağlayıcı", joined.lower())


class CoordinateDecisionEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_coordinate_includes_decision(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: _mock_marine_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIsNotNone(body["decision"])
        self.assertIn(body["decision"]["fishing_decision"], {"excellent", "good", "borderline", "poor", "unsafe"})
        self.assertIsNotNone(body["decision"]["go_score"])
        self.assertIsNotNone(body["decision"]["best_action_tr"])
        self.assertIsInstance(body["decision"]["decision_reason_codes"], list)
        self.assertIsNotNone(body["decision_timeline"])
        self.assertEqual(len(body["decision_timeline"]), 4)


class SavedSpotDecisionSnapshotTests(unittest.TestCase):
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

    def test_refresh_snapshot_includes_decision(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Decision Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={},
        )
        snapshot = resp.json()["spot"]["last_report"]
        self.assertIn("decision", snapshot)
        self.assertIsNotNone(snapshot["decision"])
        self.assertIn("decision_timeline", snapshot)
        self.assertEqual(len(snapshot["decision_timeline"]), 4)

    def test_trim_report_snapshot_decision_fields(self) -> None:
        report = self.marine_service.get_coordinate_intelligence(37.0, 27.0)
        snapshot = trim_report_snapshot(report)
        self.assertIn("decision", snapshot)
        self.assertIn("decision_timeline", snapshot)


if __name__ == "__main__":
    unittest.main()
