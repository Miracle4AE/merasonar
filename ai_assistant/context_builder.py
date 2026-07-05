from __future__ import annotations

import hashlib
import json
from typing import Any, Dict, List, Mapping, Optional, Sequence

from ai_assistant.models import (
    AiFishingAssistantRequestModel,
    AnalysisPayloadModel,
    HotspotInputModel,
    LiveContextInputModel,
)

_MAX_HOTSPOTS = 15
_MAX_REASONING_ITEMS = 3
_MAX_SPECIES = 3
_MAX_METRIC_KEYS = 5
_IMAGE_SPACE_MODES = frozenset({"image_space", "unknown"})


class AiAssistantContextBuilder:
    """İstemci analiz yükünü token-safe, deterministik bağlama dönüştürür."""

    def build(self, request: AiFishingAssistantRequestModel) -> Dict[str, Any]:
        if request.scope == "marine_coordinate":
            return self._build_marine_coordinate_context(request)
        if request.scope == "marine_compare":
            return self._build_marine_compare_context(request)
        analysis = request.analysis
        if analysis is None:
            return {"scope": request.scope, "locale": request.locale}
        coordinate_mode = (analysis.coordinate_mode or "unknown").strip().lower()
        hotspots = self._select_hotspots(
            analysis,
            request.focus_hotspot_id,
            request.scope,
            request.live_context,
        )
        live_summary = _live_context_summary(request.live_context)
        live_warnings = _live_context_warnings(request.live_context, coordinate_mode)
        matched_nearest_id = _matched_nearest_hotspot_id(hotspots, request.live_context)

        context: Dict[str, Any] = {
            "scope": request.scope,
            "locale": request.locale,
            "coordinate_mode": coordinate_mode,
            "calibration_quality": analysis.calibration_quality,
            "calibration_reliability": analysis.calibration_reliability,
            "user_warning_tr": _trim_text(analysis.user_warning_tr, 400),
            "session_advice": _trim_text(analysis.session_advice, 600),
            "top_recommendations": list(analysis.top_recommendations[:8]),
            "image_size": analysis.image_size,
            "boat": _boat_summary(analysis),
            "diagnostics": _diagnostics_summary(analysis),
            "hotspots": [_hotspot_summary(h, coordinate_mode) for h in hotspots],
            "focus_hotspot_id": request.focus_hotspot_id,
            "user_question": _trim_text(request.user_question, 500),
            "live_context": live_summary,
            "live_context_warnings": live_warnings,
            "matched_nearest_hotspot_id": matched_nearest_id,
            "vision_attached": False,
        }
        return context

    def _build_marine_coordinate_context(
        self,
        request: AiFishingAssistantRequestModel,
    ) -> Dict[str, Any]:
        marine = request.marine_context
        if marine is None:
            return {"scope": "marine_coordinate", "locale": request.locale, "marine": {}}
        ctx: Dict[str, Any] = {
            "scope": "marine_coordinate",
            "locale": request.locale,
            "coordinate": {"lat": round(float(marine.lat), 5), "lon": round(float(marine.lon), 5)},
            "decision": marine.decision,
            "decision_timeline": marine.decision_timeline[:6],
            "fishing_score": marine.fishing_score,
            "consensus_summary": marine.consensus_summary,
            "provider_comparison_summary": marine.provider_comparison_summary,
            "explainability": marine.explainability,
            "scenario_top_items": marine.scenario_top_items[:3],
            "weather_summary": marine.weather_summary,
            "wind_summary": marine.wind_summary,
            "marine_summary": marine.marine_summary,
            "astronomy_summary": marine.astronomy_summary,
            "most_sensitive_factor_tr": _trim_text(marine.most_sensitive_factor_tr, 300),
            "user_question": _trim_text(request.user_question, 500),
            "vision_attached": False,
        }
        if marine.catch_context:
            ctx["catch_context"] = marine.catch_context
            ctx["catch_context_instructions"] = (
                "Bu spotta kayıtlı geçmiş av verileri olasılıksal bağlamdır; "
                "kesin kanıt veya garanti iddiası yapma. "
                "'Geçmiş kayıtlarına göre...' veya 'Bu spotta kayıtların...' gibi dil kullan."
            )
        return ctx

    def _build_marine_compare_context(
        self,
        request: AiFishingAssistantRequestModel,
    ) -> Dict[str, Any]:
        compare = request.marine_compare_context
        if compare is None:
            return {"scope": "marine_compare", "locale": request.locale}
        return {
            "scope": "marine_compare",
            "locale": request.locale,
            "left_label": compare.left_label,
            "right_label": compare.right_label,
            "comparison": compare.comparison,
            "left_summary": compare.left_summary,
            "right_summary": compare.right_summary,
            "left_catch_context": compare.left_catch_context,
            "right_catch_context": compare.right_catch_context,
            "compare_instructions": (
                "İki noktayı kısa karşılaştır; kesinlik iddiası yapma. "
                "Hangisi daha mantıklı görünüyor, risk farkı ve en iyi zaman penceresini olasılıksal dilde açıkla."
            ),
        }

    def build_fingerprint(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        prompt_version: str,
    ) -> str:
        context = self.build(request)
        if request.scope == "marine_compare":
            payload = {
                "prompt_version": prompt_version,
                "scope": "marine_compare",
                "left_label": context.get("left_label"),
                "right_label": context.get("right_label"),
                "winner": (context.get("comparison") or {}).get("winner"),
                "score_delta": (context.get("comparison") or {}).get("score_delta"),
            }
            raw = json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
            return hashlib.sha256(raw.encode("utf-8")).hexdigest()
        if request.scope == "marine_coordinate":
            payload = {
                "prompt_version": prompt_version,
                "scope": "marine_coordinate",
                "coordinate": context.get("coordinate"),
                "decision_go": (context.get("decision") or {}).get("go_score"),
                "timeline": context.get("decision_timeline"),
            }
            raw = json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
            return hashlib.sha256(raw.encode("utf-8")).hexdigest()
        payload = {
            "prompt_version": prompt_version,
            "scope": context["scope"],
            "focus_hotspot_id": context.get("focus_hotspot_id"),
            "coordinate_mode": context["coordinate_mode"],
            "top_recommendations": context["top_recommendations"],
            "session_advice": context.get("session_advice"),
            "user_question": context.get("user_question"),
            "live_context": context.get("live_context"),
            "hotspots": [
                {
                    "id": h["id"],
                    "score": h["score"],
                    "classification": h["classification"],
                    "rank": h.get("recommendation_rank"),
                }
                for h in context["hotspots"]
            ],
        }
        raw = json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    def _select_hotspots(
        self,
        analysis: AnalysisPayloadModel,
        focus_hotspot_id: Optional[int],
        scope: str,
        live_context: Optional[LiveContextInputModel],
    ) -> List[HotspotInputModel]:
        hotspots = list(analysis.hotspots)
        if not hotspots:
            return []

        if scope == "hotspot_detail" and focus_hotspot_id is not None:
            focused = [h for h in hotspots if h.id == focus_hotspot_id]
            if focused:
                return focused[:1]

        nearest_id: Optional[int] = None
        if scope == "live_context" and live_context is not None:
            nearest_id = live_context.nearest_hotspot
            if nearest_id is not None:
                focused = [h for h in hotspots if h.id == nearest_id]
                if focused:
                    remainder = [h for h in hotspots if h.id != nearest_id]
                    ordered = self._order_hotspots(analysis, remainder)
                    return focused[:1] + ordered[: max(0, _MAX_HOTSPOTS - 1)]

        return self._order_hotspots(analysis, hotspots)

    def _order_hotspots(
        self,
        analysis: AnalysisPayloadModel,
        hotspots: Sequence[HotspotInputModel],
    ) -> List[HotspotInputModel]:
        if not hotspots:
            return []
        top_ids = analysis.top_recommendations
        if top_ids:
            by_id = {h.id: h for h in hotspots}
            ordered: List[HotspotInputModel] = []
            seen: set[int] = set()
            for hid in top_ids:
                item = by_id.get(int(hid))
                if item is not None and item.id not in seen:
                    ordered.append(item)
                    seen.add(item.id)
                if len(ordered) >= _MAX_HOTSPOTS:
                    return ordered
            remainder = sorted(
                (h for h in hotspots if h.id not in seen),
                key=lambda x: (
                    x.recommendation_rank if x.recommendation_rank is not None else 10**9,
                    -x.score,
                ),
            )
            ordered.extend(remainder[: max(0, _MAX_HOTSPOTS - len(ordered))])
            return ordered

        return sorted(
            hotspots,
            key=lambda x: (
                x.recommendation_rank if x.recommendation_rank is not None else 10**9,
                -x.score,
            ),
        )[:_MAX_HOTSPOTS]


