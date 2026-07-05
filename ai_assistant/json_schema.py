from __future__ import annotations

from typing import Any, Dict, Type

from pydantic import BaseModel

from ai_assistant.models import AiStructuredPayloadModel

_SCHEMA_NAME = "ai_fishing_assistant_response"


def strict_json_schema(model: Type[BaseModel]) -> Dict[str, Any]:
    """OpenAI Structured Outputs için additionalProperties=false ile şema üretir."""
    schema = model.model_json_schema()
    return _enforce_strict_object(schema)


def structured_output_format() -> Dict[str, Any]:
    return {
        "type": "json_schema",
        "name": _SCHEMA_NAME,
        "strict": True,
        "schema": strict_json_schema(AiStructuredPayloadModel),
    }


def _enforce_strict_object(node: Any) -> Any:
    if isinstance(node, dict):
        patched = {k: _enforce_strict_object(v) for k, v in node.items()}
        if patched.get("type") == "object":
            patched["additionalProperties"] = False
            props = patched.get("properties")
            if isinstance(props, dict) and props:
                # OpenAI strict JSON schema: every property key must appear in required.
                patched["required"] = list(props.keys())
        return patched
    if isinstance(node, list):
        return [_enforce_strict_object(item) for item in node]
    return node
