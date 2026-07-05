from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import cv2
import numpy as np

from bathymetry_analyzer import BathymetryAnalyzer


class BoatAnchorDetectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analyzer = BathymetryAnalyzer(max_hotspots=5)

    def _analyze_array(self, image: np.ndarray) -> dict:
        with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
            path = Path(tmp.name)
        try:
            cv2.imwrite(str(path), image)
            return self.analyzer.analyze_chart(str(path))
        finally:
            if path.exists():
                path.unlink()

    def test_detects_visible_boat_marker_on_water(self) -> None:
        h, w = 260, 360
        image = np.zeros((h, w, 3), dtype=np.uint8)
        image[:, :] = (190, 90, 45)  # water-like base
        image[0:45, :] = (120, 210, 230)  # land band
        cv2.circle(image, (190, 150), 6, (0, 0, 255), -1)  # vivid marker on water

        result = self._analyze_array(image)
        detection = result['diagnostics']['boat_anchor_detection']

        self.assertEqual(detection['status'], 'detected')
        self.assertGreaterEqual(float(detection['anchor_confidence']), 0.45)
        self.assertIsInstance(detection['boat_pixel_anchor'], dict)

    def test_returns_not_found_when_no_marker_exists(self) -> None:
        h, w = 260, 360
        image = np.zeros((h, w, 3), dtype=np.uint8)
        image[:, :] = (190, 90, 45)
        image[0:45, :] = (120, 210, 230)

        result = self._analyze_array(image)
        detection = result['diagnostics']['boat_anchor_detection']

        self.assertEqual(detection['status'], 'not_found')
        self.assertIsNone(detection['boat_pixel_anchor'])
        self.assertEqual(float(detection['anchor_confidence']), 0.0)

    def test_low_confidence_marker_falls_back(self) -> None:
        h, w = 260, 360
        image = np.zeros((h, w, 3), dtype=np.uint8)
        image[:, :] = (190, 90, 45)
        image[0:45, :] = (120, 210, 230)
        # Tiny, edge-near marker yields low confidence by design.
        cv2.circle(image, (w - 5, h - 5), 2, (255, 255, 255), -1)

        result = self._analyze_array(image)
        detection = result['diagnostics']['boat_anchor_detection']

        self.assertEqual(detection['status'], 'low_confidence')
        self.assertIsNone(detection['boat_pixel_anchor'])
        self.assertLess(float(detection['anchor_confidence']), 0.45)


if __name__ == '__main__':
    unittest.main()
