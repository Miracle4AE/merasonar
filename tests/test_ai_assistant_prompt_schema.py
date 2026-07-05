from __future__ import annotations

import unittest

from ai_assistant.json_schema import strict_json_schema
from ai_assistant.models import AiStructuredPayloadModel
from ai_assistant.prompt_builder import AiAssistantPromptBuilder
from tests.ai_assistant_fixtures import make_ai_config


class AiAssistantPromptAndSchemaTests(unittest.TestCase):
    def test_prompt_includes_version(self) -> None:
        builder = AiAssistantPromptBuilder(make_ai_config())
        bundle = builder.build({"scope": "session_summary", "hotspots": []})
        self.assertIn("v1-test", bundle.system_prompt)
        self.assertIn("prompt_version: v1-test", bundle.user_prompt)

    def test_schema_enforces_additional_properties_false(self) -> None:
        schema = strict_json_schema(AiStructuredPayloadModel)

        def _walk(node):
            if isinstance(node, dict):
                if node.get("type") == "object":
                    yield node
                for v in node.values():
                    yield from _walk(v)
            elif isinstance(node, list):
                for item in node:
                    yield from _walk(item)

        objects = list(_walk(schema))
        self.assertGreater(len(objects), 0)
        for obj in objects:
            self.assertFalse(obj.get("additionalProperties", True))

    def test_schema_required_includes_all_property_keys(self) -> None:
        schema = strict_json_schema(AiStructuredPayloadModel)
        props = schema.get("properties") or {}
        required = schema.get("required") or []
        self.assertEqual(set(required), set(props.keys()))


if __name__ == "__main__":
    unittest.main()
