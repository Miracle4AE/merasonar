from __future__ import annotations

import logging
import re
from typing import Any, Dict, List, Optional

from ai_assistant.captain_atlas import (
    CAPTAIN_ATLAS_NAME,
    captain_atlas_fallback_summary,
    get_persona_version,
    persona_metadata,
)
from ai_assistant.config import AiAssistantConfig
from ai_assistant.dependencies import (
    build_ai_assistant_service,
    get_ai_assistant_config,
    get_ai_quota_store,
    get_ai_rate_limiter,
)
from marine_intelligence.marine_ai_comment_cache import (
    MarineAiCommentCacheProtocol,
    build_marine_ai_comment_cache_key,
)
from ai_assistant.identity import resolve_client_identity
from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    AiFishingAssistantResponseModel,
    MarineCoordinateContextInputModel,
)
from ai_assistant.quota import check_ai_quota
from ai_assistant.rate_limiter import check_ai_rate_limit
from ai_assistant.service import AiAssistantService
from marine_intelligence.models import (
    MarineAiCommentActionModel,
    MarineAiCommentModel,
    MarineCoordinateResponseModel,
)

_logger = logging.getLogger(__name__)

_BEST_TIME_RE = re.compile(
    r"(en iyi|best|pencere|saat\s*\d|:\d{2})",
    re.IGNORECASE,
)


def _consensus_value(block: Any, field: str) -> Optional[float]:
    if block is None:
        return None
    model = getattr(block, field, None)
    if model is None:
        return None
    return model.final_value if hasattr(model, "final_value") else None


def build_marine_ai_context(
    report: MarineCoordinateResponseModel,
    *,
    catch_context: Optional[Dict[str, Any]] = None,
) -> MarineCoordinateContextInputModel:
    timeline_payload: List[Dict[str, Any]] = []
    if report.decision_timeline:
        for item in report.decision_timeline[:6]:
            timeline_payload.append(item.model_dump(mode="json"))

    scenario_items: List[Dict[str, Any]] = []
    if report.scenario and report.scenario.items:
        ranked = sorted(
            report.scenario.items,
            key=lambda s: abs(s.delta_go_score or 0) + abs(s.delta_risk_score or 0),
            reverse=True,
        )
        for item in ranked[:3]:
            scenario_items.append(item.model_dump(mode="json"))

    provider_summary = None
    if report.provider_comparison is not None:
        provider_summary = report.provider_comparison.summary.model_dump(mode="json")

    sensitive = None
    if report.explainability and report.explainability.most_sensitive_factor_tr:
        sensitive = report.explainability.most_sensitive_factor_tr

    return MarineCoordinateContextInputModel(
        lat=report.coordinate.lat,
        lon=report.coordinate.lon,
        decision=report.decision.model_dump(mode="json") if report.decision else None,
        decision_timeline=timeline_payload,
        fishing_score=report.fishing_score.model_dump(mode="json"),
        consensus_summary=report.consensus_summary.model_dump(mode="json"),
        provider_comparison_summary=provider_summary,
        explainability=(
            report.explainability.model_dump(mode="json") if report.explainability else None
        ),
        scenario_top_items=scenario_items,
        weather_summary={
            "temperature_c": _consensus_value(report.weather, "temperature_c"),
            "precipitation_probability_pct": _consensus_value(
                report.weather, "precipitation_probability_pct"
            ),
        },
        wind_summary={
            "speed_kmh": _consensus_value(report.wind, "speed_kmh"),
            "gust_kmh": _consensus_value(report.wind, "gust_kmh"),
            "direction_text": report.wind.direction_text,
        },
        marine_summary={
            "wave_height_m": _consensus_value(report.marine, "wave_height_m"),
            "swell_height_m": _consensus_value(report.marine, "swell_height_m"),
            "sea_surface_temperature_c": _consensus_value(
                report.marine, "sea_surface_temperature_c"
            ),
        },
        astronomy_summary={
            "moon_phase": report.astronomy.moon_phase,
            "moon_illumination_pct": report.astronomy.moon_illumination_pct,
        },
        most_sensitive_factor_tr=sensitive,
        catch_context=catch_context if catch_context and catch_context.get("found") else None,
    )


def _best_time_from_report(report: MarineCoordinateResponseModel) -> Optional[str]:
    if not report.decision_timeline:
        return None
    best = next((t for t in report.decision_timeline if t.is_best_slot), None)
    if best is None:
        best = max(
            report.decision_timeline,
            key=lambda t: t.go_score if t.go_score is not None else -1,
        )
    if best.go_score is None:
        return None
    return (
        f"Saat {best.time} UTC civarı git skoru {best.go_score} "
        f"({best.decision or 'değerlendirme'}) — tahmine dayalıdır."
    )


def _extract_best_time_from_ai(response: AiFishingAssistantResponseModel) -> Optional[str]:
    for text in (
        response.summary_tr,
        response.conditions_comment_tr,
        response.species_comment_tr,
    ):
        if text and _BEST_TIME_RE.search(text):
            return text.strip()
    return None


