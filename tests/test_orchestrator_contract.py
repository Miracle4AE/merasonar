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


class OrchestratorContractTests(unittest.TestCase):
    def _manager(self, payload: Dict[str, Any]) -> FishingHotspotManager:
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
            marine_data_client=None,
        )

    def test_ranking_is_score_then_distance_and_proximity_rank_is_independent(self) -> None:
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
                },
                {
                    "pixel_centroid": {"x": 110.0, "y": 110.0},
                    "score": 0.92,
                    "classification": "A",
                    "reasoning": ["r2"],
                    "metrics": {"slope": 0.8},
                    "feature_type": "ridge_spur",
                },
            ],
        }
        manager = self._manager(payload)
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

        hotspots = result["ranked_hotspots"]
        self.assertGreaterEqual(hotspots[0]["score"], hotspots[1]["score"])
        self.assertIn("latitude", hotspots[0])
        self.assertIn("longitude", hotspots[0])
        self.assertIn("classification", hotspots[0])
        self.assertIn("reasoning", hotspots[0])
        self.assertIn("supporting_metrics", hotspots[0])
        self.assertEqual(hotspots[0]["rank"], 1)
        self.assertEqual(hotspots[0]["rank_by_score_then_distance"], 1)
        self.assertEqual(hotspots[0]["rank_overall"], 1)
        self.assertIn("hotspot_pixel_anchor", hotspots[0])
        self.assertIn("trust_state", hotspots[0])
        self.assertIn("is_renderable", hotspots[0])
        self.assertEqual(result["diagnostics"]["chart_reference_primary"], True)
        self.assertIn("mapping_trust_state", result["diagnostics"])
        self.assertIn("render_mode_recommendation", result["diagnostics"])
        # Top score hotspot can be farther from the boat; proximity rank is independent.
        self.assertGreater(hotspots[0]["distance_m"], hotspots[1]["distance_m"])
        self.assertEqual(hotspots[0]["rank_by_proximity"], 2)
        self.assertEqual(hotspots[1]["rank_by_proximity"], 1)

    def test_invalid_candidate_sequence_falls_back_to_features(self) -> None:
        payload = {
            "image_size": {"width": 200, "height": 200},
            "candidate_hotspots": "invalid-sequence",
            "features": {
                "drop_offs": [
                    {
                        "centroid": {"x": 80.0, "y": 90.0},
                        "bbox": {"x": 70, "y": 80, "width": 20, "height": 20},
                        "area_px": 120,
                    }
                ]
            },
            "counts": {},
            "diagnostics": {},
        }
        manager = self._manager(payload)
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

        hotspots = result["ranked_hotspots"]
        self.assertEqual(len(hotspots), 1)
        self.assertEqual(hotspots[0]["classification"], "C")


if __name__ == "__main__":
    unittest.main()
