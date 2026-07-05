from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timezone
from typing import Any, Dict
from unittest.mock import patch

from fastapi.testclient import TestClient

import main
from marine_intelligence.cache import MarineIntelligenceCache
from marine_intelligence.config import MarineIntelligenceConfig
from marine_intelligence.dependencies import (
    build_marine_intelligence_service,
    reset_marine_intelligence_singletons,
)
from marine_intelligence.models import MAX_SPOT_NAME_LEN, MAX_PERSONAL_TAGS, MAX_TAG_LEN
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


class SpotIntelligenceEndpointTests(unittest.TestCase):
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
        self.store = None
        self.spot_service = None
        self._tmpdir.cleanup()

    def test_create_saved_spot_success(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={
                "name": "Fethiye Kayalık 1",
                "lat": 36.62123,
                "lon": 29.11234,
                "note": "Sabah levrek denenebilir",
                "favorite": True,
                "personal_tags": ["levrek", "kayalık"],
            },
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["name"], "Fethiye Kayalık 1")
        self.assertTrue(body["favorite"])
        self.assertEqual(body["personal_tags"], ["levrek", "kayalık"])
        self.assertEqual(body["visit_count"], 0)
        self.assertIsNone(body["last_report"])
        self.assertIsNotNone(body["id"])

    def test_create_saved_spot_validation_name_length(self) -> None:
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "x" * (MAX_SPOT_NAME_LEN + 1), "lat": 36.0, "lon": 29.0},
        )
        self.assertEqual(resp.status_code, 422)

    def test_personal_tags_validation(self) -> None:
        too_many = [f"tag{i}" for i in range(MAX_PERSONAL_TAGS + 1)]
        resp = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Spot", "lat": 36.0, "lon": 29.0, "personal_tags": too_many},
        )
        self.assertEqual(resp.status_code, 422)

        long_tag = "x" * (MAX_TAG_LEN + 1)
        resp2 = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Spot", "lat": 36.0, "lon": 29.0, "personal_tags": [long_tag]},
        )
        self.assertEqual(resp2.status_code, 422)

    def test_list_favorite_sorting(self) -> None:
        self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Normal", "lat": 36.0, "lon": 29.0, "favorite": False},
        )
        self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Favorite", "lat": 36.1, "lon": 29.1, "favorite": True},
        )
        resp = self.client.get("/api/v1/marine_intelligence/saved_spots")
        self.assertEqual(resp.status_code, 200)
        spots = resp.json()["spots"]
        self.assertEqual(spots[0]["name"], "Favorite")
        self.assertTrue(spots[0]["favorite"])

        fav_resp = self.client.get("/api/v1/marine_intelligence/saved_spots?favorite=true")
        self.assertEqual(fav_resp.json()["count"], 1)
        self.assertEqual(fav_resp.json()["spots"][0]["name"], "Favorite")

    def test_patch_saved_spot(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Old", "lat": 36.0, "lon": 29.0},
        ).json()
        resp = self.client.patch(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}",
            json={"name": "New Name", "favorite": True, "personal_tags": ["test"]},
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["name"], "New Name")
        self.assertTrue(body["favorite"])
        self.assertEqual(body["personal_tags"], ["test"])

    def test_delete_saved_spot(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Delete Me", "lat": 36.0, "lon": 29.0},
        ).json()
        resp = self.client.delete(f"/api/v1/marine_intelligence/saved_spots/{created['id']}")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()["deleted"])

    def test_delete_not_found_404(self) -> None:
        resp = self.client.delete("/api/v1/marine_intelligence/saved_spots/nonexistent-id")
        self.assertEqual(resp.status_code, 404)
        self.assertEqual(resp.json().get("error"), "not_found")

    def test_refresh_saved_spot_calls_coordinate_service(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Refresh Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        with patch.object(
            self.marine_service,
            "get_coordinate_intelligence",
            wraps=self.marine_service.get_coordinate_intelligence,
        ) as mocked:
            resp = self.client.post(
                f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
                json={"force_refresh": True},
            )
            self.assertEqual(resp.status_code, 200)
            mocked.assert_called_once()

    def test_refresh_updates_last_report(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Report Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={},
        )
        body = resp.json()
        self.assertIsNotNone(body["spot"]["last_report"])
        self.assertIsNotNone(body["spot"]["last_report_at"])
        self.assertIn("weather", body["spot"]["last_report"])
        self.assertIn("fishing_score", body["spot"]["last_report"])
        self.assertNotIn("provider_status", body["spot"]["last_report"])
        self.assertIsNotNone(body["report"]["weather"])

    def test_refresh_increments_visit_count(self) -> None:
        created = self.client.post(
            "/api/v1/marine_intelligence/saved_spots",
            json={"name": "Visit Spot", "lat": 37.0, "lon": 27.0},
        ).json()
        self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={},
        )
        resp = self.client.post(
            f"/api/v1/marine_intelligence/saved_spots/{created['id']}/refresh",
            json={},
        )
        self.assertEqual(resp.json()["spot"]["visit_count"], 2)


class ReportSnapshotTests(unittest.TestCase):
    def test_last_report_snapshot_trim(self) -> None:
        service = _mock_marine_service()
        report = service.get_coordinate_intelligence(37.0, 27.0)
        snapshot = trim_report_snapshot(report)
        self.assertIn("coordinate", snapshot)
        self.assertIn("explainability", snapshot)
        self.assertNotIn("tide", snapshot)
        self.assertNotIn("provider_status", snapshot)
        if snapshot.get("provider_comparison") is not None:
            self.assertIn("summary", snapshot["provider_comparison"])
            self.assertNotIn("providers", snapshot["provider_comparison"])


class SqliteStorePersistenceTests(unittest.TestCase):
    def test_sqlite_store_persists_across_instance(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmpdir:
            db_path = os.path.join(tmpdir, "persist.db")
            store1 = SqliteSpotIntelligenceStore(db_path)
            spot = store1.create_spot(name="Persist", lat=36.0, lon=29.0)
            store2 = SqliteSpotIntelligenceStore(db_path)
            loaded = store2.get_spot(spot.id)
            self.assertIsNotNone(loaded)
            self.assertEqual(loaded.name, "Persist")


class SavedSpotsHealthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        reset_marine_intelligence_singletons()

    def test_health_saved_spot_fields(self) -> None:
        resp = self.client.get("/health")
        mi = resp.json()["marine_intelligence"]
        self.assertIn("saved_spots_enabled", mi)
        self.assertIn("saved_spots_storage", mi)
        self.assertEqual(mi["saved_spots_storage"], "sqlite")
        self.assertNotIn("marine_spots.db", str(mi))
        self.assertNotIn("api_key", str(mi).lower())


if __name__ == "__main__":
    unittest.main()
