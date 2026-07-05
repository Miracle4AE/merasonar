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


class BoatAnchorEstimatedModeTests(unittest.TestCase):
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

    def test_bounds_plus_boat_anchor_without_control_points_enables_boat_anchor_estimated(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 120.0, "y": 60.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.62},
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
                # no control_points (or insufficient) -> NOT geo_referenced
                "control_points": [],
                "boat_pixel_anchor": {"x": 100.0, "y": 100.0, "confidence": 0.9, "source": "manual"},
            },
            enrich_data=False,
        )

        self.assertEqual(result.get("coordinate_mode"), "boat_anchor_estimated")
        self.assertEqual(result.get("is_geo_referenced"), False)

        hs = result["ranked_hotspots"][0]
        self.assertIsInstance(hs.get("latitude"), (int, float))
        self.assertIsInstance(hs.get("longitude"), (int, float))
        # never show/propagate 0/0 sentinel
        self.assertFalse(abs(float(hs["latitude"])) < 1e-9 and abs(float(hs["longitude"])) < 1e-9)
        self.assertIsInstance(hs.get("distance_m"), (int, float))
        self.assertIsInstance(hs.get("bearing_deg"), (int, float))

    def test_boat_anchor_estimated_can_use_server_cached_mapper_without_bounds(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 120.0, "y": 60.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.62},
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
                # no top_left/bottom_right here on purpose
                "control_points": [],
                "boat_pixel_anchor": {"x": 100.0, "y": 100.0, "confidence": 0.9, "source": "manual"},
            },
            enrich_data=False,
        )
        self.assertEqual(result.get("coordinate_mode"), "boat_anchor_estimated")

    def test_heuristic_scale_when_no_bounds_and_no_cached_mapper(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 120.0, "y": 60.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.62},
                    "feature_type": "drop_off",
                }
            ],
        }
        manager = FishingHotspotManager(
            bathymetry_analyzer=_FakeAnalyzer(payload),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )
        result = manager.process_new_chart_and_state(
            image_path="dummy.png",
            current_gps_lat=37.35,
            current_gps_lon=27.25,
            image_geo_bounds={
                "control_points": [],
                "boat_pixel_anchor": {"x": 100.0, "y": 100.0, "confidence": 0.9, "source": "manual"},
            },
            enrich_data=False,
        )
        self.assertEqual(result.get("coordinate_mode"), "boat_anchor_estimated")
        self.assertTrue(result.get("geo_map_display_allowed"))
        self.assertEqual(result.get("calibration_reliability"), "approximate")
        diag = result.get("diagnostics", {})
        self.assertEqual(diag.get("boat_anchor_estimate_reason"), "ok_gps_hotspots_heuristic_scale")
        self.assertIsInstance(diag.get("boat_anchor_heuristic_meters_per_pixel"), (int, float))
        hs = result["ranked_hotspots"][0]
        self.assertEqual(hs.get("mapping_trust"), "boat_anchor_estimated")
        self.assertIsInstance(hs.get("latitude"), (int, float))
        self.assertIsInstance(hs.get("longitude"), (int, float))
        boat = result.get("boat", {})
        self.assertIsNotNone(boat.get("navigation_anchor_geo"))

    def test_detected_boat_anchor_activates_even_if_request_anchor_is_center_fallback(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "features": {},
            "counts": {},
            "diagnostics": {
                # Analyzer-level detection (simulated): a real anchor on the image.
                "boat_pixel_anchor": {"x": 90.0, "y": 110.0, "confidence": 0.7, "source": "detected"},
            },
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 120.0, "y": 60.0},
                    "score": 0.80,
                    "classification": "B",
                    "reasoning": ["r1"],
                    "metrics": {"slope": 0.62},
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
                # no bounds/control points
                "control_points": [],
                # center fallback should be ignored for estimation when detected anchor exists
                "boat_pixel_anchor": {"x": 100.0, "y": 100.0, "confidence": 0.25, "source": "photo_center_fallback"},
            },
            enrich_data=False,
        )
        self.assertEqual(result.get("coordinate_mode"), "boat_anchor_estimated")

