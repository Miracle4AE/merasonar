"""Tests for /api/v1/live_fishing_score computation."""

import unittest

from live_fishing_score import compute_live_fishing_score


def _hk(
    hid: int,
    lat: float,
    lon: float,
    *,
    rr: int = 99,
) -> dict:
    return {
        "id": hid,
        "latitude": lat,
        "longitude": lon,
        "recommendation_rank": rr,
    }


class LiveFishingScoreApiTests(unittest.TestCase):
    def test_image_space_has_no_nearest_and_explains_calibration(self) -> None:
        out = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "image_space",
                "latest_hotspots": [_hk(1, 37.001, 27.001, rr=1)],
            }
        )
        self.assertIsNone(out["nearest_hotspot"])
        self.assertIn("kalibre harita", out["reasoning"].lower())
        self.assertLessEqual(out["live_score"], 55)
        self.assertGreaterEqual(out["live_score"], 40)

    def test_unknown_mode_no_hotspot_distance_even_if_close(self) -> None:
        out = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "unknown",
                "latest_hotspots": [_hk(1, 37.0001, 27.0001, rr=1)],
            }
        )
        self.assertIsNone(out["nearest_hotspot"])
        self.assertIn("kalibre harita", out["reasoning"].lower())

    def test_omitted_coordinate_mode_never_computes_hotspot_distance(self) -> None:
        out = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "latest_hotspots": [_hk(1, 37.0001, 27.0001, rr=1)],
            }
        )
        self.assertIsNone(out["nearest_hotspot"])

    def test_valid_geo_finds_nearest_distance(self) -> None:
        out = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "geo_referenced",
                "latest_hotspots": [
                    _hk(1, 37.0001, 27.0001, rr=1),
                    _hk(2, 38.0, 28.0, rr=2),
                ],
            }
        )
        self.assertIsNotNone(out["nearest_hotspot"])
        nh = out["nearest_hotspot"]
        assert nh is not None
        self.assertEqual(nh["id"], 1)
        self.assertLess(nh["distance_m"], 200.0)

    def test_poor_gps_accuracy_lowers_score_vs_good(self) -> None:
        base = {
            "current_lat": 37.0,
            "current_lon": 27.0,
            "coordinate_mode": "geo_referenced",
            "latest_hotspots": [],
        }
        good = compute_live_fishing_score({**base, "gps_accuracy_m": 10.0})
        poor = compute_live_fishing_score({**base, "gps_accuracy_m": 60.0})
        self.assertGreater(good["live_score"], poor["live_score"])

    def test_top_rank_nearby_boosts_score(self) -> None:
        far = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "geo_referenced",
                "gps_accuracy_m": 20.0,
                "latest_hotspots": [_hk(9, 40.0, 30.0, rr=1)],
            }
        )
        near = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "geo_referenced",
                "gps_accuracy_m": 20.0,
                "latest_hotspots": [_hk(9, 37.0002, 27.0002, rr=1)],
            }
        )
        self.assertGreater(near["live_score"], far["live_score"])

    def test_score_clamped_0_to_100(self) -> None:
        out = compute_live_fishing_score(
            {
                "current_lat": 37.0,
                "current_lon": 27.0,
                "coordinate_mode": "geo_referenced",
                "gps_accuracy_m": 12.0,
                "latest_hotspots": [_hk(1, 37.00001, 27.00001, rr=1)],
            }
        )
        self.assertGreaterEqual(out["live_score"], 0)
        self.assertLessEqual(out["live_score"], 100)

    def test_trust_note_constant(self) -> None:
        out = compute_live_fishing_score({"current_lat": 0.0, "current_lon": 20.0, "coordinate_mode": "geo_referenced"})
        self.assertIn("olasılıksal", out["trust_note"].lower())


if __name__ == "__main__":
    unittest.main()
