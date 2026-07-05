from __future__ import annotations

import unittest

from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.dependencies import build_ai_assistant_service
from tests.ai_assistant_fixtures import (
    MockOpenAIResponsesClient,
    default_client_identity,
    sample_request,
    sample_structured_json,
    make_ai_config,
)


class AiAssistantCostGuardTests(unittest.TestCase):
    def test_cost_guard_blocks_openai_and_returns_fallback(self) -> None:
        cfg = make_ai_config()
        cfg = cfg.__class__(
            **{
                **cfg.__dict__,
                "ai_max_estimated_cost_per_request_usd": 0.000001,
                "cost_input_per_1m": 10.0,
                "cost_output_per_1m": 10.0,
            }
        )
        mock = MockOpenAIResponsesClient(sample_structured_json())
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "fallback")
        self.assertEqual(out.fallback_reason, "cost_guard_exceeded")
        self.assertEqual(mock.calls, 0)
        self.assertIsNotNone(out.telemetry)
        assert out.telemetry is not None
        self.assertEqual(out.telemetry.fallback_reason, "cost_guard_exceeded")

    def test_cost_guard_disabled_when_threshold_zero(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "ai")
        self.assertEqual(mock.calls, 1)


if __name__ == "__main__":
    unittest.main()
