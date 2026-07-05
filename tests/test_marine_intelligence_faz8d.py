from __future__ import annotations

import os
import tempfile
import unittest
from typing import Any, Dict
from unittest.mock import patch

from fastapi.testclient import TestClient

import main
from ai_assistant.context_builder import AiAssistantContextBuilder
from ai_assistant.models import AiFishingAssistantRequestModel, MarineCoordinateContextInputModel
from marine_intelligence.catch_service import CatchIntelligenceService
from marine_intelligence.dependencies import (
    get_catch_intelligence_service,
    get_catch_record_store,
    get_spot_intelligence_service,
    get_spot_intelligence_store,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.models import MAX_BULK_LEARNING_SPOT_IDS
from marine_intelligence.spot_service import SpotIntelligenceService
from marine_intelligence.storage.catch_record_store import SqliteCatchRecordStore
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore
from tests.test_marine_intelligence_faz7a import _make_config
from tests.test_marine_intelligence_faz7c import _mock_marine_service


def _sample_last_report() -> Dict[str, Any]:
    return {
        "coordinate": {"lat": 36.62, "lon": 29.11},
        "weather": {"temperature_c": {"final_value": 22.0}},
        "wind": {"speed_kmh": {"final_value": 10.0}},
        "marine": {"wave_height_m": {"final_value": 0.5}},
        "astronomy": {"moon_phase": "Ilk Hilal"},
        "fishing_score": {"suitability_score": 75, "risk_score": 20},
        "consensus_summary": {"overall_confidence": 0.6},
        "decision": {"fishing_decision": "good", "go_score": 72, "wait_score": 28},
        "scenario": {"base_go_score": 72, "items": []},
        "updated_at": "2026-07-03T06:00:00Z",
    }


class CatchIntelligenceHardeningTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        self._tmpdir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.db_path = os.path.join(self._tmpdir.name, "spots.db")
        self.spot_store = SqliteSpotIntelligenceStore(self.db_path)
        self.catch_store = SqliteCatchRecordStore(self.db_path)
        self.catch_service = CatchIntelligenceService(self.spot_store, self.catch_store)
        self.marine_service = _mock_marine_service()
        self.spot_service = SpotIntelligenceService(self.spot_store, self.marine_service)

        main.app.dependency_overrides[get_spot_intelligence_store] = lambda: self.spot_store
        main.app.dependency_overrides[get_catch_record_store] = lambda: self.catch_store
        main.app.dependency_overrides[get_catch_intelligence_service] = lambda: self.catch_service
        main.app.dependency_overrides[get_spot_intelligence_service] = lambda: self.spot_service

        self.spot = self.spot_store.create_spot(
            name="Fethiye Kayalık",
            lat=36.62123,
            lon=29.11234,
        )
        updated = self.spot_store.update_last_report(
            self.spot.id,
            _sample_last_report(),
            report_at="2026-07-03T06:00:00Z",
        )
        assert updated is not None
        self.spot = updated

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()
        self._tmpdir.cleanup()

    def _create_catch(self, **overrides: Any) -> Dict[str, Any]:
        payload = {
            "species": "Levrek",
            "length_cm": 53,
            "weight_kg": 2.1,
            "caught_at": "2026-07-03T06:42:00Z",
        }
        payload.update(overrides)
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=payload,
        )
        self.assertEqual(resp.status_code, 200)
        return resp.json()

    def test_bulk_learning_summaries_success(self) -> None:
        self._create_catch()
        spot2 = self.spot_store.create_spot(name="Spot 2", lat=36.7, lon=29.2)
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots/learning_summaries",
            json={"spot_ids": [self.spot.id, spot2.id]},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["summaries"][self.spot.id]["catch_count"], 1)
        self.assertEqual(body["summaries"][spot2.id]["catch_count"], 0)

    def test_bulk_max_100_validation(self) -> None:
        ids = [f"id-{i}" for i in range(MAX_BULK_LEARNING_SPOT_IDS + 1)]
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots/learning_summaries",
            json={"spot_ids": ids},
        )
        self.assertEqual(resp.status_code, 422)

    def test_bulk_missing_spot_safe_behavior(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots/learning_summaries",
            json={"spot_ids": [self.spot.id, "missing-spot"]},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertIn(self.spot.id, body["summaries"])
        self.assertIsNone(body["summaries"]["missing-spot"])
        self.assertIn("missing-spot", body["missing_spot_ids"])

    def test_patch_catch_updates_reputation(self) -> None:
        created = self._create_catch()
        catch_id = created["catch"]["id"]
        before_rep = created["spot"]["spot_reputation"]
        resp = self.client.patch(
            f"/api/v1/marine_intelligence/catches/{catch_id}",
            json={"species": "Çipura", "weight_kg": 3.5},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["catch"]["species"], "Çipura")
        self.assertEqual(body["spot"]["last_success_species"], "Çipura")
        self.assertIn("learning_summary", body)
        self.assertIsNotNone(body["spot"]["spot_reputation"])
        self.assertIsNotNone(before_rep)

    def test_delete_catch_recalculates_reputation(self) -> None:
        created = self._create_catch()
        catch_id = created["catch"]["id"]
        rep_with_catch = created["spot"]["spot_reputation"]
        resp = self.client.delete(f"/api/v1/marine_intelligence/catches/{catch_id}")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertTrue(body["deleted"])
        self.assertEqual(body["spot_id"], self.spot.id)
        self.assertEqual(body["learning_summary"]["catch_count"], 0)
        self.assertLess(body["learning_summary"]["spot_reputation"], rep_with_catch)

    def test_delete_missing_catch_404(self) -> None:
        resp = self.client.delete("/api/v1/marine_intelligence/catches/missing-id")
        self.assertEqual(resp.status_code, 404)

    def test_delete_spot_cascades_catches(self) -> None:
        self._create_catch()
        self._create_catch(species="Çipura", caught_at="2026-07-04T08:00:00Z")
        self._create_catch(species="Lüfer", caught_at="2026-07-05T08:00:00Z")
        resp = self.client.delete(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}",
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertTrue(body["deleted"])
        self.assertEqual(body["deleted_catches"], 3)
        self.assertEqual(len(self.catch_store.list_catches(spot_id=self.spot.id)), 0)

    def test_captain_atlas_prompt_contains_catch_context(self) -> None:
        builder = AiAssistantContextBuilder()
        request = AiFishingAssistantRequestModel(
            scope="marine_coordinate",
            marine_context=MarineCoordinateContextInputModel(
                lat=36.62,
                lon=29.11,
                catch_context={
                    "found": True,
                    "top_species": "Levrek",
                    "catch_count": 2,
                    "spot_reputation": 72,
                },
            ),
        )
        ctx = builder.build(request)
        self.assertIn("catch_context", ctx)
        self.assertEqual(ctx["catch_context"]["top_species"], "Levrek")
        self.assertIn("olasılıksal", ctx["catch_context_instructions"])

    @patch("marine_intelligence.service.generate_marine_ai_comment")
    def test_saved_spot_refresh_include_ai_comment_passes_catch_context(
        self,
        mock_ai: Any,
    ) -> None:
        from marine_intelligence.models import MarineAiCommentModel

        self._create_catch()
        mock_ai.return_value = MarineAiCommentModel(
            source="fallback",
            summary_tr="Test",
        )

        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/refresh",
            json={"force_refresh": True, "include_ai_comment": True},
        )
        self.assertEqual(resp.status_code, 200)
        mock_ai.assert_called_once()
        _, kwargs = mock_ai.call_args
        self.assertEqual(kwargs.get("spot_id"), self.spot.id)


class CatchIntelligenceHealth8DTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        reset_marine_intelligence_singletons()

    def test_health_bulk_learning_field(self) -> None:
        resp = self.client.get("/health")
        mi = resp.json()["marine_intelligence"]
        self.assertIn("bulk_learning_summary_enabled", mi)
        self.assertTrue(mi["bulk_learning_summary_enabled"])


if __name__ == "__main__":
    unittest.main()