def _trim_text(value: Optional[str], max_len: int) -> Optional[str]:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    if len(trimmed) <= max_len:
        return trimmed
    return trimmed[: max_len - 1] + "…"


def _boat_summary(analysis: AnalysisPayloadModel) -> Optional[Dict[str, Any]]:
    boat = analysis.boat
    if boat is None:
        return None
    out: Dict[str, Any] = {}
    if boat.smoothed_gps:
        out["smoothed_gps"] = {
            "lat": round(float(boat.smoothed_gps.get("lat", 0.0)), 5),
            "lon": round(float(boat.smoothed_gps.get("lon", 0.0)), 5),
        }
    if boat.boat_anchor_confidence is not None:
        out["boat_anchor_confidence"] = round(float(boat.boat_anchor_confidence), 3)
    return out or None


def _diagnostics_summary(analysis: AnalysisPayloadModel) -> Optional[Dict[str, Any]]:
    diag = analysis.diagnostics
    if diag is None:
        return None
    out: Dict[str, Any] = {}
    if diag.mapping_mode:
        out["mapping_mode"] = diag.mapping_mode
    if diag.enrichment_enabled is not None:
        out["enrichment_enabled"] = diag.enrichment_enabled
    if diag.transform_quality is not None:
        out["transform_quality"] = round(float(diag.transform_quality), 3)
    if diag.georeference_error_m is not None:
        out["georeference_error_m"] = round(float(diag.georeference_error_m), 1)
    return out or None