def map_ai_response_to_marine_comment(
    response: AiFishingAssistantResponseModel,
    report: MarineCoordinateResponseModel,
) -> MarineAiCommentModel:
    actions = [
        MarineAiCommentActionModel(title_tr=a.title_tr, detail_tr=a.detail_tr)
        for a in response.recommended_actions[:5]
    ]
    risk_parts = [response.conditions_comment_tr]
    risk_parts.extend(response.limitations_tr[:2])
    risk_parts.extend(response.safety_reminders_tr[:1])
    risk_note = " ".join(p for p in risk_parts if p).strip() or None

    best_time = _extract_best_time_from_ai(response) or _best_time_from_report(report)

    return MarineAiCommentModel(
        source=response.source,
        summary_tr=response.summary_tr,
        recommended_actions=actions,
        risk_note_tr=risk_note,
        best_time_window_tr=best_time,
        cache_hit=response.cache_hit,
        fallback_reason=response.fallback_reason,
        **persona_metadata(),
    )


def build_deterministic_marine_comment(
    report: MarineCoordinateResponseModel,
    *,
    reason: str = "ai_not_requested",
) -> MarineAiCommentModel:
    decision = report.decision
    fishing = report.fishing_score
    raw_summary = decision.short_summary_tr if decision and decision.short_summary_tr else None
    summary = captain_atlas_fallback_summary(raw_summary)
    actions: List[MarineAiCommentActionModel] = []
    if decision and decision.best_action_tr:
        actions.append(
            MarineAiCommentActionModel(
                title_tr=f"{CAPTAIN_ATLAS_NAME} önerisi",
                detail_tr=decision.best_action_tr,
            )
        )
    risk_note = None
    if report.explainability and report.explainability.most_sensitive_factor_tr:
        risk_note = report.explainability.most_sensitive_factor_tr
    elif fishing.risk_score >= 50:
        risk_note = f"Risk skoru {fishing.risk_score}/100 — dikkatli olun."

    return MarineAiCommentModel(
        source="fallback",
        summary_tr=summary,
        recommended_actions=actions,
        risk_note_tr=risk_note,
        best_time_window_tr=_best_time_from_report(report),
        cache_hit=False,
        fallback_reason=reason,
        **persona_metadata(),
    )


def generate_marine_ai_comment(
    report: MarineCoordinateResponseModel,
    *,
    client_ip: str = "unknown",
    user_question: Optional[str] = None,
    spot_id: Optional[str] = None,
    force_refresh: bool = False,
    ai_service: Optional[AiAssistantService] = None,
    ai_config: Optional[AiAssistantConfig] = None,
    comment_cache: Optional[MarineAiCommentCacheProtocol] = None,
) -> MarineAiCommentModel:
    """Mevcut AI Assistant altyapısı ile marine_coordinate yorumu üretir."""
    from marine_intelligence.dependencies import get_marine_ai_comment_cache

    config = ai_config or get_ai_assistant_config()
    cache = comment_cache or get_marine_ai_comment_cache()
    persona_version = get_persona_version()

    catch_context = _resolve_catch_context(spot_id)
    cache_key = build_marine_ai_comment_cache_key(
        report,
        persona_version=persona_version,
        user_question=user_question,
        catch_context=catch_context,
    )

    cached = None if force_refresh else cache.get(cache_key)
    if cached is not None and cached.source != "fallback":
        return cached

    service = ai_service or build_ai_assistant_service(config=config)

    marine_context = build_marine_ai_context(report, catch_context=catch_context)
    request = AiFishingAssistantRequestModel(
        scope="marine_coordinate",
        marine_context=marine_context,
        user_question=user_question,
    )

    resolved = resolve_client_identity(None, client_ip)
    rate_limit_remaining: Optional[int] = None
    quota_remaining: Optional[int] = None

    try:
        rl = check_ai_rate_limit(config, get_ai_rate_limiter(), client_ip)
        rate_limit_remaining = rl.remaining
        if not rl.allowed:
            return build_deterministic_marine_comment(report, reason="rate_limit_exceeded")

        quota = check_ai_quota(
            config,
            get_ai_quota_store(),
            resolved.client_key,
            is_premium=resolved.is_premium,
        )
        quota_remaining = quota.remaining
        if not quota.allowed:
            return build_deterministic_marine_comment(report, reason="quota_exceeded")
    except Exception as exc:
        _logger.warning("Marine AI quota/rate check failed: %s", exc)

    try:
        ai_response = service.handle(
            request,
            client_identity=resolved,
            rate_limit_remaining=rate_limit_remaining,
            quota_remaining=quota_remaining,
        )
        comment = map_ai_response_to_marine_comment(ai_response, report)
        if comment.source != "fallback":
            cache.set(cache_key, comment)
        return comment
    except Exception as exc:
        from ai_assistant.openai_errors import classify_openai_failure, sanitize_log_message

        reason = classify_openai_failure(exc)
        _logger.warning(
            "Marine AI comment generation failed [%s]: %s",
            reason,
            sanitize_log_message(str(exc)),
        )
        comment = build_deterministic_marine_comment(report, reason=reason)
        return comment


def _resolve_catch_context(spot_id: Optional[str]) -> Optional[Dict[str, Any]]:
    if not spot_id:
        return None
    try:
        from marine_intelligence.catch_context import build_catch_context_for_spot
        from marine_intelligence.dependencies import (
            get_catch_record_store,
            get_spot_intelligence_store,
        )

        ctx = build_catch_context_for_spot(
            spot_id,
            spot_store=get_spot_intelligence_store(),
            catch_store=get_catch_record_store(),
        )
        if not ctx.get("found"):
            return None
        return ctx
    except Exception as exc:
        _logger.warning("Catch context resolution failed for spot %s: %s", spot_id, exc)
        return None
