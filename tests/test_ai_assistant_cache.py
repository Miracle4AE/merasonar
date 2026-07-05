from __future__ import annotations

import unittest

from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.fallback import AiAssistantFallbackBuilder
from tests.ai_assistant_fixtures import sample_request


class AiAssistantCacheTests(unittest.TestCase):
    def test_set_and_get_returns_cache_hit_flag(self) -> None:
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        req = sample_request()
        response = AiAssistantFallbackBuilder().build(
            req,
            prompt_version="v1",
            reason="test",
            processing_ms=1,
        )
        cache.set("fp1", response)
        cached = cache.get("fp1")
        assert cached is not None
        self.assertTrue(cached.cache_hit)

    def test_miss_returns_none(self) -> None:
        cache = InMemoryAiResponseCache(ttl_seconds=60)
        self.assertIsNone(cache.get("missing"))


if __name__ == "__main__":
    unittest.main()
