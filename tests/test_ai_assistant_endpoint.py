from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

import main
from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.dependencies import build_ai_assistant_service
from ai_assistant.router import _get_ai_assistant_service
from tests.ai_assistant_fixtures import (
    MockOpenAIResponsesClient,
    sample_structured_json,
    make_ai_config,
)


def _sample_body() -> dict:
    return {
        "scope": "session_summary",
        "locale": "tr",
        "analysis": {
            "coordinate_mode": "geo_referenced",
            "session_advice": "Önce Nokta #10.",
            "top_recommendations": [10],
            "hotspots": [
                {
                    "id": 10,
                    "classification": "A",
                    "score": 0.8,
                    "feature_type": "drop_off",
                    "recommendation_rank": 1,
                    "reasoning": ["eğim"],
                    "reasoning_text": "Olası aday.",
                    "supporting_metrics": {"slope": 0.7},
                }
            ],
        },
        "client_request_id": "endpoint-test",
    }


class AiAssistantEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()

    def test_health_includes_ai_assistant_block(self) -> None:
        resp = self.client.get("/health")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["service"], "MeraSonar API")
        self.assertIn("ai_assistant", body)
        ai = body["ai_assistant"]
        for key in (
            "enabled",
            "configured",
            "vision_enabled",
            "streaming_enabled",
            "prompt_version",
            "rate_limit_enabled",
            "model_configured",
            "quota_enabled",
            "telemetry_persist_enabled",
            "usage_summary_enabled",
            "openai_key_present",
            "openai_model",
            "ai_runtime_ready",
            "timeout_seconds",
        ):
            self.assertIn(key, ai)
        self.assertNotIn("openai_api_key", ai)
        self.assertNotIn("OPENAI_API_KEY", str(ai))

    def test_endpoint_validation_error(self) -> None:
        resp = self.client.post("/api/v1/ai_fishing_assistant", json={"scope": "session_summary"})
        self.assertEqual(resp.status_code, 422)
        self.assertEqual(resp.json().get("error"), "validation_error")

    def test_endpoint_fallback_when_ai_disabled(self) -> None:
        cfg = make_ai_config(enabled=False)
        service = build_ai_assistant_service(
            cfg,
            cache=InMemoryAiResponseCache(ttl_seconds=30),
        )
        main.app.dependency_overrides[_get_ai_assistant_service] = lambda: service
        resp = self.client.post("/api/v1/ai_fishing_assistant", json=_sample_body())
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["source"], "fallback")
        self.assertIn("summary_tr", body)

    def test_endpoint_ai_success_with_override(self) -> None:
        cfg = make_ai_config()
        mock = MockOpenAIResponsesClient(sample_structured_json())
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=30),
        )
        main.app.dependency_overrides[_get_ai_assistant_service] = lambda: service
        resp = self.client.post("/api/v1/ai_fishing_assistant", json=_sample_body())
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["source"], "ai")
        self.assertEqual(body["prompt_version"], "v1-test")


if __name__ == "__main__":
    unittest.main()
