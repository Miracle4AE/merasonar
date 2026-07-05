from __future__ import annotations

import unittest
from typing import Any, Dict, List, Tuple

from geo_navigation import PrecisionGPS
from maritime_orchestrator import FishingHotspotManager


class _FakeAnalyzer:
    def __init__(self, payload: Dict[str, Any]) -> None:
        self._payload = payload

    def analyze_chart(self, image_path: str) -> Dict[str, Any]:
        return self._payload


class _TrackingMarine:
    def __init__(self) -> None:
        self.calls: List[Tuple[str, float, float]] = []

    def get_sea_state(self, lat: float, lon: float) -> Dict[str, Any]:
        self.calls.append(("sea_state", lat, lon))
        return {
            "wave_height_m": 0.4,
            "water_temperature_c": 18.0,
            "wind_speed_knots": 10.0,
            "wind_direction_deg": 90.0,
            "current_speed_knots": 0.5,
            "current_direction_deg": 180.0,
            "pressure_hpa": 1013.0,
            "ocean_current_velocity_mps": 0.1,
            "source": "test_marine",
            "fallback": False,
            "simulated_components": [],
        }

    def get_bathymetry_depth(self, lat: float, lon: float) -> Dict[str, Any]:
        self.calls.append(("depth", lat, lon))
        return {"depth_m": 50.0, "source": "should_not_run"}

    def get_marine_biodiversity(self, lat: float, lon: float, radius_km: float = 5.0) -> Dict[str, Any]:
        self.calls.append(("biodiversity", lat, lon))
        return {"top_species": [], "source": "should_not_run"}


class ImageSpaceEnrichmentTests(unittest.TestCase):
    def _base_candidate_payload(self) -> Dict[str, Any]:
        return {
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

    def test_image_space_with_gps_fetches_only_sea_state(self) -> None:
        marine = _TrackingMarine()
        payload_empty_candidates = {
            "image_size": {"width": 400, "height": 300},
            "features": {},
            "counts": {},
            "diagnostics": {},
            "candidate_hotspots": [],
        }
        manager = FishingHotspotManager(
            bathymetry_analyzer=_FakeAnalyzer(payload_empty_candidates),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=marine,
        )
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=37.4,
            current_gps_lon=27.25,
            image_geo_bounds={"control_points": []},
            enrich_data=True,
        )
        self.assertEqual(result.get("coordinate_mode"), "image_space")
        sea_calls = [c for c in marine.calls if c[0] == "sea_state"]
        depth_calls = [c for c in marine.calls if c[0] == "depth"]
        bio_calls = [c for c in marine.calls if c[0] == "biodiversity"]
        self.assertEqual(len(sea_calls), 1)
        self.assertEqual(len(depth_calls), 0)
        self.assertEqual(len(bio_calls), 0)
        self.assertEqual(len(result["hotspots"]), 0)
        self.assertIn("raw_gps", result["boat"])
        self.assertIn("smoothed_gps", result["boat"])
        detail = result["diagnostics"].get("image_space_enrichment_detail")
        self.assertIsInstance(detail, str)
        self.assertIn("kalibre", detail.lower())

    def test_image_space_zero_gps_skips_external_marine(self) -> None:
        marine = _TrackingMarine()
        manager = FishingHotspotManager(
            bathymetry_analyzer=_FakeAnalyzer(self._base_candidate_payload()),
            coordinate_mapper=None,
            precision_gps=PrecisionGPS(),
            marine_data_client=marine,
        )
        result = manager.process_new_chart_and_state(
            image_path="chart.png",
            current_gps_lat=0.0,
            current_gps_lon=0.0,
            image_geo_bounds={"control_points": []},
            enrich_data=True,
        )
        self.assertEqual(marine.calls, [])
        hs = result["hotspots"][0]
        self.assertEqual(hs["sea_state"]["source"], "requires_gps_or_server")


if __name__ == "__main__":
    unittest.main()
