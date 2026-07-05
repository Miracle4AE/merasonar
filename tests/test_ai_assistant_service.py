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


class AiAssistantServiceTests(unittest.TestCase):
    def test_ai_success_returns_structured_response(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "ai")
        self.assertEqual(out.model, "test-model")
        self.assertFalse(out.cache_hit)
        self.assertEqual(mock.calls, 1)

    def test_parse_failure_retries_then_fallback(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json(), fail_times=2)
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "fallback")
        self.assertEqual(mock.calls, 2)
        self.assertEqual(out.fallback_reason, "upstream_failure")

    def test_disabled_returns_fallback_without_openai(self) -> None:
        cfg = make_ai_config(enabled=False)
        service = build_ai_assistant_service(
            cfg,
            openai_client=None,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "fallback")
        self.assertEqual(out.fallback_reason, "ai_assistant_disabled")

    def test_cache_prevents_second_openai_call(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        service = build_ai_assistant_service(cfg, openai_client=mock, cache=cache)
        req = sample_request()
        first = service.handle(req, client_identity=default_client_identity())
        second = service.handle(req, client_identity=default_client_identity())
        self.assertEqual(first.source, "ai")
        self.assertEqual(second.source, "ai")
        self.assertTrue(second.cache_hit)
        self.assertEqual(mock.calls, 1)

    def test_streaming_enabled_falls_back_in_phase_1(self) -> None:
        cfg = make_ai_config(streaming=True)
        mock = MockOpenAIResponsesClient(sample_structured_json())
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.source, "fallback")
        self.assertEqual(out.fallback_reason, "streaming_not_implemented_in_phase_1")
        self.assertEqual(mock.calls, 0)


if __name__ == "__main__":
    unittest.main()
