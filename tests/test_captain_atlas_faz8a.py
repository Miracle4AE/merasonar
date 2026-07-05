from __future__ import annotations

import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

import main
from ai_assistant.guardrails import AiAssistantGuardrails
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from ai_assistant.captain_atlas import (
    CAPTAIN_ATLAS_NAME,
    CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT,
    get_persona_version,
    persona_metadata,
)
from ai_assistant.telemetry import AiTelemetryLogger
from marine_intelligence.dependencies import reset_marine_intelligence_singletons
from marine_intelligence.marine_ai_comment import build_deterministic_marine_comment
from marine_intelligence.models import MarineCoordinateResponseModel
from tests.ai_assistant_fixtures import make_ai_config, sample_structured_payload
from tests.test_marine_intelligence_faz7f import _mock_marine_service


def _minimal_report() -> MarineCoordinateResponseModel:
    service = _mock_marine_service()
    return service.get_coordinate_intelligence(37.0, 27.0)


class CaptainAtlasPersonaTests(unittest.TestCase):
    def test_marine_coordinate_prompt_includes_captain_atlas(self) -> None:
        builder = AiAssistantPromptBuilder(make_ai_config())
        bundle = builder.build({"scope": "marine_coordinate", "marine": {}})
        self.assertIn(CAPTAIN_ATLAS_NAME, bundle.system_prompt)
        self.assertIn(get_persona_version(), bundle.system_prompt)
        self.assertIn(CAPTAIN_ATLAS_NAME, bundle.user_prompt)

    def test_session_summary_uses_captain_atlas(self) -> None:
        builder = AiAssistantPromptBuilder(make_ai_config())
        bundle = builder.build({"scope": "session_summary", "hotspots": []})
        self.assertIn(CAPTAIN_ATLAS_NAME, bundle.system_prompt)
        self.assertIn(get_persona_version(), bundle.system_prompt)

    def test_fallback_comment_includes_assistant_name(self) -> None:
        report = _minimal_report()
        comment = build_deterministic_marine_comment(report, reason="test")
        self.assertEqual(comment.assistant_name, CAPTAIN_ATLAS_NAME)
        self.assertEqual(comment.persona_version, get_persona_version())
        self.assertEqual(comment.tone, "calm_expert")
        self.assertTrue(comment.summary_tr.startswith("Denizden selamlar"))

    def test_persona_metadata_defaults(self) -> None:
        meta = persona_metadata()
        self.assertEqual(meta["assistant_name"], CAPTAIN_ATLAS_NAME)
        self.assertEqual(meta["persona_version"], CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT)


class CaptainAtlasGuardrailTests(unittest.TestCase):
    def setUp(self) -> None:
        self.guardrails = AiAssistantGuardrails()

    def test_forbidden_phrase_kesin_balik(self) -> None:
        payload = sample_structured_payload().model_copy(
            update={"summary_tr": "Burada kesin balık var."}
        )
        self.assertIsNotNone(self.guardrails.validate_payload(payload))

    def test_forbidden_phrase_risk_yok(self) -> None:
        payload = sample_structured_payload().model_copy(
            update={"conditions_comment_tr": "Denize çıkabilirsiniz, risk yok."}
        )
        self.assertIsNotNone(self.guardrails.validate_payload(payload))

    def test_sanitize_mutlaka_git(self) -> None:
        payload = sample_structured_payload().model_copy(
            update={"summary_tr": "Mutlaka git, koşullar uygun."}
        )
        sanitized = self.guardrails.sanitize_payload(payload)
        self.assertNotIn("Mutlaka", sanitized.summary_tr)


class CaptainAtlasTelemetryTests(unittest.TestCase):
    def test_marine_coordinate_telemetry_includes_persona(self) -> None:
        logger = AiTelemetryLogger(make_ai_config())
        record = logger.build_record(
            model="test-model",
            latency_ms=10.0,
            cache_hit=False,
            input_tokens=1,
            output_tokens=2,
            processing_time_ms=5,
            prompt_version="v1",
            source="ai",
            scope="marine_coordinate",
            fallback_reason=None,
            client_request_id=None,
        )
        self.assertEqual(record.assistant_name, CAPTAIN_ATLAS_NAME)
        self.assertEqual(record.persona_version, get_persona_version())
        self.assertEqual(record.scope, "marine_coordinate")

    def test_session_summary_telemetry_includes_persona(self) -> None:
        logger = AiTelemetryLogger(make_ai_config())
        record = logger.build_record(
            model="test-model",
            latency_ms=10.0,
            cache_hit=False,
            input_tokens=1,
            output_tokens=2,
            processing_time_ms=5,
            prompt_version="v1",
            source="ai",
            scope="session_summary",
            fallback_reason=None,
            client_request_id=None,
        )
        self.assertEqual(record.assistant_name, CAPTAIN_ATLAS_NAME)
        self.assertIsNotNone(record.persona_version)


class CaptainAtlasEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        reset_marine_intelligence_singletons()
        from marine_intelligence.dependencies import get_marine_intelligence_service

        main.app.dependency_overrides[get_marine_intelligence_service] = lambda: _mock_marine_service()

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        reset_marine_intelligence_singletons()

    def test_include_ai_comment_false_skips_ai(self) -> None:
        with patch("marine_intelligence.service.generate_marine_ai_comment") as mock_ai:
            resp = self.client.post(
                "/api/v1/marine_intelligence/coordinate",
                json={"lat": 37.0, "lon": 27.0, "include_ai_comment": False},
            )
            self.assertEqual(resp.status_code, 200)
            self.assertIsNone(resp.json().get("ai_comment"))
            mock_ai.assert_not_called()

    def test_ai_assistant_session_summary_still_requires_analysis(self) -> None:
        resp = self.client.post("/api/v1/ai_fishing_assistant", json={"scope": "session_summary"})
        self.assertEqual(resp.status_code, 422)


if __name__ == "__main__":
    unittest.main()
