from __future__ import annotations

import unittest

from fastapi.testclient import TestClient

import main
from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.dependencies import build_ai_assistant_service, get_ai_assistant_config, get_ai_rate_limiter
from ai_assistant.router import _get_ai_assistant_service
from ai_assistant.rate_limiter import InMemoryAiRateLimiter
from tests.ai_assistant_fixtures import make_ai_config


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
                }
            ],
        },
    }


class AiAssistantRateLimitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        get_ai_rate_limiter().reset()

    def test_rate_limit_returns_429_when_enabled(self) -> None:
        cfg = make_ai_config(enabled=False)
        cfg = cfg.__class__(
            **{
                **cfg.__dict__,
                "ai_rate_limit_enabled": True,
                "ai_rate_limit_per_minute": 1,
            }
        )
        service = build_ai_assistant_service(
            cfg,
            cache=InMemoryAiResponseCache(ttl_seconds=30),
        )
        limiter = InMemoryAiRateLimiter(limit_per_minute=1)
        main.app.dependency_overrides[_get_ai_assistant_service] = lambda: service
        main.app.dependency_overrides[get_ai_assistant_config] = lambda: cfg
        main.app.dependency_overrides[get_ai_rate_limiter] = lambda: limiter

        first = self.client.post("/api/v1/ai_fishing_assistant", json=_sample_body())
        self.assertEqual(first.status_code, 200)

        second = self.client.post("/api/v1/ai_fishing_assistant", json=_sample_body())
        self.assertEqual(second.status_code, 429)
        self.assertEqual(second.json().get("error"), "rate_limit_exceeded")

    def test_rate_limit_disabled_by_default(self) -> None:
        cfg = make_ai_config(enabled=False)
        service = build_ai_assistant_service(
            cfg,
            cache=InMemoryAiResponseCache(ttl_seconds=30),
        )
        main.app.dependency_overrides[_get_ai_assistant_service] = lambda: service

        for _ in range(3):
            resp = self.client.post("/api/v1/ai_fishing_assistant", json=_sample_body())
            self.assertEqual(resp.status_code, 200)


if __name__ == "__main__":
    unittest.main()
