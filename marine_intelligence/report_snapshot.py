from __future__ import annotations

from typing import Any, Dict, List, Optional

from marine_intelligence.models import (
    MarineCoordinateResponseModel,
    ProviderComparisonModel,
    ScenarioBundleModel,
)


def _trim_scenario_snapshot(
    scenario: Optional[ScenarioBundleModel],
) -> Optional[Dict[str, Any]]:
    if scenario is None:
        return None
    return {
        "base_go_score": scenario.base_go_score,
        "items": [item.model_dump(mode="json") for item in scenario.items],
    }


def trim_report_snapshot(report: MarineCoordinateResponseModel) -> Dict[str, Any]:
    """last_report için sadeleştirilmiş coordinate response özeti."""
    provider_comparison_summary: Optional[Dict[str, Any]] = None
    if report.provider_comparison is not None:
        provider_comparison_summary = {
            "summary": report.provider_comparison.summary.model_dump(mode="json"),
        }

    snapshot: Dict[str, Any] = {
        "coordinate": report.coordinate.model_dump(mode="json"),
        "weather": report.weather.model_dump(mode="json"),
        "wind": report.wind.model_dump(mode="json"),
        "marine": report.marine.model_dump(mode="json"),
        "astronomy": report.astronomy.model_dump(mode="json"),
        "fishing_score": report.fishing_score.model_dump(mode="json"),
        "consensus_summary": report.consensus_summary.model_dump(mode="json"),
        "provider_comparison": provider_comparison_summary,
        "explainability": (
            report.explainability.model_dump(mode="json") if report.explainability else None
        ),
        "decision": report.decision.model_dump(mode="json") if report.decision else None,
        "decision_timeline": (
            [item.model_dump(mode="json") for item in report.decision_timeline]
            if report.decision_timeline
            else None
        ),
        "scenario": _trim_scenario_snapshot(report.scenario),
        "ai_comment": report.ai_comment.model_dump(mode="json") if report.ai_comment else None,
        "updated_at": report.updated_at,
    }
    return snapshot


def trim_report_snapshot_from_dict(report: Dict[str, Any]) -> Dict[str, Any]:
    model = MarineCoordinateResponseModel.model_validate(report)
    return trim_report_snapshot(model)
