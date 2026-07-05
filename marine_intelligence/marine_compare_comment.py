from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from ai_assistant.captain_atlas import (
    CAPTAIN_ATLAS_NAME,
    captain_atlas_fallback_summary,
    persona_metadata,
)
from ai_assistant.config import AiAssistantConfig
from ai_assistant.dependencies import (
    build_ai_assistant_service,
    get_ai_assistant_config,
    get_ai_quota_store,
    get_ai_rate_limiter,
)
from ai_assistant.identity import resolve_client_identity
from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    MarineCompareContextInputModel,
)
from ai_assistant.quota import check_ai_quota
from ai_assistant.rate_limiter import check_ai_rate_limit
from ai_assistant.service import AiAssistantService
from marine_intelligence.compare_engine import _best_timeline_label, _go_score, _risk_score
from marine_intelligence.models import (
    MarineAiCommentActionModel,
    MarineAiCommentModel,
    MarineComparisonModel,
    MarineCoordinateResponseModel,
)

_logger = logging.getLogger(__name__)


def _side_summary(
    report: MarineCoordinateResponseModel,
    *,
    label: str,
) -> Dict[str, Any]:
    decision = report.decision.model_dump(mode="json") if report.decision else {}
    return {
        "label": label,
        "lat": round(report.coordinate.lat, 5),
        "lon": round(report.coordinate.lon, 5),
        "go_score": _go_score(report),
        "risk_score": _risk_score(report),
        "confidence_pct": int(round(report.consensus_summary.overall_confidence * 100)),
        "decision": decision.get("fishing_decision"),
        "best_time_window": _best_timeline_label(report),
        "partial_data": report.partial_data,
    }


def build_marine_compare_context(
    *,
    left_report: MarineCoordinateResponseModel,
    right_report: MarineCoordinateResponseModel,
    comparison: MarineComparisonModel,
    left_label: str,
    right_label: str,
    left_catch_context: Optional[Dict[str, Any]] = None,
    right_catch_context: Optional[Dict[str, Any]] = None,
) -> MarineCompareContextInputModel:
    return MarineCompareContextInputModel(
        left_label=left_label,
        right_label=right_label,
        comparison=comparison.model_dump(mode="json"),
        left_summary=_side_summary(left_report, label=left_label),
        right_summary=_side_summary(right_report, label=right_label),
        left_catch_context=left_catch_context,
        right_catch_context=right_catch_context,
    )


def build_deterministic_compare_comment(
    comparison: MarineComparisonModel,
    *,
    left_label: str,
    right_label: str,
    reason: str = "ai_not_requested",
) -> MarineAiCommentModel:
    summary = captain_atlas_fallback_summary(comparison.summary_tr)
    actions: List[MarineAiCommentActionModel] = []
    if comparison.winner == "tie":
        actions.append(
            MarineAiCommentActionModel(
                title_tr="Benzer koşullar",
                detail_tr=(
                    f"{left_label} ve {right_label} birbirine yakın; "
                    "hangisini seçeceğiniz yerel tercih ve rota planına bağlı."
                ),
            )
        )
    else:
        winner = comparison.winner_label or "Seçilen nokta"
        actions.append(
            MarineAiCommentActionModel(
                title_tr=f"{CAPTAIN_ATLAS_NAME} karşılaştırması",
                detail_tr=comparison.decision_delta_tr,
            )
        )
        actions.append(
            MarineAiCommentActionModel(
                title_tr="Daha uygun görünen",
                detail_tr=f"{winner} şu an biraz daha mantıklı görünüyor (olasılıksal).",
            )
        )

    return MarineAiCommentModel(
        source="fallback",
        summary_tr=summary,
        recommended_actions=actions,
        risk_note_tr=comparison.risk_note_tr,
        best_time_window_tr=None,
        cache_hit=False,
        fallback_reason=reason,
        **persona_metadata(),
    )


def generate_marine_compare_comment(
    *,
    left_report: MarineCoordinateResponseModel,
    right_report: MarineCoordinateResponseModel,
    comparison: MarineComparisonModel,
    left_label: str,
    right_label: str,
    left_catch_context: Optional[Dict[str, Any]] = None,
    right_catch_context: Optional[Dict[str, Any]] = None,
    client_ip: str = "unknown",
    ai_service: Optional[AiAssistantService] = None,
    ai_config: Optional[AiAssistantConfig] = None,
) -> MarineAiCommentModel:
    config = ai_config or get_ai_assistant_config()
    service = ai_service or build_ai_assistant_service(config=config)

    compare_context = build_marine_compare_context(
        left_report=left_report,
        right_report=right_report,
        comparison=comparison,
        left_label=left_label,
        right_label=right_label,
        left_catch_context=left_catch_context,
        right_catch_context=right_catch_context,
    )
    request = AiFishingAssistantRequestModel(
        scope="marine_compare",
        marine_compare_context=compare_context,
    )

    resolved = resolve_client_identity(None, client_ip)
    try:
        rl = check_ai_rate_limit(config, get_ai_rate_limiter(), client_ip)
        if not rl.allowed:
            return build_deterministic_compare_comment(
                comparison,
                left_label=left_label,
                right_label=right_label,
                reason="rate_limit_exceeded",
            )
        quota = check_ai_quota(
            config,
            get_ai_quota_store(),
            resolved.client_key,
            is_premium=resolved.is_premium,
        )
        if not quota.allowed:
            return build_deterministic_compare_comment(
                comparison,
                left_label=left_label,
                right_label=right_label,
                reason="quota_exceeded",
            )
    except Exception as exc:
        _logger.warning("Compare AI quota/rate check failed: %s", exc)

    try:
        ai_response = service.handle(
            request,
            client_identity=resolved,
        )
        actions = [
            MarineAiCommentActionModel(title_tr=a.title_tr, detail_tr=a.detail_tr)
            for a in ai_response.recommended_actions[:5]
        ]
        return MarineAiCommentModel(
            source=ai_response.source,
            summary_tr=ai_response.summary_tr,
            recommended_actions=actions,
            risk_note_tr=ai_response.conditions_comment_tr or comparison.risk_note_tr,
            best_time_window_tr=None,
            cache_hit=ai_response.cache_hit,
            fallback_reason=ai_response.fallback_reason,
            **persona_metadata(),
        )
    except Exception as exc:
        _logger.warning("Marine compare AI comment failed: %s", exc, exc_info=True)
        return build_deterministic_compare_comment(
            comparison,
            left_label=left_label,
            right_label=right_label,
            reason="upstream_failure",
        )
