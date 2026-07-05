from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Mapping

from ai_assistant.config import AiAssistantConfig


@dataclass(frozen=True)
class CostEstimate:
    estimated_input_tokens: int
    estimated_output_tokens: int
    estimated_cost_usd: float
    threshold_usd: float
    exceeded: bool


def estimate_context_cost_usd(
    context: Mapping[str, Any],
    config: AiAssistantConfig,
) -> CostEstimate:
    threshold = max(0.0, float(config.ai_max_estimated_cost_per_request_usd))
    payload = json.dumps(dict(context), ensure_ascii=False, separators=(",", ":"))
    estimated_input = max(1, len(payload) // 4)
    estimated_output = max(1, min(config.ai_max_tokens, estimated_input // 2))
    cost = config.estimate_cost_usd(
        input_tokens=estimated_input,
        output_tokens=estimated_output,
    )
    exceeded = threshold > 0.0 and cost > threshold
    return CostEstimate(
        estimated_input_tokens=estimated_input,
        estimated_output_tokens=estimated_output,
        estimated_cost_usd=cost,
        threshold_usd=threshold,
        exceeded=exceeded,
    )
