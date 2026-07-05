from __future__ import annotations

import unittest

from ai_assistant.context_builder import AiAssistantContextBuilder
from ai_assistant.models import LiveContextInputModel
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from tests.ai_assistant_fixtures import make_ai_config, sample_live_context, sample_request


class LiveContextInputModelTests(unittest.TestCase):
    def test_parses_full_payload(self) -> None:
        live = LiveContextInputModel.model_validate(
            {
                "current_lat": 37.1,
                "current_lon": 27.2,
                "gps_accuracy_m": 8.5,
                "live_score": 65,
                "rating": "fair",
                "reasoning": "Orta skor.",
                "nearest_hotspot": 3,
                "distance_to_nearest": 150.0,
                "bearing_to_nearest": 90.0,
                "coordinate_mode": "geo_referenced",
            }
        )
        self.assertEqual(live.nearest_hotspot, 3)
        self.assertEqual(live.live_score, 65)

    def test_ignores_unknown_extra_fields(self) -> None:
        live = LiveContextInputModel.model_validate(
            {"live_score": 50, "extra_field": "ignored", "flutter_only": True}
        )
        self.assertEqual(live.live_score, 50)


class LiveContextContextBuilderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.builder = AiAssistantContextBuilder()

    def test_live_context_summary_includes_nearest_fields(self) -> None:
        req = sample_request(
            scope="live_context",
            live_context=sample_live_context(),
        )
        ctx = self.builder.build(req)
        live = ctx["live_context"]
        self.assertIsNotNone(live)
        assert live is not None
        self.assertEqual(live["nearest_hotspot"], 10)
        self.assertEqual(live["distance_to_nearest"], 420.0)
        self.assertEqual(live["bearing_to_nearest"], 85.0)
        self.assertEqual(live["live_score"], 72)
        self.assertEqual(live["rating"], "good")

    def test_image_space_adds_warning(self) -> None:
        req = sample_request(
            scope="live_context",
            coordinate_mode="geo_referenced",
            live_context=sample_live_context(coordinate_mode="image_space"),
        )
        ctx = self.builder.build(req)
        warnings = ctx["live_context_warnings"]
        self.assertTrue(any("image_space" in w for w in warnings))

    def test_matched_nearest_hotspot_id(self) -> None:
        req = sample_request(
            scope="live_context",
            live_context=sample_live_context(nearest_hotspot=10),
        )
        ctx = self.builder.build(req)
        self.assertEqual(ctx["matched_nearest_hotspot_id"], 10)

    def test_live_context_prioritizes_nearest_hotspot(self) -> None:
        req = sample_request(
            scope="live_context",
            live_context=sample_live_context(nearest_hotspot=3),
        )
        ctx = self.builder.build(req)
        self.assertEqual(ctx["hotspots"][0]["id"], 3)


class LiveContextPromptBuilderTests(unittest.TestCase):
    def test_live_context_task_covers_navigation_guidance(self) -> None:
        builder = AiAssistantPromptBuilder(make_ai_config())
        context = {
            "scope": "live_context",
            "live_context": {"nearest_hotspot": 10, "live_score": 70, "rating": "good"},
            "live_context_warnings": ["GPS düşük"],
            "matched_nearest_hotspot_id": 10,
            "hotspots": [],
        }
        bundle = builder.build(context)
        self.assertIn("live_context", bundle.user_prompt)
        self.assertIn("En yakın hotspot", bundle.user_prompt)
        self.assertIn("kesin", bundle.system_prompt.lower())


if __name__ == "__main__":
    unittest.main()
