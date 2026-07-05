from __future__ import annotations

import unittest

from ai_assistant.guardrails import AiAssistantGuardrails
from ai_assistant.models import AiStructuredPayloadModel
from tests.ai_assistant_fixtures import sample_structured_payload


class AiAssistantGuardrailsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.guardrails = AiAssistantGuardrails()

    def test_detects_forbidden_word(self) -> None:
        payload = sample_structured_payload().model_copy(
            update={"summary_tr": "Burada kesin avlanırsınız."}
        )
        reason = self.guardrails.validate_payload(payload)
        self.assertIsNotNone(reason)

    def test_sanitize_replaces_forbidden_content(self) -> None:
        payload = sample_structured_payload().model_copy(
            update={"summary_tr": "Mutlaka burada balık vardır."}
        )
        sanitized = self.guardrails.sanitize_payload(payload)
        self.assertNotIn("Mutlaka", sanitized.summary_tr)

    def test_clean_payload_passes(self) -> None:
        payload = sample_structured_payload()
        self.assertIsNone(self.guardrails.validate_payload(payload))


if __name__ == "__main__":
    unittest.main()
