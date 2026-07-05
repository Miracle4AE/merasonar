from __future__ import annotations

import os
import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

import main
from ai_assistant.captain_atlas import (
    CAPTAIN_ATLAS_NAME,
    CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT,
    get_persona_version,
)
from ai_assistant.models import (
    AiFishingAssistantResponseModel,
    RecommendedActionModel,
)
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from ai_assistant.telemetry import AiTelemetryLogger
from marine_intelligence.dependencies import reset_marine_intelligence_singletons
from marine_intelligence.marine_ai_comment import generate_marine_ai_comment
from marine_intelligence.marine_ai_comment_cache import (
    MarineAiCommentCache,
    build_marine_ai_comment_cache_key,
)
from tests.ai_assistant_fixtures import make_ai_config
from tests.test_marine_intelligence_faz7f import _mock_marine_service


def _mock_ai_response() -> AiFishingAssistantResponseModel:
    return AiFishingAssistantResponseModel(
        source="ai",
        prompt_version="v1-test",
        summary_tr="Captain Atlas test özeti",
        confidence="medium",
        recommended_actions=[
            RecommendedActionModel(priority=1, title_tr="Plan", detail_tr="Detay"),
        ],
        conditions_comment_tr="Koşullar uygun görünüyor.",
        species_comment_tr="Genel deniz koşulu.",
    )


class CaptainAtlasUnifiedPersonaTests(unittest.TestCase):
    def test_all_scopes_use_captain_atlas_system_prompt(self) -> None:
        builder = AiAssistantPromptBuilder(make_ai_config())
        scopes = [
            ("session_summary", {"scope": "session_summary", "hotspots": []}),
            ("hotspot_detail", {"scope": "hotspot_detail", "focus_hotspot_id": 3}),
            (
                "live_context",
                {
                    "scope": "live_context",
                    "live_context": {"nearest_hotspot": 10},
                    "live_context_warnings": [],
                },
            ),
            ("marine_coordinate", {"scope": "marine_coordinate", "marine": {}}),
        ]
        for scope_name, context in scopes:
            with self.subTest(scope=scope_name):
                bundle = builder.build(context)
                self.assertIn(CAPTAIN_ATLAS_NAME, bundle.system_prompt)
                self.assertIn(CAPTAIN_ATLAS_NAME, bundle.user_prompt)

    def test_persona_version_env_override(self) -> None:
        with patch.dict(os.environ, {"CAPTAIN_ATLAS_PERSONA_VERSION": "captain_atlas_test_v2"}):
            self.assertEqual(get_persona_version(), "captain_atlas_test_v2")
        self.assertEqual(get_persona_version(), CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT)

    def test_cache_key_changes_when_persona_version_changes(self) -> None:
        report = _mock_marine_service().get_coordinate_intelligence(37.0, 27.0)
        key_v1 = build_marine_ai_comment_cache_key(report, persona_version="captain_atlas_v1")
        key_v2 = build_marine_ai_comment_cache_key(report, persona_version="captain_atlas_v2")
        self.assertNotEqual(key_v1, key_v2)


class MarineAiCommentCacheTests(unittest.TestCase):
    def test_cache_hit_skips_ai_service(self) -> None:
        report = _mock_marine_service().get_coordinate_intelligence(37.0, 27.0)
        cache = MarineAiCommentCache(ttl_seconds=900)
        mock_service = MagicMock()
        mock_service.handle.return_value = _mock_ai_response()

        comment1 = generate_marine_ai_comment(
            report,
            ai_service=mock_service,
            ai_config=make_ai_config(enabled=True),
            comment_cache=cache,
        )
        comment2 = generate_marine_ai_comment(
            report,
            ai_service=mock_service,
            ai_config=make_ai_config(enabled=True),
            comment_cache=cache,
        )

        mock_service.handle.assert_called_once()
        self.assertFalse(comment1.cache_hit)
        self.assertTrue(comment2.cache_hit)
        self.assertEqual(comment2.summary_tr, comment1.summary_tr)

    def test_fallback_comment_is_not_cached(self) -> None:
        report = _mock_marine_service().get_coordinate_intelligence(37.0, 27.0)
        cache = MarineAiCommentCache(ttl_seconds=900)
        mock_service = MagicMock()
        mock_service.handle.side_effect = RuntimeError("boom")

        first = generate_marine_ai_comment(
            report,
            ai_service=mock_service,
            ai_config=make_ai_config(enabled=True),
            comment_cache=cache,
        )
        second = generate_marine_ai_comment(
            report,
            ai_service=mock_service,
            ai_config=make_ai_config(enabled=True),
            comment_cache=cache,
        )

        self.assertEqual(first.source, "fallback")
        self.assertEqual(first.fallback_reason, "upstream_failure")
        self.assertFalse(second.cache_hit)
        self.assertEqual(mock_service.handle.call_count, 2)


class CaptainAtlasTelemetryAllScopesTests(unittest.TestCase):
    def test_all_scopes_emit_persona_telemetry(self) -> None:
        logger = AiTelemetryLogger(make_ai_config())
        for scope in (
            "session_summary",
            "hotspot_detail",
            "live_context",
            "marine_coordinate",
        ):
            with self.subTest(scope=scope):
                record = logger.build_record(
                    model="test-model",
                    latency_ms=10.0,
                    cache_hit=False,
                    input_tokens=1,
                    output_tokens=2,
                    processing_time_ms=5,
                    prompt_version="v1",
                    source="ai",
                    scope=scope,
                    fallback_reason=None,
                    client_request_id=None,
                )
                self.assertEqual(record.assistant_name, CAPTAIN_ATLAS_NAME)
                self.assertIsNotNone(record.persona_version)
                self.assertEqual(record.scope, scope)


class CaptainAtlasEndpointRegressionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: _mock_marine_service()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_include_ai_comment_false_skips_ai_and_cache(self) -> None:
        with patch("marine_intelligence.service.generate_marine_ai_comment") as mock_gen:
            resp = self.client.post(
                "/api/v1/marine_intelligence/coordinate",
                json={"lat": 37.0, "lon": 27.0, "include_ai_comment": False},
            )
            self.assertEqual(resp.status_code, 200)
            self.assertIsNone(resp.json().get("ai_comment"))
            mock_gen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
