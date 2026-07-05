from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

import main
from ai_assistant.cache import InMemoryAiResponseCache
from ai_assistant.dependencies import (
    build_ai_assistant_service,
    get_ai_assistant_config,
    get_ai_quota_store,
    get_ai_telemetry_store,
)
from ai_assistant.identity import resolve_client_identity
from ai_assistant.models import ClientIdentityModel
from ai_assistant.quota import InMemoryAiQuotaStore, check_ai_quota
from ai_assistant.router import _get_ai_assistant_service
from ai_assistant.telemetry_store import (
    CompositeAiTelemetryStore,
    InMemoryAiTelemetryStore,
    JsonlAiTelemetryStore,
    build_persistent_entry,
)
from tests.ai_assistant_fixtures import (
    MockOpenAIResponsesClient,
    default_client_identity,
    make_ai_config,
    sample_structured_json,
)


def _sample_body(*, device_id: str | None = None, is_premium: bool | None = None) -> dict:
    body = {
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
    if device_id is not None or is_premium is not None:
        identity: dict = {}
        if device_id is not None:
            identity["device_id"] = device_id
        if is_premium is not None:
            identity["is_premium"] = is_premium
        body["client_identity"] = identity
    return body


class QuotaTests(unittest.TestCase):
    def test_quota_disabled_by_default(self) -> None:
        cfg = make_ai_config(enabled=False)
        store = InMemoryAiQuotaStore()
        result = check_ai_quota(
            cfg,
            store,
            "device:test-1",
            is_premium=False,
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.remaining, cfg.ai_free_daily_limit)

    def test_free_daily_limit_enforced(self) -> None:
        cfg = make_ai_config(enabled=False)
        cfg = cfg.__class__(
            **{**cfg.__dict__, "ai_quota_enabled": True, "ai_free_daily_limit": 2}
        )
        store = InMemoryAiQuotaStore()
        for _ in range(2):
            r = check_ai_quota(cfg, store, "device:free-1", is_premium=False)
            self.assertTrue(r.allowed)
        blocked = check_ai_quota(cfg, store, "device:free-1", is_premium=False)
        self.assertFalse(blocked.allowed)
        self.assertEqual(blocked.remaining, 0)

    def test_premium_daily_limit_higher(self) -> None:
        cfg = make_ai_config(enabled=False)
        cfg = cfg.__class__(
            **{
                **cfg.__dict__,
                "ai_quota_enabled": True,
                "ai_free_daily_limit": 2,
                "ai_premium_daily_limit": 5,
            }
        )
        store = InMemoryAiQuotaStore()
        for _ in range(5):
            r = check_ai_quota(cfg, store, "user:premium-1", is_premium=True)
            self.assertTrue(r.allowed)
        blocked = check_ai_quota(cfg, store, "user:premium-1", is_premium=True)
        self.assertFalse(blocked.allowed)


class IdentityFallbackTests(unittest.TestCase):
    def test_missing_identity_uses_ip(self) -> None:
        resolved = resolve_client_identity(None, "203.0.113.10")
        self.assertTrue(resolved.client_key.startswith("ip:"))
        self.assertEqual(resolved.identity_source, "ip")
        self.assertFalse(resolved.is_premium)

    def test_user_id_takes_priority_over_device(self) -> None:
        identity = ClientIdentityModel(
            user_id="u-42",
            device_id="d-99",
            is_premium=True,
        )
        resolved = resolve_client_identity(identity, "127.0.0.1")
        self.assertEqual(resolved.client_key, "user:u-42")
        self.assertTrue(resolved.is_premium)


class TelemetryStoreTests(unittest.TestCase):
    def test_jsonl_persist_writes_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ai_telemetry.jsonl"
            store = JsonlAiTelemetryStore(path)
            store.append(
                build_persistent_entry(
                    request_id="req-1",
                    client_safe_id="abc123",
                    scope="session_summary",
                    source="ai",
                    model="test-model",
                    prompt_version="v1",
                    latency_ms=10.0,
                    cache_hit=False,
                    fallback_reason=None,
                    token_usage={"input": 1, "output": 2, "total": 3},
                    estimated_cost=0.001,
                    remaining_ai_requests=9,
                    is_premium=False,
                )
            )
            self.assertTrue(path.exists())
            text = path.read_text(encoding="utf-8")
            self.assertIn("req-1", text)
            self.assertIn("abc123", text)
            self.assertNotIn("OPENAI", text)

            summary = store.summarize(client_safe_id="abc123")
            self.assertEqual(summary["total_requests"], 1)
            self.assertEqual(summary["ai_requests"], 1)


class QuotaEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        get_ai_quota_store().reset()

    def test_quota_exceeded_returns_429(self) -> None:
        cfg = make_ai_config(enabled=False)
        cfg = cfg.__class__(
            **{**cfg.__dict__, "ai_quota_enabled": True, "ai_free_daily_limit": 1}
        )
        quota_store = InMemoryAiQuotaStore()
        service = build_ai_assistant_service(
            cfg,
            cache=InMemoryAiResponseCache(ttl_seconds=30),
        )
        main.app.dependency_overrides[_get_ai_assistant_service] = lambda: service
        main.app.dependency_overrides[get_ai_assistant_config] = lambda: cfg
        main.app.dependency_overrides[get_ai_quota_store] = lambda: quota_store

        body = _sample_body(device_id="quota-device-1")
        first = self.client.post("/api/v1/ai_fishing_assistant", json=body)
        self.assertEqual(first.status_code, 200)

        second = self.client.post("/api/v1/ai_fishing_assistant", json=body)
        self.assertEqual(second.status_code, 429)
        self.assertEqual(second.json().get("error"), "quota_exceeded")


class UsageSummaryEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        self._memory = InMemoryAiTelemetryStore()
        self._store = CompositeAiTelemetryStore(self._memory)

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        self._memory.reset()

    def _override_stores(self, *, admin_key: str | None = None) -> None:
        cfg = make_ai_config(enabled=False)
        if admin_key is not None:
            cfg = cfg.__class__(**{**cfg.__dict__, "ai_usage_admin_key": admin_key})
        main.app.dependency_overrides[get_ai_assistant_config] = lambda: cfg
        main.app.dependency_overrides[get_ai_telemetry_store] = lambda: self._store
        main.app.dependency_overrides[get_ai_quota_store] = lambda: InMemoryAiQuotaStore()

    def test_usage_summary_without_admin_key_when_unconfigured(self) -> None:
        self._override_stores(admin_key=None)
        self._memory.append(
            build_persistent_entry(
                request_id="r1",
                client_safe_id="safe123",
                scope="session_summary",
                source="ai",
                model="m1",
                prompt_version="v1",
                latency_ms=5.0,
                cache_hit=False,
                fallback_reason=None,
                token_usage={"input": 10, "output": 5, "total": 15},
                estimated_cost=0.002,
                remaining_ai_requests=None,
                is_premium=None,
            )
        )
        resp = self.client.get("/api/v1/ai_usage_summary")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["total_requests"], 1)
        self.assertEqual(body["ai_requests"], 1)
        self.assertIn("by_scope", body)

    def test_admin_key_required_when_configured(self) -> None:
        self._override_stores(admin_key="secret-admin-key")
        resp = self.client.get("/api/v1/ai_usage_summary")
        self.assertEqual(resp.status_code, 403)
        self.assertEqual(resp.json().get("error"), "forbidden")

        ok = self.client.get(
            "/api/v1/ai_usage_summary",
            headers={"X-AI-Usage-Admin-Key": "secret-admin-key"},
        )
        self.assertEqual(ok.status_code, 200)
        self.assertNotIn("secret-admin-key", ok.text)

    def test_response_includes_remaining_when_quota_enabled(self) -> None:
        cfg = make_ai_config(enabled=False)
        cfg = cfg.__class__(
            **{**cfg.__dict__, "ai_quota_enabled": True, "ai_free_daily_limit": 10}
        )
        quota_store = InMemoryAiQuotaStore()
        main.app.dependency_overrides[get_ai_assistant_config] = lambda: cfg
        main.app.dependency_overrides[get_ai_telemetry_store] = lambda: self._store
        main.app.dependency_overrides[get_ai_quota_store] = lambda: quota_store

        resp = self.client.get(
            "/api/v1/ai_usage_summary",
            params={"device_id": "usage-dev-1"},
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json().get("quota_remaining"), 10)


class PremiumResponseTests(unittest.TestCase):
    def test_is_premium_feature_in_response_when_quota_enabled(self) -> None:
        cfg = make_ai_config()
        cfg = cfg.__class__(**{**cfg.__dict__, "ai_quota_enabled": True})
        mock = MockOpenAIResponsesClient(sample_structured_json())
        memory = InMemoryAiTelemetryStore()
        store = CompositeAiTelemetryStore(memory)
        service = build_ai_assistant_service(
            cfg,
            openai_client=mock,
            cache=InMemoryAiResponseCache(ttl_seconds=60),
            telemetry_store=store,
        )
        identity = resolve_client_identity(
            ClientIdentityModel(device_id="prem-dev", is_premium=True),
            "127.0.0.1",
        )
        from tests.ai_assistant_fixtures import sample_request

        out = service.handle(
            sample_request(),
            client_identity=identity,
            quota_remaining=99,
        )
        self.assertEqual(out.is_premium_feature, True)
        self.assertIsNotNone(out.remaining_ai_requests)


if __name__ == "__main__":
    unittest.main()
