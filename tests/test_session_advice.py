import re
import unittest

from session_advice import build_session_advice


class SessionAdviceTests(unittest.TestCase):
    def test_two_hotspots_three_sentences_references_priority(self) -> None:
        hs = [
            _h(10, "drop_off", {}, 1),
            _h(20, "ridge_spur", {}, 2),
            _h(30, "shelf", {}, 3),
        ]
        txt = build_session_advice(hs, [10, 20])
        sentences = [s.strip() for s in re.findall(r"[^.!?]+[.!?]", txt) if s.strip()]
        self.assertGreaterEqual(len(sentences), 1)
        self.assertLessEqual(len(sentences), 3)
        low = txt.lower()
        self.assertIn("nokta #1", low)
        self.assertIn("nokta #2", low)
        self.assertNotIn("guaranteed", low)

    def test_empty_hotspots_short_copy(self) -> None:
        txt = build_session_advice([], [1, 2])
        self.assertGreater(len(txt), 24)


def _h(
    hid: int,
    ft: str,
    metrics: dict,
    rec_rank: int,
) -> dict:
    return {
        "id": hid,
        "feature_type": ft,
        "supporting_metrics": metrics,
        "recommendation_rank": rec_rank,
    }


if __name__ == "__main__":
    unittest.main()
