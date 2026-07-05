from __future__ import annotations

import unittest
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.consensus import (
    build_consensus,
    circular_weighted_mean_deg,
    disagreement_level,
)
from marine_intelligence.dependencies import (
    build_marine_intelligence_service,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.explainability_engine import compute_explainability
from marine_intelligence.models import (
    ConsensusSummaryModel,
    ConsensusValueModel,
    MarineBlockModel,
    WeatherBlockModel,
    WindBlockModel,
)
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider
from marine_intelligence.providers.open_meteo_provider import OpenMeteoProvider
from marine_intelligence.providers.reliability import ProviderReliability, ProviderReliabilityRegistry
from marine_intelligence.service import MarineIntelligenceService
from tests.test_marine_intelligence_faz7a import (
    _make_config,
    _sample_forecast_payload,
    _sample_marine_payload,
)


class WeightedConsensusTests(unittest.TestCase):
    def test_weighted_average_numeric(self) -> None:
        rel = {
            "open_meteo": ProviderReliability("open_meteo", static_weight=1.0, runtime_confidence=0.9, enabled=True),
            "windy": ProviderReliability("windy", static_weight=0.5, runtime_confidence=0.8, enabled=True),
        }
        result = build_consensus("temperature_c", {"open_meteo": 20.0, "windy": 26.0}, rel, unit="°C")
        # effective: open_meteo=0.9, windy=0.4 -> weighted (20*0.9 + 26*0.4) / 1.3
        expected = round((20.0 * 0.9 + 26.0 * 0.4) / 1.3, 3)
        self.assertEqual(result.final_value, expected)
        self.assertEqual(result.min_value, 20.0)
        self.assertEqual(result.max_value, 26.0)
        self.assertEqual(result.mean_value, 23.0)

    def test_circular_weighted_angle(self) -> None:
        mean = circular_weighted_mean_deg([(350.0, 1.0), (10.0, 1.0)])
        self.assertIsNotNone(mean)
        self.assertTrue(abs(mean) < 5.0 or mean > 355.0)

        rel = {
            "a": ProviderReliability("a", static_weight=1.0, runtime_confidence=1.0, enabled=True),
            "b": ProviderReliability("b", static_weight=1.0, runtime_confidence=1.0, enabled=True),
        }
        result = build_consensus(
            "direction_deg",
            {"a": 350.0, "b": 10.0},
            rel,
            is_angle=True,
        )
        self.assertIsNotNone(result.final_value)
        self.assertTrue(abs(result.final_value) < 5.0 or result.final_value > 355.0)

    def test_disagreement_levels(self) -> None:
        self.assertEqual(disagreement_level([10.0, 10.2]), "low")
        self.assertEqual(disagreement_level([10.0, 11.5]), "medium")
        self.assertEqual(disagreement_level([10.0, 15.0]), "high")
        self.assertEqual(disagreement_level([10.0]), "unknown")

    def test_single_source_max_confidence(self) -> None:
        rel = {"open_meteo": ProviderReliability("open_meteo", static_weight=1.0, enabled=True)}
        result = build_consensus("wave_height_m", {"open_meteo": 1.0}, rel)
        self.assertLessEqual(result.confidence, 0.6)
        self.assertEqual(result.confidence, 0.6)


class ProviderReliabilityTests(unittest.TestCase):
    def test_success_failure_updates(self) -> None:
        registry = ProviderReliabilityRegistry(_make_config())
        registry.record_success("open_meteo")
        registry.record_success("open_meteo")
        registry.record_failure("open_meteo")
        rel = registry.get("open_meteo")
        self.assertEqual(rel.success_count, 2)
        self.assertEqual(rel.failure_count, 1)
        self.assertIsNotNone(rel.last_success)
        self.assertIsNotNone(rel.last_failure)
        self.assertGreater(rel.runtime_confidence, 0.0)
        self.assertLessEqual(rel.runtime_confidence, 0.95)

    def test_fingerprint_changes_with_provider_set(self) -> None:
        r1 = ProviderReliabilityRegistry(_make_config())
        r2 = ProviderReliabilityRegistry(_make_config(windy_enabled=True))
        self.assertNotEqual(r1.fingerprint(), r2.fingerprint())


class ExplainabilityTests(unittest.TestCase):
    def test_positive_negative_uncertainty(self) -> None:
        weather = WeatherBlockModel(
            precipitation_probability_pct=ConsensusValueModel(
                final_value=65.0, source_count=1, confidence=0.6
            )
        )
        wind = WindBlockModel(
            speed_kmh=ConsensusValueModel(final_value=35.0, source_count=1, confidence=0.6),
            gust_kmh=ConsensusValueModel(final_value=50.0, source_count=1, confidence=0.6),
        )
        marine = MarineBlockModel(
            wave_height_m=ConsensusValueModel(final_value=2.0, source_count=1, confidence=0.6),
            swell_height_m=ConsensusValueModel(final_value=2.0, source_count=1, confidence=0.6),
        )
        summary = ConsensusSummaryModel(overall_confidence=0.55, provider_count=1)
        result = compute_explainability(
            weather=weather,
            wind=wind,
            marine=marine,
            consensus_summary=summary,
            partial_data=True,
        )
        self.assertTrue(any("Rüzgar" in f for f in result.negative_factors))
        self.assertTrue(any("Dalga" in f for f in result.negative_factors))
        self.assertTrue(any("Yağış" in f for f in result.negative_factors))
        self.assertTrue(any("tek sağlayıcı" in f for f in result.uncertainty_factors))
        self.assertIsNotNone(result.explanation_summary_tr)


class MarineIntelligenceFaz7bEndpointTests(unittest.TestCase):
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
        return build_marine_intelligence_service(
            config=_make_config(),
            cache=MarineIntelligenceCache(ttl_seconds=1800),
            providers=providers,
        )

    def test_coordinate_includes_provider_comparison(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: self._mock_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        comparison = body.get("provider_comparison")
        self.assertIsNotNone(comparison)
        self.assertIn("providers", comparison)
        self.assertIn("summary", comparison)
        names = {p["name"] for p in comparison["providers"]}
        self.assertIn("open_meteo", names)
        self.assertIn("astronomy_local", names)
        self.assertGreater(comparison["summary"]["healthy_count"], 0)
        self.assertNotIn("api_key", str(comparison).lower())

    def test_coordinate_includes_explainability(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: self._mock_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        body = resp.json()
        expl = body.get("explainability")
        self.assertIsNotNone(expl)
        self.assertIn("positive_factors", expl)
        self.assertIn("negative_factors", expl)
        self.assertIn("uncertainty_factors", expl)
        self.assertIsNotNone(expl["explanation_summary_tr"])

    def test_consensus_summary_extended_fields(self) -> None:
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: self._mock_service()
        resp = self.client.post(
            "/api/v1/marine_intelligence/coordinate",
            json={"lat": 37.0, "lon": 27.0},
        )
        summary = resp.json()["consensus_summary"]
        self.assertIn("source_count_by_group", summary)
        self.assertIn("strongest_group", summary)
        self.assertIn("weakest_group", summary)
        self.assertIn("disagreement_groups", summary)
        self.assertIn("partial_providers", summary)


class CacheFingerprintTests(unittest.TestCase):
    def test_cache_key_includes_fingerprint(self) -> None:
        fp = ProviderReliabilityRegistry(_make_config()).fingerprint()
        key = MarineIntelligenceCache.build_key(37.0, 27.0, "astronomy_local,open_meteo", fp)
        self.assertIn("w-", key)
        self.assertIn("open_meteo", key)


if __name__ == "__main__":
    unittest.main()
