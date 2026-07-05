import unittest

from fishing_recommendation_ranking import attach_fishing_recommendation_metrics


class FishingRecommendationRankingTests(unittest.TestCase):
    def test_boosts_cluster_and_class_a_rank(self) -> None:
        h0 = _hs(
            0,
            score=0.62,
            classification="A",
            px=(100.0, 100.0),
            species=[{"confidence": "high"}, {"confidence": "low"}],
        )
        h1 = _hs(
            1,
            score=0.55,
            classification="C",
            px=(118.0, 105.0),
            species=[],
        )
        hotspots = [h1, h0]
        tops = attach_fishing_recommendation_metrics(hotspots, width=1000, height=800)

        ranks = {int(h["id"]): int(h["recommendation_rank"]) for h in hotspots}
        scores = {int(h["id"]): int(h["final_fishing_score"]) for h in hotspots}

        self.assertEqual(ranks[0], 1)
        self.assertLessEqual(len(tops), 5)
        self.assertGreater(scores[0], scores[1])


def _hs(
    hid: int,
    *,
    score: float,
    classification: str,
    px: tuple[float, float],
    species,
) -> dict:
    return {
        "id": hid,
        "score": score,
        "classification": classification,
        "species_match": species,
        "pixel_centroid": {"x": px[0], "y": px[1]},
        "hotspot_pixel_anchor": {"x": px[0], "y": px[1]},
    }


if __name__ == "__main__":
    unittest.main()