def _live_context_summary(live: Any) -> Optional[Dict[str, Any]]:
    if live is None:
        return None
    out: Dict[str, Any] = {}
    if live.current_lat is not None and live.current_lon is not None:
        out["current_lat"] = round(float(live.current_lat), 5)
        out["current_lon"] = round(float(live.current_lon), 5)
    if live.gps_accuracy_m is not None:
        out["gps_accuracy_m"] = round(float(live.gps_accuracy_m), 1)
    if live.live_score is not None:
        out["live_score"] = int(live.live_score)
    if live.rating:
        out["rating"] = str(live.rating).strip()
    if live.reasoning:
        out["reasoning"] = _trim_text(live.reasoning, 400)
    if live.nearest_hotspot is not None:
        out["nearest_hotspot"] = int(live.nearest_hotspot)
    if live.distance_to_nearest is not None:
        out["distance_to_nearest"] = round(float(live.distance_to_nearest), 1)
    if live.bearing_to_nearest is not None:
        out["bearing_to_nearest"] = round(float(live.bearing_to_nearest), 1)
    if live.coordinate_mode:
        out["coordinate_mode"] = str(live.coordinate_mode).strip().lower()
    return out or None


def _live_context_warnings(
    live: Optional[LiveContextInputModel],
    analysis_coordinate_mode: str,
) -> List[str]:
    if live is None:
        return []
    warnings: List[str] = []
    live_mode = (live.coordinate_mode or analysis_coordinate_mode or "unknown").strip().lower()
    if live_mode in _IMAGE_SPACE_MODES:
        warnings.append(
            "coordinate_mode image_space/unknown: gerçek dünya konum veya mesafe iddiası yapma."
        )
    if live.gps_accuracy_m is not None and float(live.gps_accuracy_m) > 50.0:
        warnings.append("GPS doğruluğu düşük; konum belirsizliğini yanıtta belirt.")
    return warnings


