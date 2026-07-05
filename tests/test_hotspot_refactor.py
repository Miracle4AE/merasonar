from __future__ import annotations

import unittest

import numpy as np

from bathymetry_analyzer import BathymetryAnalyzer, HotspotThresholds


class BathymetryRefactorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analyzer = BathymetryAnalyzer(
            suppression_radius_px=6.0,
            peak_window_size=9,
            thresholds=HotspotThresholds(
                min_score=0.35,
                class_a=0.75,
                class_b=0.58,
                min_contour_density=0.06,
                min_coast_distance_px=4.0,
            ),
        )

    @staticmethod
    def _feature_maps(shape: tuple[int, int]) -> dict[str, np.ndarray]:
        zeros = np.zeros(shape, dtype=np.float32)
        return {
            "pseudo_depth": zeros.copy(),
            "contour_density": zeros.copy(),
            "slope": zeros.copy(),
            "local_relief": zeros.copy(),
            "dropoff_proximity": zeros.copy(),
            "basin_likelihood": zeros.copy(),
            "ridge_likelihood": zeros.copy(),
            "transition_band": zeros.copy(),
            "flat_penalty": zeros.copy(),
            "invalid_region_penalty": zeros.copy(),
            "coast_distance": zeros.copy(),
            "land_distance": np.full(shape, 50.0, dtype=np.float32),
            "water_confidence": np.ones(shape, dtype=np.float32),
        }

    def test_flat_areas_score_low(self) -> None:
        shape = (48, 48)
        water_mask = np.full(shape, 255, dtype=np.uint8)
        maps = self._feature_maps(shape)
        maps["flat_penalty"][:, :] = 1.0
        maps["invalid_region_penalty"][:, :] = 0.6

        score = self.analyzer._compute_score_map(maps, water_mask)
        self.assertLess(float(score.max()), 0.2)

    def test_strong_dropoffs_score_high(self) -> None:
        shape = (48, 48)
        water_mask = np.full(shape, 255, dtype=np.uint8)
        maps = self._feature_maps(shape)

        y, x = 24, 24
        maps["slope"][y, x] = 1.0
        maps["contour_density"][y, x] = 0.95
        maps["dropoff_proximity"][y, x] = 1.0
        maps["ridge_likelihood"][y, x] = 0.85
        maps["transition_band"][y, x] = 0.9
        maps["flat_penalty"][y, x] = 0.05
        maps["invalid_region_penalty"][y, x] = 0.05

        score = self.analyzer._compute_score_map(maps, water_mask)
        self.assertGreater(float(score[y, x]), 0.75)

    def test_land_points_are_rejected(self) -> None:
        shape = (64, 64)
        water_mask = np.full(shape, 255, dtype=np.uint8)
        land_mask = np.zeros(shape, dtype=np.uint8)
        coastline_mask = np.zeros(shape, dtype=np.uint8)
        score = np.zeros(shape, dtype=np.float32)
        maps = self._feature_maps(shape)

        good_y, good_x = 35, 35
        land_y, land_x = 20, 20
        for y, x in ((good_y, good_x), (land_y, land_x)):
            score[y, x] = 0.9
            maps["contour_density"][y, x] = 0.8
            maps["coast_distance"][y, x] = 12.0
            maps["slope"][y, x] = 0.8
            maps["dropoff_proximity"][y, x] = 0.9
            maps["transition_band"][y, x] = 0.75
            maps["ridge_likelihood"][y, x] = 0.7

        land_mask[land_y, land_x] = 255
        water_mask[land_y, land_x] = 0

        candidates, _stats = self.analyzer._extract_hotspot_candidates(
            score_map=score,
            feature_maps=maps,
            water_mask=water_mask,
            land_mask=land_mask,
            coastline_mask=coastline_mask,
        )

        coords = {(int(c["pixel_centroid"]["y"]), int(c["pixel_centroid"]["x"])) for c in candidates}
        self.assertIn((good_y, good_x), coords)
        self.assertNotIn((land_y, land_x), coords)

    def test_nearby_duplicates_are_suppressed(self) -> None:
        shape = (80, 80)
        water_mask = np.full(shape, 255, dtype=np.uint8)
        land_mask = np.zeros(shape, dtype=np.uint8)
        coastline_mask = np.zeros(shape, dtype=np.uint8)
        score = np.zeros(shape, dtype=np.float32)
        maps = self._feature_maps(shape)

        peaks = [
            (30, 30, 0.95),
            (33, 33, 0.92),
            (60, 60, 0.90),
        ]
        for y, x, s in peaks:
            score[y, x] = s
            maps["contour_density"][y, x] = 0.85
            maps["coast_distance"][y, x] = 16.0
            maps["slope"][y, x] = 0.85
            maps["dropoff_proximity"][y, x] = 0.88
            maps["transition_band"][y, x] = 0.70
            maps["ridge_likelihood"][y, x] = 0.75

        candidates, _stats = self.analyzer._extract_hotspot_candidates(
            score_map=score,
            feature_maps=maps,
            water_mask=water_mask,
            land_mask=land_mask,
            coastline_mask=coastline_mask,
        )

        coords = {(int(c["pixel_centroid"]["y"]), int(c["pixel_centroid"]["x"])) for c in candidates}
        self.assertIn((30, 30), coords)
        self.assertIn((60, 60), coords)
        self.assertNotIn((33, 33), coords)


if __name__ == "__main__":
    unittest.main()
