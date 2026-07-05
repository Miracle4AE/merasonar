from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timezone
from typing import Any, Dict
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.decision_engine import compute_decision_timeline
from marine_intelligence.dependencies import (
    build_marine_intelligence_service,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.models import (
    AstronomyBlockModel,
    DecisionModel,
    FishingScoreModel,
    HourlyForecastPointModel,
    MarineAiCommentModel,
    WeatherBlockModel,
    WindBlockModel,
    MarineBlockModel,
)
from marine_intelligence.marine_ai_comment import generate_marine_ai_comment
from marine_intelligence.providers.astronomy_local import AstronomyLocalProvider
from marine_intelligence.providers.open_meteo_provider import (
    OpenMeteoProvider,
    parse_open_meteo_hourly_series,
)
from marine_intelligence.report_snapshot import trim_report_snapshot
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore
from tests.test_marine_intelligence_faz7a import (
    _make_config,
    _sample_forecast_payload,
    _sample_marine_payload,
)
from tests.ai_assistant_fixtures import make_ai_config
from tests.test_marine_intelligence_faz7e import _good_weather_wind_marine
from tests.test_marine_intelligence_faz7f import (
    _base_decision,
    _mock_marine_service,
    _sample_hourly_forecast_payload,
    _sample_hourly_marine_payload,
)


def _hourly_series_models(count: int = 12) -> list[HourlyForecastPointModel]:
    return [
        HourlyForecastPointModel(
            time=f"{h:02d}:00",
            time_utc=f"2024-06-15T{h:02d}:00",
            wind_speed_kmh=10.0 + h,
            gust_kmh=14.0 + h,
            wave_height_m=0.4 + h * 0.05,
            precipitation_probability_pct=10.0 + h,
        )
        for h in range(count)
    ]


class OpenMeteoHourlyUrlTests(unittest.TestCase):
    def test_forecast_url_includes_hourly_params(self) -> None:
        url = OpenMeteoProvider._build_forecast_url(37.0, 27.0)
        self.assertIn("hourly=", url)
        self.assertIn("temperature_2m", url)
        self.assertIn("wind_speed_10m", url)
        self.assertIn("forecast_hours=24", url)

    def test_marine_url_includes_hourly_params(self) -> None:
        url = OpenMeteoProvider._build_marine_url(37.0, 27.0)
        self.assertIn("hourly=", url)
        self.assertIn("wave_height", url)
        self.assertIn("sea_surface_temperature", url)
        self.assertIn("forecast_hours=24", url)


class HourlyParseTests(unittest.TestCase):
    def test_hourly_series_parse(self) -> None:
        series = parse_open_meteo_hourly_series(
            _sample_hourly_forecast_payload(),
            _sample_hourly_marine_payload(),
            max_hours=12,
        )
        self.assertEqual(len(series), 12)
        self.assertEqual(series[0]["time"], "00:00")
        self.assertIsNotNone(series[0].get("wind_speed_kmh"))
        self.assertIsNotNone(series[0].get("wave_height_m"))

    def test_hourly_series_empty_when_missing(self) -> None:
        series = parse_open_meteo_hourly_series(
            {"current": {"temperature_2m": 20.0}},
            {"current": {"wave_height": 0.5}},
        )
        self.assertEqual(series, [])


class TimelineHourlyTests(unittest.TestCase):
    def test_timeline_uses_hourly_series(self) -> None:
        weather, wind, marine = _good_weather_wind_marine()
        hourly = _hourly_series_models(12)
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
        best = [item for item in timeline if item.is_best_slot]
        self.assertEqual(len(best), 1)

    def test_timeline_fallback_preserved(self) -> None:
        timeline = compute_decision_timeline(
            base_decision=_base_decision(),
            fishing_score=FishingScoreModel(suitability_score=80, risk_score=25, confidence=0.85),
            partial_data=False,
            hourly_series=None,
        )
        self.assertEqual(len(timeline), 4)
        self.assertEqual([item.time for item in timeline], ["06:00", "09:00", "12:00", "15:00"])


class AiCommentEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: _mock_marine_service()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_include_ai_comment_false_skips_ai(self) -> None:
        with patch("marine_intelligence.service.generate_marine_ai_comment") as mock_ai:
            resp = self.client.post(
                "/api/v1/marine_intelligence/coordinate",
                json={"lat": 37.0, "lon": 27.0, "include_ai_comment": False},
            )
            self.assertEqual(resp.status_code, 200)
            self.assertIsNone(resp.json().get("ai_comment"))
            mock_ai.assert_not_called()

    def test_include_ai_comment_true_returns_mock_ai(self) -> None:
        mock_comment = MarineAiCommentModel(
            source="ai",
            summary_tr="Koordinat bugün av için uygun görünüyor.",
            best_time_window_tr="Saat 08:00 UTC civarı en iyi pencere.",
            risk_note_tr="Dalga artışı riski izlenmeli.",
        )
        with patch(
            "marine_intelligence.service.generate_marine_ai_comment",
            return_value=mock_comment,
        ) as mock_ai:
            resp = self.client.post(
                "/api/v1/marine_intelligence/coordinate",
                json={"lat": 37.0, "lon": 27.0, "include_ai_comment": True},
            )
            self.assertEqual(resp.status_code, 200)
            body = resp.json()
            self.assertIsNotNone(body["ai_comment"])
            self.assertEqual(body["ai_comment"]["source"], "ai")
            self.assertEqual(body["ai_comment"]["summary_tr"], mock_comment.summary_tr)
            mock_ai.assert_called_once()

    def test_ai_failure_returns_fallback_comment(self) -> None:
        service = _mock_marine_service()
        report = service.get_coordinate_intelligence(37.0, 27.0)
        broken = MagicMock()
        broken.handle.side_effect = RuntimeError("upstream down")
        cfg = make_ai_config(api_key="test-key")
        comment = generate_marine_ai_comment(report, ai_service=broken, ai_config=cfg)
        self.assertEqual(comment.source, "fallback")
        self.assertIsNotNone(comment.summary_tr)
        self.assertEqual(comment.fallback_reason, "upstream_failure")


class SavedSpotAiCommentSnapshotTests(unittest.TestCase):
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

    def test_refresh_snapshot_includes_ai_comment_when_requested(self) -> None:
        mock_comment = MarineAiCommentModel(
            source="ai",
            summary_tr="Kayıtlı nokta yorumu",
        )
        with patch(
            "marine_intelligence.service.generate_marine_ai_comment",
            return_value=mock_comment,
        ):
            created = self.client.post(
                "/api/v1/marine_intelligence/saved_spots",
                json={"name": "AI Spot", "lat": 37.0, "lon": 27.0},
            ).json()
            resp = self.client.post(
                f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
                json={"include_ai_comment": True},
            )
            self.assertEqual(resp.status_code, 200)
            snapshot = resp.json()["spot"]["last_report"]
            self.assertIn("ai_comment", snapshot)
            self.assertEqual(snapshot["ai_comment"]["summary_tr"], "Kayıtlı nokta yorumu")

    def test_refresh_snapshot_omits_ai_comment_when_false(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "No AI Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={"include_ai_comment": False},
        )
        snapshot = resp.json()["spot"]["last_report"]
        self.assertIsNone(snapshot.get("ai_comment"))

    def test_trim_snapshot_ai_comment(self) -> None:
        mock_comment = MarineAiCommentModel(source="fallback", summary_tr="Trim test")
        with patch(
            "marine_intelligence.service.generate_marine_ai_comment",
            return_value=mock_comment,
        ):
            report = self.marine_service.get_coordinate_intelligence(
                37.0,
                27.0,
                include_ai_comment=True,
            )
        snapshot = trim_report_snapshot(report)
        self.assertIn("ai_comment", snapshot)
        self.assertEqual(snapshot["ai_comment"]["summary_tr"], "Trim test")


if __name__ == "__main__":
    unittest.main()
