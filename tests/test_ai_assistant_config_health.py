from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.config import AiAssistantConfig
from ai_assistant.dependencies import build_ai_assistant_service
from ai_assistant.openai_errors import classify_openai_failure, sanitize_log_message
from tests.ai_assistant_fixtures import (
    MockOpenAIResponsesClient,
    default_client_identity,
    sample_request,
    sample_structured_json,
    make_ai_config,
)


class AiAssistantConfigHealthTests(unittest.TestCase):
    def test_health_payload_includes_safe_runtime_fields(self) -> None:
        cfg = make_ai_config()
        payload = cfg.health_payload()
        self.assertTrue(payload["openai_key_present"])
        self.assertEqual(payload["openai_model"], "test-model")
        self.assertTrue(payload["ai_runtime_ready"])
        self.assertIn("timeout_seconds", payload)
        self.assertNotIn("openai_api_key", payload)

    def test_missing_key_reports_false(self) -> None:
        cfg = make_ai_config(api_key="")
        payload = cfg.health_payload()
        self.assertFalse(payload["openai_key_present"])
        self.assertFalse(payload["ai_runtime_ready"])

    def test_from_env_reads_openai_key_present(self) -> None:
        with patch.dict(
            os.environ,
            {
                "OPENAI_API_KEY": "test-key",
                "OPENAI_MODEL": "gpt-4o-mini",
                "AI_ASSISTANT_ENABLED": "true",
            },
            clear=False,
        ):
            cfg = AiAssistantConfig.from_env()
            self.assertTrue(cfg.is_openai_configured())
            self.assertTrue(cfg.health_payload()["openai_key_present"])


class AiAssistantFallbackReasonTests(unittest.TestCase):
    def test_disabled_reason(self) -> None:
        cfg = make_ai_config(enabled=False)
        service = build_ai_assistant_service(
            cfg,
            openai_client=None,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.fallback_reason, "ai_assistant_disabled")

    def test_missing_api_key_reason(self) -> None:
        cfg = make_ai_config(api_key="")
        service = build_ai_assistant_service(
            cfg,
            openai_client=None,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
        )
        out = service.handle(sample_request(), client_identity=default_client_identity())
        self.assertEqual(out.fallback_reason, "missing_api_key")

    def test_fallback_responses_are_not_cached(self) -> None:
        cfg = make_ai_config(enabled=False)
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        service = build_ai_assistant_service(cfg, openai_client=None, cache=cache)
        req = sample_request()
        first = service.handle(req, client_identity=default_client_identity())
        second = service.handle(req, client_identity=default_client_identity())
        self.assertEqual(first.source, "fallback")
        self.assertEqual(second.source, "fallback")
        self.assertFalse(second.cache_hit)

    def test_success_response_is_cached(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        service = build_ai_assistant_service(cfg, openai_client=mock, cache=cache)
        req = sample_request()
        first = service.handle(req, client_identity=default_client_identity())
        second = service.handle(req, client_identity=default_client_identity())
        self.assertEqual(first.source, "ai")
        self.assertTrue(second.cache_hit)
        self.assertEqual(mock.calls, 1)

    def test_force_refresh_bypasses_backend_cache(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        service = build_ai_assistant_service(cfg, openai_client=mock, cache=cache)
        req = sample_request()
        first = service.handle(req, client_identity=default_client_identity())
        refreshed = req.model_copy(update={"force_refresh": True})
        second = service.handle(refreshed, client_identity=default_client_identity())
        self.assertEqual(first.source, "ai")
        self.assertEqual(second.source, "ai")
        self.assertFalse(second.cache_hit)
        self.assertEqual(mock.calls, 2)


class OpenAiErrorSanitizationTests(unittest.TestCase):
    def test_sanitize_log_message_masks_key(self) -> None:
        msg = "Auth failed sk-proj-abc"
        cleaned = sanitize_log_message(msg)
        self.assertIn("sk-***", cleaned)
        self.assertNotIn("sk-proj-abc", cleaned)

    def test_classify_timeout(self) -> None:
        self.assertEqual(classify_openai_failure(TimeoutError("timed out")), "openai_timeout")

    def test_classify_schema_invalid(self) -> None:
        try:
            import httpx
            from openai import BadRequestError
        except ImportError:
            self.skipTest("openai SDK not installed")
        response = httpx.Response(
            400,
            request=httpx.Request("POST", "https://api.openai.com/v1/responses"),
        )
        exc = BadRequestError(
            "invalid schema",
            response=response,
            body={"error": {"code": "invalid_json_schema", "message": "Invalid schema"}},
        )
        self.assertEqual(classify_openai_failure(exc), "openai_schema_invalid")


if __name__ == "__main__":
    unittest.main()
