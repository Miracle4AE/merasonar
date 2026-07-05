from __future__ import annotations

import unittest
from typing import Any, Dict

from geo_navigation import PrecisionGPS
from maritime_orchestrator import FishingHotspotManager


class _FakeAnalyzer:
    def __init__(self, payload: Dict[str, Any]) -> None:
        self._payload = payload

    def analyze_chart(self, image_path: str) -> Dict[str, Any]:
        return self._payload


class ImageSpaceModeTests(unittest.TestCase):
    def _manager(self, payload: Dict[str, Any]) -> FishingHotspotManager:
        return FishingHotspotManager(
            bathymetry_analyzer=_FakeAnalyzer(payload),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )

    def test_no_control_points_forces_image_space(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 12.0, "y": 34.0},
                    "score": 0.82,
                    "classification": "A",
                    "reasoning": [],
                    "metrics": {},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=0.0,
            current_gps_lon=0.0,
            image_geo_bounds={"control_points": []},
            enrich_data=False,
        )
        self.assertEqual(result.get("coordinate_mode"), "image_space")
        self.assertEqual(result["diagnostics"]["mapping_mode"], "image_space")
        self.assertIs(result.get("geo_map_display_allowed"), False)
        self.assertIs(result.get("is_geo_referenced"), False)
        self.assertIs(result.get("geo_map_display_allowed"),
                      result["diagnostics"].get("geo_map_display_allowed"))

    def test_image_space_hotspots_have_no_lat_lon(self) -> None:
        payload = {
            "image_size": {"width": 320, "height": 240},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 100.0, "y": 120.0},
                    "score": 0.60,
                    "classification": "B",
                    "reasoning": [],
                    "metrics": {},
                    "feature_type": "drop_off",
                }
            ],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=0.0,
            current_gps_lon=0.0,
            image_geo_bounds={"control_points": []},
            enrich_data=False,
        )
        hotspots = result["hotspots"]
        self.assertTrue(hotspots)
        self.assertNotIn("latitude", hotspots[0])
        self.assertNotIn("longitude", hotspots[0])
        self.assertIn("x", hotspots[0])
        self.assertIn("y", hotspots[0])

    def test_image_space_coordinates_within_image_bounds(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 100},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 0.0, "y": 0.0},
                    "score": 0.5,
                    "classification": "C",
                    "reasoning": [],
                    "metrics": {},
                    "feature_type": "shelf",
                },
                {
                    "pixel_centroid": {"x": 199.0, "y": 99.0},
                    "score": 0.7,
                    "classification": "B",
                    "reasoning": [],
                    "metrics": {},
                    "feature_type": "drop_off",
                },
            ],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=0.0,
            current_gps_lon=0.0,
            image_geo_bounds={"control_points": []},
            enrich_data=False,
        )
        hotspots = result["hotspots"]
        for h in hotspots:
            self.assertGreaterEqual(float(h["x"]), 0.0)
            self.assertGreaterEqual(float(h["y"]), 0.0)
            self.assertLess(float(h["x"]), 200.0)
            self.assertLess(float(h["y"]), 100.0)


if __name__ == "__main__":
    unittest.main()

