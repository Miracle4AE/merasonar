from __future__ import annotations

import unittest
from typing import Any, Dict

from bathymetry_analyzer import BathymetryAnalyzer
from geo_navigation import CoordinateMapper, GeoPoint, PixelPoint, PrecisionGPS
from maritime_orchestrator import FishingHotspotManager


class _AnalyzerWithPayload(BathymetryAnalyzer):
    def __init__(self, payload: Dict[str, Any]) -> None:  # type: ignore[override]
        self._payload = payload

    def analyze_chart(self, image_path: str) -> Dict[str, Any]:  # type: ignore[override]
        return self._payload


class GeoreferenceAlignmentTests(unittest.TestCase):
    def _manager(self, payload: Dict[str, Any]) -> FishingHotspotManager:
        mapper = CoordinateMapper(
            image_width=400,
            image_height=300,
            top_left=GeoPoint(lat=37.40, lon=27.10),
            bottom_right=GeoPoint(lat=37.30, lon=27.30),
        )
        return FishingHotspotManager(
            bathymetry_analyzer=_AnalyzerWithPayload(payload),
            coordinate_mapper=mapper,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )

    def test_land_side_candidates_are_rejected_by_geo_validity(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 100.0, "y": 120.0},
                    "score": 0.9,
                    "classification": "A",
                    "reasoning": ["x"],
                    "metrics": {
                        "water_confidence": 0.92,
                        "land_distance_px": 12.0,
                        "coast_distance_px": 9.0,
                        "structure_score": 0.70,
                    },
                    "feature_type": "drop_off",
                },
                {
                    "pixel_centroid": {"x": 200.0, "y": 140.0},
                    "score": 0.88,
                    "classification": "A",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.35, "land_distance_px": 2.0},
                    "feature_type": "drop_off",
                },
            ],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.10},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                "control_points": [
                    {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},
                    {"pixel": {"x": 399.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                    {"pixel": {"x": 0.0, "y": 299.0}, "geo": {"lat": 37.30, "lon": 27.105}},
                ],
            },
            enrich_data=False,
        )

        hotspots = result["ranked_hotspots"]
        self.assertEqual(len(hotspots), 1)
        self.assertEqual(hotspots[0]["pixel_centroid"], {"x": 100.0, "y": 120.0})
        self.assertEqual(hotspots[0]["trust_state"], "trusted")
        self.assertTrue(hotspots[0]["is_renderable"])

    def test_boat_pixel_anchor_is_preserved_from_screenshot_diagnostics(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {
                "boat_anchor_detection": {
                    "boat_pixel_anchor": {"x": 155.0, "y": 111.0},
                    "anchor_confidence": 0.8,
                    "anchor_detection_method": "hsv_component_scoring_v1",
                    "status": "detected",
                }
            },
            "candidate_hotspots": [],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.10},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                "control_points": [
                    {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},
                    {"pixel": {"x": 399.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                    {"pixel": {"x": 0.0, "y": 299.0}, "geo": {"lat": 37.30, "lon": 27.105}},
                ],
            },
            enrich_data=False,
        )

        anchor = result["boat"]["pixel_anchor"]
        self.assertIsNotNone(anchor)
        self.assertEqual(anchor["x"], 155.0)
        self.assertEqual(anchor["y"], 111.0)
        self.assertEqual(result["boat"]["boat_anchor_source"], "detected")

    def test_projection_consistency_with_affine_control_points(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 220.0, "y": 160.0},
                    "score": 0.77,
                    "classification": "B",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.9, "land_distance_px": 20.0},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = self._manager(payload)
        bounds = {
            "top_left": {"lat": 37.40, "lon": 27.10},
            "bottom_right": {"lat": 37.30, "lon": 27.30},
            "control_points": [
                {
                    "pixel": {"x": 0.0, "y": 0.0},
                    "geo": {"lat": 37.40, "lon": 27.10},
                },
                {
                    "pixel": {"x": 399.0, "y": 0.0},
                    "geo": {"lat": 37.395, "lon": 27.30},
                },
                {
                    "pixel": {"x": 0.0, "y": 299.0},
                    "geo": {"lat": 37.30, "lon": 27.105},
                },
            ],
        }
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds=bounds,
            enrich_data=False,
        )

        self.assertEqual(result["diagnostics"]["mapping_mode"], "affine_control_points")
        self.assertEqual(result["diagnostics"]["mapping_trust_state"], "chart_georeferenced_precise")
        self.assertEqual(result["diagnostics"]["render_mode_recommendation"], "chart_overlay_primary")
        self.assertIn("georeference_error", result["diagnostics"])
        self.assertIn("transform_quality", result["diagnostics"])
        self.assertEqual(result["diagnostics"]["control_points_status"], "accepted")
        self.assertEqual(result["diagnostics"]["control_points_valid"], 3)
        self.assertEqual(result["diagnostics"]["control_points_invalid"], 0)

    def test_affine_control_points_without_cached_mapper(self) -> None:
        """Production API builds FishingHotspotManager with coordinate_mapper=None."""
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 220.0, "y": 160.0},
                    "score": 0.77,
                    "classification": "B",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.9, "land_distance_px": 20.0},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = FishingHotspotManager(
            bathymetry_analyzer=_AnalyzerWithPayload(payload),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )
        bounds = {
            "top_left": {"lat": 37.40, "lon": 27.10},
            "bottom_right": {"lat": 37.30, "lon": 27.30},
            "control_points": [
                {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},
                {"pixel": {"x": 399.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                {"pixel": {"x": 0.0, "y": 299.0}, "geo": {"lat": 37.30, "lon": 27.105}},
            ],
        }
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds=bounds,
            enrich_data=False,
        )
        self.assertEqual(result["coordinate_mode"], "geo_referenced")
        self.assertEqual(result["diagnostics"]["mapping_mode"], "affine_control_points")
        self.assertEqual(len(result["ranked_hotspots"]), 1)

    def test_invalid_control_points_fall_back_safely(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 220.0, "y": 160.0},
                    "score": 0.77,
                    "classification": "B",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.9, "land_distance_px": 20.0},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = self._manager(payload)
        bounds = {
            "top_left": {"lat": 37.40, "lon": 27.10},
            "bottom_right": {"lat": 37.30, "lon": 27.30},
            "control_points": [
                {"pixel": {"x": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},  # missing y
                {"pixel": {"x": -1.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},  # invalid x
                {"pixel": {"x": 0.0, "y": 299.0}, "geo": {"lat": 137.30, "lon": 27.105}},  # invalid lat
            ],
        }
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds=bounds,
            enrich_data=False,
        )

        # Geçersiz kontrol noktaları → affine yok; chart köşeleri ile yaklaşık boat_anchor_estimated.
        self.assertEqual(result["diagnostics"]["mapping_mode"], "boat_anchor_estimated")
        self.assertEqual(result["diagnostics"]["control_points_status"], "insufficient_valid_points")
        self.assertEqual(result["diagnostics"]["control_points_received"], 3)
        self.assertEqual(result["diagnostics"]["control_points_valid"], 0)
        self.assertEqual(result["diagnostics"]["control_points_invalid"], 3)
        self.assertEqual(len(result["ranked_hotspots"]), 1)

    def test_affine_uses_all_control_points(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 220.0, "y": 160.0},
                    "score": 0.77,
                    "classification": "B",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.9, "land_distance_px": 20.0},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = FishingHotspotManager(
            bathymetry_analyzer=_AnalyzerWithPayload(payload),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )
        bounds = {
            "top_left": {"lat": 37.40, "lon": 27.10},
            "bottom_right": {"lat": 37.30, "lon": 27.30},
            "control_points": [
                {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},
                {"pixel": {"x": 399.0, "y": 299.0}, "geo": {"lat": 37.30, "lon": 27.30}},
                {"pixel": {"x": 200.0, "y": 150.0}, "geo": {"lat": 37.35, "lon": 27.20}},
                {"pixel": {"x": 100.0, "y": 80.0}, "geo": {"lat": 37.39, "lon": 27.25}},
            ],
        }
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds=bounds,
            enrich_data=False,
        )
        self.assertLess(result["diagnostics"]["georeference_error"], 150.0)
        self.assertEqual(result["diagnostics"]["control_points_valid"], 4)
        self.assertGreater(result["diagnostics"]["transform_quality"], 0.9)
        self.assertTrue(result["geo_map_display_allowed"])

    def test_derives_bounds_when_corners_missing(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [
                {
                    "pixel_centroid": {"x": 220.0, "y": 160.0},
                    "score": 0.77,
                    "classification": "B",
                    "reasoning": ["x"],
                    "metrics": {"water_confidence": 0.9, "land_distance_px": 20.0},
                    "feature_type": "ridge_spur",
                }
            ],
        }
        manager = FishingHotspotManager(
            bathymetry_analyzer=_AnalyzerWithPayload(payload),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=None,
        )
        nw_lat, nw_lon = 37 + 24.345 / 60, 27 + 13.376 / 60
        se_lat, se_lon = 37 + 21.574 / 60, 27 + 11.552 / 60
        ref_lat, ref_lon = 37 + 22.540 / 60, 27 + 11.978 / 60
        bounds = {
            "control_points": [
                {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": nw_lat, "lon": nw_lon}},
                {"pixel": {"x": 399.0, "y": 299.0}, "geo": {"lat": se_lat, "lon": se_lon}},
                {"pixel": {"x": 200.0, "y": 150.0}, "geo": {"lat": ref_lat, "lon": ref_lon}},
            ],
        }
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds=bounds,
            enrich_data=False,
        )
        self.assertEqual(result["coordinate_mode"], "geo_referenced")
        self.assertEqual(result["diagnostics"]["mapping_mode"], "affine_control_points")

    def test_low_confidence_detection_uses_gps_fallback(self) -> None:
        payload = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {
                "boat_anchor_detection": {
                    "boat_pixel_anchor": None,
                    "anchor_confidence": 0.2,
                    "anchor_detection_method": "hsv_component_scoring_v1",
                    "status": "low_confidence",
                }
            },
            "candidate_hotspots": [],
        }
        manager = self._manager(payload)
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.35,
            current_gps_lon=27.20,
            image_geo_bounds={
                "top_left": {"lat": 37.40, "lon": 27.10},
                "bottom_right": {"lat": 37.30, "lon": 27.30},
                "control_points": [
                    {"pixel": {"x": 0.0, "y": 0.0}, "geo": {"lat": 37.40, "lon": 27.10}},
                    {"pixel": {"x": 399.0, "y": 0.0}, "geo": {"lat": 37.395, "lon": 27.30}},
                    {"pixel": {"x": 0.0, "y": 299.0}, "geo": {"lat": 37.30, "lon": 27.105}},
                ],
            },
            enrich_data=False,
        )
        self.assertIsNone(result["boat"]["boat_pixel_anchor"])
        self.assertEqual(result["boat"]["boat_anchor_source"], "gps_fallback")
        self.assertEqual(result["diagnostics"]["control_points_status"], "accepted")


if __name__ == "__main__":
    unittest.main()
