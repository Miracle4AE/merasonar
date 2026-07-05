from __future__ import annotations

import os
import tempfile
import unittest
from typing import Any, Dict
from unittest.mock import patch

from fastapi.testclient import TestClient

import main
from ai_assistant.context_builder import AiAssistantContextBuilder
from ai_assistant.models import AiFishingAssistantRequestModel, MarineCompareContextInputModel
from marine_intelligence.compare_engine import compute_comparison
from marine_intelligence.dependencies import (
    get_marine_compare_service,
    get_spot_intelligence_store,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.models import (
    AstronomyBlockModel,
    ConsensusSummaryModel,
    CoordinateModel,
    DecisionModel,
    FishingScoreModel,
    MarineAiCommentModel,
    MarineCoordinateResponseModel,
    ProviderStatusModel,
    WeatherBlockModel,
    WindBlockModel,
    MarineBlockModel,
)
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore
from tests.test_marine_intelligence_faz7c import _mock_marine_service


def _report(
    *,
    go_score: int,
    risk_score: int = 30,
    confidence: float = 0.8,
    partial_data: bool = False,
    lat: float = 36.62,
    lon: float = 29.11,
) -> MarineCoordinateResponseModel:
    return MarineCoordinateResponseModel(
        coordinate=CoordinateModel(lat=lat, lon=lon),
        weather=WeatherBlockModel(),
        wind=WindBlockModel(),
        marine=MarineBlockModel(),
        astronomy=AstronomyBlockModel(),
        fishing_score=FishingScoreModel(
            suitability_score=go_score,
            risk_score=risk_score,
            confidence=confidence,
        ),
        consensus_summary=ConsensusSummaryModel(
            overall_confidence=confidence,
            provider_count=2,
            partial_providers=partial_data,
        ),
        provider_status=ProviderStatusModel(),
        updated_at="2026-07-03T06:00:00Z",
        partial_data=partial_data,
        decision=DecisionModel(
            fishing_decision="good",
            go_score=go_score,
            wait_score=100 - go_score,
            short_summary_tr="Test özet",
        ),
    )


class CompareEngineTests(unittest.TestCase):
    def test_winner_left(self) -> None:
        left = _report(go_score=75)
        right = _report(go_score=55, lat=36.64, lon=29.14)
        result = compute_comparison(left, right, left_label="A", right_label="B")
        self.assertEqual(result.winner, "left")
        self.assertEqual(result.score_delta, 20)

    def test_winner_right(self) -> None:
        left = _report(go_score=50)
        right = _report(go_score=70, lat=36.64, lon=29.14)
        result = compute_comparison(left, right, left_label="A", right_label="B")
        self.assertEqual(result.winner, "right")

    def test_tie_if_score_delta_small(self) -> None:
        left = _report(go_score=72)
        right = _report(go_score=70, lat=36.64, lon=29.14)
        result = compute_comparison(left, right, left_label="A", right_label="B")
        self.assertEqual(result.winner, "tie")

    def test_partial_data_reason(self) -> None:
        left = _report(go_score=72, partial_data=True)
        right = _report(go_score=60, lat=36.64, lon=29.14)
        result = compute_comparison(left, right, left_label="A", right_label="B")
        self.assertTrue(any("kısmi veri" in r for r in result.main_reasons))


class MarineCompareEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        self._tmpdir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.db_path = os.path.join(self._tmpdir.name, "spots.db")
        self.store = SqliteSpotIntelligenceStore(self.db_path)
        self.marine_service = _mock_marine_service()

        from marine_intelligence.compare_service import MarineCompareService

        self.compare_service = MarineCompareService(self.marine_service, self.store)
        main.app.dependency_overrides[get_spot_intelligence_store] = lambda: self.store
        main.app.dependency_overrides[get_marine_compare_service] = lambda: self.compare_service

        self.spot = self.store.create_spot(
            name="Kayalık A",
            lat=36.62123,
            lon=29.11234,
        )
        self.spot_b = self.store.create_spot(
            name="Kayalık B",
            lat=36.64123,
            lon=29.14234,
        )

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()
        self._tmpdir.cleanup()

    def test_compare_by_coordinates_success(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {"lat": 36.62, "lon": 29.11, "label": "A Noktası"},
                "right": {"lat": 36.64, "lon": 29.14, "label": "B Noktası"},
                "include_ai_comment": False,
            },
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIn("left_report", body)
        self.assertIn("comparison", body)
        self.assertIsNone(body["captain_comment"])

    def test_compare_by_spot_id_success(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {"spot_id": self.spot.id},
                "right": {"spot_id": self.spot_b.id},
            },
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["comparison"]["winner_label"], body["comparison"].get("winner_label"))

    def test_spot_id_overrides_lat_lon(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {
                    "spot_id": self.spot.id,
                    "lat": 0,
                    "lon": 0,
                    "label": "Override",
                },
                "right": {"lat": 36.64, "lon": 29.14, "label": "B"},
            },
        )
        self.assertEqual(resp.status_code, 200)
        left = resp.json()["left_report"]["coordinate"]
        self.assertAlmostEqual(left["lat"], self.spot.lat, places=3)

    def test_not_found_spot_id_404(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {"spot_id": "missing"},
                "right": {"lat": 36.64, "lon": 29.14},
            },
        )
        self.assertEqual(resp.status_code, 404)

    @patch("marine_intelligence.compare_service.generate_marine_compare_comment")
    def test_include_ai_comment_true_mock_captain(self, mock_ai: Any) -> None:
        mock_ai.return_value = MarineAiCommentModel(
            source="fallback",
            summary_tr="Karşılaştırma yorumu",
        )
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {"lat": 36.62, "lon": 29.11, "label": "A"},
                "right": {"lat": 36.64, "lon": 29.14, "label": "B"},
                "include_ai_comment": True,
            },
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIsNotNone(resp.json()["captain_comment"])
        mock_ai.assert_called_once()

    @patch("marine_intelligence.compare_service.generate_marine_compare_comment")
    def test_include_ai_comment_false_no_ai_call(self, mock_ai: Any) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/compare",
            json={
                "left": {"lat": 36.62, "lon": 29.11},
                "right": {"lat": 36.64, "lon": 29.14},
                "include_ai_comment": False,
            },
        )
        self.assertEqual(resp.status_code, 200)
        mock_ai.assert_not_called()

    def test_captain_atlas_prompt_contains_compare_context(self) -> None:
        builder = AiAssistantContextBuilder()
        request = AiFishingAssistantRequestModel(
            scope="marine_compare",
            marine_compare_context=MarineCompareContextInputModel(
                left_label="A",
                right_label="B",
                comparison={"winner": "left", "score_delta": 12},
                left_summary={"go_score": 75},
                right_summary={"go_score": 63},
            ),
        )
        ctx = builder.build(request)
        self.assertEqual(ctx["scope"], "marine_compare")
        self.assertEqual(ctx["left_label"], "A")
        self.assertIn("compare_instructions", ctx)


class MarineCompareHealthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        reset_marine_intelligence_singletons()

    def test_health_marine_compare_field(self) -> None:
        resp = self.client.get("/health")
        mi = resp.json()["marine_intelligence"]
        self.assertIn("marine_compare_enabled", mi)
        self.assertTrue(mi["marine_compare_enabled"])


if __name__ == "__main__":
    unittest.main()
