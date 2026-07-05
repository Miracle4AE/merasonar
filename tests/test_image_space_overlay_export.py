from __future__ import annotations

import json
import unittest
from pathlib import Path

import cv2
import numpy as np


class ImageSpaceOverlayExportTests(unittest.TestCase):
    def test_export_writes_labeled_and_clean_png(self) -> None:
        import tempfile

        from image_space_overlay_export import export_image_space_overlay_from_response

        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            chart = td / "c.png"
            img = np.zeros((200, 300, 3), dtype=np.uint8)
            img[:, :] = (40, 40, 40)
            cv2.imwrite(str(chart), img)
            payload = {
                "image_size": {"width": 300, "height": 200},
                "ranked_hotspots": [
                    {
                        "classification": "A",
                        "rank": 1,
                        "score": 0.9,
                        "pixel_centroid": {"x": 50.0, "y": 60.0},
                    },
                    {
                        "classification": "B",
                        "rank": 2,
                        "score": 0.5,
                        "pixel_centroid": {"x": 200.0, "y": 100.0},
                    },
                    {
                        "classification": "C",
                        "rank": 3,
                        "score": 0.25,
                        "pixel_centroid": {"x": 150.0, "y": 150.0},
                    },
                ],
            }
            out = td / "o.png"
            paths = export_image_space_overlay_from_response(chart, payload, out)
            self.assertIn("labeled", paths)
            self.assertIn("clean", paths)
            self.assertTrue(Path(paths["labeled"]).is_file())
            self.assertTrue(paths["clean"])
            self.assertTrue(Path(paths["clean"]).is_file())
            read = cv2.imread(paths["labeled"], cv2.IMREAD_COLOR)
            self.assertEqual(read.shape, (200, 300, 3))

    def test_cli_loads_json_via_helper(self) -> None:
        import tempfile

        from image_space_overlay_export import export_image_space_overlay

        with tempfile.TemporaryDirectory() as tmp:
            td = Path(tmp)
            chart = td / "chart.png"
            cv2.imwrite(str(chart), np.zeros((50, 80, 3), dtype=np.uint8))
            jpath = td / "r.json"
            jpath.write_text(
                json.dumps(
                    {
                        "image_size": {"width": 80, "height": 50},
                        "ranked_hotspots": [
                            {
                                "classification": "A",
                                "rank": 1,
                                "score": 1.0,
                                "pixel_centroid": {"x": 10.0, "y": 20.0},
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            outp = td / "out.png"
            paths = export_image_space_overlay(str(chart), str(jpath), str(outp))
            self.assertEqual(paths["labeled"], str(outp.resolve()))


if __name__ == "__main__":
    unittest.main()
