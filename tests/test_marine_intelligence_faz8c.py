from __future__ import annotations

import os
import tempfile
import unittest
from typing import Any, Dict

from fastapi.testclient import TestClient

import main
from marine_intelligence.catch_context import build_catch_context_for_spot
from marine_intelligence.catch_service import CatchIntelligenceService
from marine_intelligence.dependencies import (
    get_catch_intelligence_service,
    get_catch_record_store,
    get_spot_intelligence_store,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.models import MAX_CATCH_SPECIES_LEN
from marine_intelligence.spot_reputation import compute_spot_reputation, spot_level_from_reputation
from marine_intelligence.storage.catch_record_store import SqliteCatchRecordStore
from marine_intelligence.storage.sqlite_store import SqliteSpotIntelligenceStore


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


class CatchIntelligenceEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        self._tmpdir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.db_path = os.path.join(self._tmpdir.name, "spots.db")
        self.spot_store = SqliteSpotIntelligenceStore(self.db_path)
        self.catch_store = SqliteCatchRecordStore(self.db_path)
        self.catch_service = CatchIntelligenceService(self.spot_store, self.catch_store)

        main.app.dependency_overrides[get_spot_intelligence_store] = lambda: self.spot_store
        main.app.dependency_overrides[get_catch_record_store] = lambda: self.catch_store
        main.app.dependency_overrides[get_catch_intelligence_service] = lambda: self.catch_service

        self.spot = self.spot_store.create_spot(
            name="Fethiye Kayalık",
            lat=36.62123,
            lon=29.11234,
            note="Test",
            favorite=True,
            personal_tags=["levrek"],
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

    def _catch_payload(self, **overrides: Any) -> Dict[str, Any]:
        base = {
            "species": "Levrek",
            "length_cm": 53,
            "weight_kg": 2.1,
            "bait": "Silikon",
            "method": "Spin",
            "caught_at": "2026-07-03T06:42:00Z",
            "notes": "Sabah gün doğumuna yakın",
        }
        base.update(overrides)
        return base

    def test_create_catch_success(self) -> None:
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["catch"]["species"], "Levrek")
        self.assertEqual(body["catch"]["spot_id"], self.spot.id)
        self.assertEqual(body["spot"]["last_success_species"], "Levrek")
        self.assertEqual(body["spot"]["last_success_weight"], 2.1)
        self.assertEqual(body["spot"]["visit_count"], 0)
        self.assertIn("learning_summary", body)

    def test_create_catch_validates_species(self) -> None:
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(species=" "),
        )
        self.assertEqual(resp.status_code, 422)
        long_name = "x" * (MAX_CATCH_SPECIES_LEN + 1)
        resp2 = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(species=long_name),
        )
        self.assertEqual(resp2.status_code, 422)

    def test_snapshot_fields_copied_from_last_report(self) -> None:
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        self.assertEqual(resp.status_code, 200)
        catch = resp.json()["catch"]
        self.assertIsNotNone(catch["weather_snapshot"])
        self.assertIsNotNone(catch["marine_snapshot"])
        self.assertIsNotNone(catch["decision_snapshot"])
        self.assertEqual(catch["decision_snapshot"]["go_score"], 72)
        self.assertIsNotNone(catch["scenario_snapshot"])
        self.assertIsNotNone(catch["moon_snapshot"])

    def test_spot_last_success_fields_update(self) -> None:
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(caught_at="2026-07-04T08:00:00Z", species="Çipura"),
        )
        self.assertEqual(resp.status_code, 200)
        spot = resp.json()["spot"]
        self.assertEqual(spot["last_success_species"], "Çipura")
        self.assertEqual(spot["last_success_date"], "2026-07-04T08:00:00Z")

    def test_spot_reputation_heuristic(self) -> None:
        reputation, _ = compute_spot_reputation(
            catch_count=3,
            visit_count=5,
            has_recent_success=True,
            go_score=72,
        )
        self.assertEqual(reputation, 85)
        self.assertEqual(spot_level_from_reputation(reputation), "Elite")

        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIsNotNone(resp.json()["spot"]["spot_reputation"])

    def test_list_catches_by_spot(self) -> None:
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(species="Çipura", caught_at="2026-07-04T08:00:00Z"),
        )
        resp = self.client.get(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catches",
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["count"], 2)
        self.assertEqual(len(body["catches"]), 2)
        self.assertIn("summary", body)

    def test_learning_summary_top_species(self) -> None:
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(caught_at="2026-07-04T08:00:00Z"),
        )
        resp = self.client.get(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/learning_summary",
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["catch_count"], 2)
        self.assertEqual(body["top_species"], "Levrek")
        self.assertIn("message_tr", body)

    def test_delete_catch(self) -> None:
        create = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        catch_id = create.json()["catch"]["id"]
        resp = self.client.delete(f"/api/v1/marine_intelligence/catches/{catch_id}")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()["deleted"])
        listed = self.client.get(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catches",
        )
        self.assertEqual(listed.json()["count"], 0)

    def test_catch_not_found_404(self) -> None:
        resp = self.client.delete("/api/v1/marine_intelligence/catches/missing-id")
        self.assertEqual(resp.status_code, 404)

    def test_catch_context_hook(self) -> None:
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{self.spot.id}/catch",
            json=self._catch_payload(),
        )
        ctx = build_catch_context_for_spot(
            self.spot.id,
            spot_store=self.spot_store,
            catch_store=self.catch_store,
        )
        self.assertTrue(ctx["found"])
        self.assertEqual(ctx["top_species"], "Levrek")
        self.assertEqual(len(ctx["recent_catches"]), 1)


class CatchIntelligenceHealthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        reset_marine_intelligence_singletons()

    def test_health_catch_field(self) -> None:
        resp = self.client.get("/health")
        mi = resp.json()["marine_intelligence"]
        self.assertIn("catch_intelligence_enabled", mi)
        self.assertTrue(mi["catch_intelligence_enabled"])


if __name__ == "__main__":
    unittest.main()
