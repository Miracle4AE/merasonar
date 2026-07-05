from __future__ import annotations

import unittest

from fishing_reasoning_text import build_hotspot_reasoning_text, apply_reasoning_text_to_hotspots


class FishingReasoningTextTests(unittest.TestCase):
    def test_variation_by_hotspot_id(self) -> None:
        m = {
            "contour_density": 0.8,
            "slope": 0.6,
            "dropoff_proximity": 0.7,
            "transition_band": 0.5,
            "structure_score": 0.4,
        }
        a = build_hotspot_reasoning_text(
            metrics=m,
            classification="A",
            hotspot_id=1,
            rank=1,
            nearby_peer_count=0,
        )
        b = build_hotspot_reasoning_text(
            metrics=m,
            classification="A",
            hotspot_id=2,
            rank=1,
            nearby_peer_count=0,
        )
        self.assertNotEqual(a, b)

    def test_class_tone_c_more_hedged_than_a(self) -> None:
        m = {"contour_density": 0.5, "slope": 0.5, "dropoff_proximity": 0.5, "transition_band": 0.5}
        ta = build_hotspot_reasoning_text(
            metrics=m, classification="A", hotspot_id=9, rank=3, nearby_peer_count=0
        )
        tc = build_hotspot_reasoning_text(
            metrics=m, classification="C", hotspot_id=9, rank=3, nearby_peer_count=0
        )
        tl = tc.lower()
        self.assertTrue(
            any(k in tl for k in ("düşük", "deneme", "belirsiz", "keşif", "olmay")),
            msg=tc,
        )
        tal = ta.lower()
        self.assertTrue(
            any(
                k in tal
                for k in ("güçlü", "öncelik", "ciddi", "durak", "şans")
            ),
            msg=ta,
        )

    def test_apply_sets_reasoning_text(self) -> None:
        hotspots = [
            {
                "id": 0,
                "rank": 1,
                "classification": "A",
                "pixel_centroid": {"x": 10.0, "y": 10.0},
                "supporting_metrics": {"contour_density": 0.9},
            },
            {
                "id": 1,
                "rank": 2,
                "classification": "B",
                "pixel_centroid": {"x": 11.0, "y": 10.0},
                "supporting_metrics": {"contour_density": 0.8},
            },
        ]
        apply_reasoning_text_to_hotspots(hotspots, 200, 200)
        self.assertIn("reasoning_text", hotspots[0])
        self.assertTrue(len(hotspots[0]["reasoning_text"]) > 20)
        self.assertIn("fish_prediction", hotspots[0])
        self.assertGreater(len(hotspots[0]["fish_prediction"]), 12)


if __name__ == "__main__":
    unittest.main()
