from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import cv2
import numpy as np

from bathymetry_analyzer import BathymetryAnalyzer, HotspotThresholds


class BathymetryIntegrationTests(unittest.TestCase):
    def test_synthetic_chart_generates_water_hotspots_with_contract_fields(self) -> None:
        h, w = 240, 320
        image = np.zeros((h, w, 3), dtype=np.uint8)

        # Water background
        image[:, :] = (190, 90, 45)

        # Land region (yellow/tan) at the top
        image[0:55, :] = (120, 210, 230)

        # Dense contour cluster in water
        center = (220, 170)
        for radius in range(16, 70, 8):
            cv2.ellipse(image, center, (radius, int(radius * 0.65)), 12, 0, 360, (20, 20, 20), 2)

        # Additional contour-like transitions in another water region
        for y in range(110, 220, 14):
            cv2.line(image, (50, y), (150, y - 20), (0, 0, 180), 2)

        analyzer = BathymetryAnalyzer(
            max_hotspots=20,
            thresholds=HotspotThresholds(
                min_score=0.20,
                class_a=0.70,
                class_b=0.50,
                min_contour_density=0.03,
                min_coast_distance_px=2.0,
            ),
        )
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            cv2.imwrite(str(tmp_path), image)
            result = analyzer.analyze_chart(str(tmp_path))
        finally:
            if tmp_path.exists():
                tmp_path.unlink()

        hotspots = result.get("candidate_hotspots", [])
        self.assertTrue(hotspots, "Expected at least one hotspot on synthetic contour chart.")

        for hotspot in hotspots:
            self.assertIn("score", hotspot)
            self.assertIn("classification", hotspot)
            self.assertIn("reasoning", hotspot)
            self.assertIn("metrics", hotspot)
            y = float(hotspot["pixel_centroid"]["y"])
            # Land occupies top rows; hotspots must remain in water
            self.assertGreaterEqual(y, 55.0)


if __name__ == "__main__":
    unittest.main()
