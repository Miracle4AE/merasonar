from __future__ import annotations

import unittest

from ai_assistant.context_builder import AiAssistantContextBuilder
from tests.ai_assistant_fixtures import sample_request


class AiAssistantContextBuilderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.builder = AiAssistantContextBuilder()

    def test_limits_hotspots_to_fifteen(self) -> None:
        req = sample_request()
        req.analysis.hotspots.extend(
            [
                type(req.analysis.hotspots[0])(
                    id=100 + i,
                    classification="C",
                    score=0.2,
                    feature_type="flat",
                    recommendation_rank=20 + i,
                )
                for i in range(20)
            ]
        )
        ctx = self.builder.build(req)
        self.assertLessEqual(len(ctx["hotspots"]), 15)

    def test_image_space_strips_coordinates(self) -> None:
        req = sample_request(coordinate_mode="image_space")
        ctx = self.builder.build(req)
        for hs in ctx["hotspots"]:
            self.assertNotIn("latitude", hs)
            self.assertNotIn("longitude", hs)

    def test_fingerprint_stable_for_same_input(self) -> None:
        req = sample_request()
        a = self.builder.build_fingerprint(req, prompt_version="v1")
        b = self.builder.build_fingerprint(req, prompt_version="v1")
        self.assertEqual(a, b)

    def test_fingerprint_changes_with_prompt_version(self) -> None:
        req = sample_request()
        a = self.builder.build_fingerprint(req, prompt_version="v1")
        b = self.builder.build_fingerprint(req, prompt_version="v2")
        self.assertNotEqual(a, b)

    def test_hotspot_detail_focuses_single_hotspot(self) -> None:
        req = sample_request(scope="hotspot_detail", focus_id=3)
        ctx = self.builder.build(req)
        self.assertEqual(len(ctx["hotspots"]), 1)
        self.assertEqual(ctx["hotspots"][0]["id"], 3)


if __name__ == "__main__":
    unittest.main()
