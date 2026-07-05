from __future__ import annotations

import importlib
import json
import sys
import types
from unittest.mock import patch

__test__ = False


def _install_lightweight_stubs() -> None:
    # Keep optional dependency stubs local to direct execution so pytest
    # collection never pollutes sys.modules for the real test suite.
    if "cv2" not in sys.modules:
        sys.modules["cv2"] = types.ModuleType("cv2")

    if "scipy" not in sys.modules:
        scipy_module = types.ModuleType("scipy")
        ndimage_module = types.ModuleType("scipy.ndimage")
        spatial_module = types.ModuleType("scipy.spatial")

        class _DummyKDTree:
            def __init__(self, *args, **kwargs):
                pass

        spatial_module.cKDTree = _DummyKDTree
        scipy_module.ndimage = ndimage_module
        scipy_module.spatial = spatial_module
        sys.modules["scipy"] = scipy_module
        sys.modules["scipy.ndimage"] = ndimage_module
        sys.modules["scipy.spatial"] = spatial_module


def _load_runtime_dependencies():
    try:
        bathymetry_module = importlib.import_module("bathymetry_analyzer")
        geo_module = importlib.import_module("geo_navigation")
        marine_module = importlib.import_module("marine_data_client")
        orchestrator_module = importlib.import_module("maritime_orchestrator")
    except ModuleNotFoundError:
        _install_lightweight_stubs()
        bathymetry_module = importlib.import_module("bathymetry_analyzer")
        geo_module = importlib.import_module("geo_navigation")
        marine_module = importlib.import_module("marine_data_client")
        orchestrator_module = importlib.import_module("maritime_orchestrator")

    return (
        bathymetry_module.BathymetryAnalyzer,
        geo_module.CoordinateMapper,
        geo_module.GeoPoint,
        geo_module.PrecisionGPS,
        marine_module.MarineDataClient,
        orchestrator_module.FishingHotspotManager,
    )


def _mock_analysis_output(image_path: str):
    return {
        "image_path": image_path,
        "image_size": {"width": 1080, "height": 1920},
        "counts": {
            "drop_offs": 1,
            "ridges_spurs": 0,
            "basins_bowls": 1,
            "shelves": 0,
        },
        "features": {
            "drop_offs": [
                {
                    "type": "drop_off",
                    "bbox": {"x": 380, "y": 480, "width": 40, "height": 40},
                    "centroid": {"x": 400.0, "y": 500.0},
                    "area_px": 120,
                }
            ],
            "ridges_spurs": [],
            "basins_bowls": [
                {
                    "type": "basin_bowl",
                    "bbox": {"x": 580, "y": 780, "width": 40, "height": 40},
                    "centroid": {"x": 600.0, "y": 800.0},
                    "area_px": 150,
                }
            ],
            "shelves": [],
        },
        "diagnostics": {
            "contours_total": 2,
            "contour_pixels": 300,
            "sampled_points": 0,
            "mean_cross_contour_distance": 0.0,
        },
    }


def main() -> None:
    (
        BathymetryAnalyzer,
        CoordinateMapper,
        GeoPoint,
        PrecisionGPS,
        MarineDataClient,
        FishingHotspotManager,
    ) = _load_runtime_dependencies()

    analyzer = BathymetryAnalyzer()
    mapper = CoordinateMapper(
        image_width=2,
        image_height=2,
        top_left=GeoPoint(lat=1.0, lon=1.0),
        bottom_right=GeoPoint(lat=0.0, lon=2.0),
    )
    gps = PrecisionGPS()
    marine_client = MarineDataClient(timeout_seconds=10.0, max_retries=2, backoff_factor=0.3)

    manager = FishingHotspotManager(
        bathymetry_analyzer=analyzer,
        coordinate_mapper=mapper,
        precision_gps=gps,
        marine_data_client=marine_client,
    )

    bounds = {
        "top_left": {"lat": 37.39, "lon": 27.23},
        "bottom_right": {"lat": 37.37, "lon": 27.26},
    }

    with patch.object(BathymetryAnalyzer, "analyze_chart", side_effect=_mock_analysis_output):
        result = manager.process_new_chart_and_state(
            image_path="mock_chart.jpg",
            current_gps_lat=37.3820,
            current_gps_lon=27.2450,
            image_geo_bounds=bounds,
            enrich_data=True,
        )

    print(json.dumps(result, indent=4, ensure_ascii=False))


if __name__ == "__main__":
    main()
