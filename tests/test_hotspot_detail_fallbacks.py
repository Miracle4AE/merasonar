from __future__ import annotations

import unittest
from typing import Any, Dict

from bathymetry_analyzer import BathymetryAnalyzer
from geo_navigation import CoordinateMapper, GeoPoint, PrecisionGPS
from maritime_orchestrator import FishingHotspotManager


class _FakeAnalyzer(BathymetryAnalyzer):
    def __init__(self, payload: Dict[str, Any]) -> None:  # type: ignore[override]
        self._payload = payload

    def analyze_chart(self, image_path: str) -> Dict[str, Any]:  # type: ignore[override]
        return self._payload


class HotspotDetailFallbackTests(unittest.TestCase):
    def _manager(self, payload: Dict[str, Any], *, marine: Any) -> FishingHotspotManager:
        mapper = CoordinateMapper(
            image_width=200,
            image_height=200,
            top_left=GeoPoint(lat=37.40, lon=27.20),
            bottom_right=GeoPoint(lat=37.30, lon=27.30),
        )
        return FishingHotspotManager(
            bathymetry_analyzer=_FakeAnalyzer(payload),
            coordinate_mapper=mapper,
            precision_gps=PrecisionGPS(),
            marine_data_client=marine,
        )

    def test_geo_enrich_disabled_still_has_detail_fields(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 100.0, "y": 100.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.62, "contour_density": 0.66, "transition_band": 0.7},
                    "feature_type": "drop_off",
                }
            ],
        }
        manager = self._manager(payload, marine=None)
        result = manager.process_new_chart_and_state(
            image_path="dummy.png",
            current_gps_lat=37.35,
            current_gps_lon=27.25,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.20},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                "control_points": [
                    {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.20}},
                    {"pixel": {"x": 199.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                    {"pixel": {"x": 0.0, "y": 199.0}, "geo": {"lat": 37.30, "lon": 27.205}},
                ],
            },
            enrich_data=False,
        )
        hs = result["ranked_hotspots"][0]
        self.assertIn("confirmed_depth", hs)
        self.assertIn("likely_species", hs)
        self.assertIn("regional_species_context", hs)
        self.assertIn("fishing_advice", hs)
        self.assertEqual(hs["confirmed_depth"].get("source"), "rule_based_fallback")
        self.assertEqual(hs["likely_species"].get("source"), "rule_based_fallback")
        self.assertIn("bait_recommendation", hs)
        self.assertIn("tackle_recommendation", hs)
        self.assertIn("best_fishing_times", hs)
        self.assertIn("species_reasoning", hs)

    def test_geo_marine_client_failure_keeps_fallback(self) -> None:
        class _BrokenMarine:
            def enrich_hotspot_data(self, hotspot: Dict[str, Any]) -> Dict[str, Any]:
                raise RuntimeError("boom")

            def get_regional_species_bundle_for_bounds(self, *args: Any, **kwargs: Any):
                raise RuntimeError("boom")

        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 100.0, "y": 100.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.5},
                    "feature_type": "drop_off",
                }
            ],
        }
        manager = self._manager(payload, marine=_BrokenMarine())
        result = manager.process_new_chart_and_state(
            image_path="dummy.png",
            current_gps_lat=37.35,
            current_gps_lon=27.25,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.20},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                "control_points": [
                    {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.20}},
                    {"pixel": {"x": 199.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                    {"pixel": {"x": 0.0, "y": 199.0}, "geo": {"lat": 37.30, "lon": 27.205}},
                ],
            },
            enrich_data=True,
        )
        hs = result["ranked_hotspots"][0]
        self.assertIn("confirmed_depth", hs)
        self.assertIn("likely_species", hs)
        self.assertIn("regional_species_context", hs)
        # Even if enrichment was requested, client failures should not drop fields.
        self.assertIn(hs["confirmed_depth"].get("source"), ("rule_based_fallback", "calibration_required"))

    def test_image_space_stub_preserved(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 100.0, "y": 100.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.5},
                    "feature_type": "drop_off",
                }
            ],
        }
        manager = self._manager(payload, marine=None)
        result = manager.process_new_chart_and_state(
            image_path="dummy.png",
            current_gps_lat=0.0,
            current_gps_lon=0.0,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.20},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                # GPS geçersiz => gerçek image_space (kalibrasyon stub’ları)
            },
            enrich_data=False,
        )
        hs = result["ranked_hotspots"][0]
        self.assertEqual(hs.get("mapping_trust"), "image_space")
        self.assertEqual(hs.get("confirmed_depth", {}).get("source"), "calibration_required")
        self.assertEqual(hs.get("likely_species", {}).get("source"), "calibration_required")


if __name__ == "__main__":
    unittest.main()

