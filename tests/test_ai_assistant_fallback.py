from __future__ import annotations

import unittest

from ai_assistant.fallback import AiAssistantFallbackBuilder
from tests.ai_assistant_fixtures import sample_request


class AiAssistantFallbackTests(unittest.TestCase):
    def test_uses_session_advice_in_summary(self) -> None:
        req = sample_request()
        out = AiAssistantFallbackBuilder().build(
            req,
            prompt_version="v1",
            reason="test",
            processing_ms=5,
        )
        self.assertEqual(out.source, "fallback")
        self.assertIn("Nokta #10", out.summary_tr)
        self.assertGreaterEqual(len(out.recommended_actions), 1)
        self.assertGreaterEqual(len(out.hotspot_insights), 1)

    def test_species_comment_from_species_match(self) -> None:
        req = sample_request()
        out = AiAssistantFallbackBuilder().build(
            req,
            prompt_version="v1",
            reason="test",
            processing_ms=1,
        )
        self.assertIn("Dicentrarchus", out.species_comment_tr)

    def test_image_space_adds_limitation(self) -> None:
        req = sample_request(coordinate_mode="image_space")
        out = AiAssistantFallbackBuilder().build(
            req,
            prompt_version="v1",
            reason="test",
            processing_ms=1,
        )
        joined = " ".join(out.limitations_tr).lower()
        self.assertIn("fotoğraf", joined)


if __name__ == "__main__":
    unittest.main()