def _matched_nearest_hotspot_id(
    hotspots: Sequence[HotspotInputModel],
    live: Optional[LiveContextInputModel],
) -> Optional[int]:
    if live is None or live.nearest_hotspot is None:
        return None
    target = int(live.nearest_hotspot)
    for h in hotspots:
        if h.id == target:
            return target
    return None


def _hotspot_summary(h: HotspotInputModel, coordinate_mode: str) -> Dict[str, Any]:
    out: Dict[str, Any] = {
        "id": h.id,
        "classification": h.classification,
        "score": round(float(h.score), 3),
        "feature_type": h.feature_type,
        "recommendation_rank": h.recommendation_rank,
        "final_fishing_score": (
            round(float(h.final_fishing_score), 3)
            if h.final_fishing_score is not None
            else None
        ),
        "distance_m": round(float(h.distance_m), 1) if h.distance_m is not None else None,
        "bearing_deg": round(float(h.bearing_deg), 1) if h.bearing_deg is not None else None,
        "reasoning": list(h.reasoning[:_MAX_REASONING_ITEMS]),
        "reasoning_text": _trim_text(h.reasoning_text, 320),
        "fish_prediction": _trim_text(h.fish_prediction, 200),
        "species_match": _species_summary(h.species_match),
        "sea_state": _sea_state_summary(h.sea_state),
    }
    if coordinate_mode not in _IMAGE_SPACE_MODES:
        if h.latitude is not None and h.longitude is not None:
            out["latitude"] = round(float(h.latitude), 5)
            out["longitude"] = round(float(h.longitude), 5)
    out["supporting_metrics"] = _metrics_summary(h.supporting_metrics)
    return out


def _species_summary(matches: Optional[Sequence[Any]]) -> List[Dict[str, str]]:
    if not matches:
        return []
    out: List[Dict[str, str]] = []
    for item in matches[:_MAX_SPECIES]:
        if hasattr(item, "species"):
            out.append(
                {
                    "species": str(item.species),
                    "confidence": str(item.confidence),
                    "reason": _trim_text(str(item.reason), 120) or "",
                }
            )
        elif isinstance(item, Mapping):
            out.append(
                {
                    "species": str(item.get("species", "")),
                    "confidence": str(item.get("confidence", "")),
                    "reason": _trim_text(str(item.get("reason", "")), 120) or "",
                }
            )
    return out


def _sea_state_summary(sea: Any) -> Optional[Dict[str, Any]]:
    if sea is None:
        return None
    out: Dict[str, Any] = {}
    for key in ("wave_height_m", "water_temperature_c", "wind_speed_knots", "source"):
        val = getattr(sea, key, None) if hasattr(sea, key) else (
            sea.get(key) if isinstance(sea, Mapping) else None
        )
        if val is not None:
            out[key] = val if key == "source" else round(float(val), 2)
    return out or None


def _metrics_summary(metrics: Optional[Mapping[str, Any]]) -> Dict[str, float]:
    if not metrics:
        return {}
    numeric: List[tuple[str, float]] = []
    for key, val in metrics.items():
        try:
            numeric.append((str(key), float(val)))
        except (TypeError, ValueError):
            continue
    numeric.sort(key=lambda x: abs(x[1]), reverse=True)
    return {k: round(v, 3) for k, v in numeric[:_MAX_METRIC_KEYS]}
