from __future__ import annotations

from typing import Any, Dict, List, Mapping, Optional, Sequence

from ai_assistant.captain_atlas import (
    CAPTAIN_ATLAS_NAME,
    captain_atlas_fallback_summary,
    persona_metadata,
)
from ai_assistant.models import (
    AiConfidence,
    AiFishingAssistantRequestModel,
    AiFishingAssistantResponseModel,
    AiStructuredPayloadModel,
    HotspotInsightModel,
    RecommendedActionModel,
    TRUST_NOTE_TR,
)


class AiAssistantFallbackBuilder:
    """AI kullanılamadığında deterministik yanıt — mevcut analiz metinlerinden."""

    def build(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        prompt_version: str,
        reason: str,
        processing_ms: int,
    ) -> AiFishingAssistantResponseModel:
        if request.scope == "marine_coordinate":
            return self._build_marine_coordinate_fallback(
                request,
                prompt_version=prompt_version,
                reason=reason,
                processing_ms=processing_ms,
            )
        if request.scope == "marine_compare":
            return self._build_marine_compare_fallback(
                request,
                prompt_version=prompt_version,
                reason=reason,
                processing_ms=processing_ms,
            )
        analysis = request.analysis
        if analysis is None:
            meta = persona_metadata()
            return AiFishingAssistantResponseModel(
                source="fallback",
                summary_tr=captain_atlas_fallback_summary(
                    "Analiz verisi eksik — planlama fikri sınırlıdır."
                ),
                fallback_reason=reason or "missing_analysis",
                prompt_version=prompt_version,
                processing_ms=processing_ms,
                conditions_comment_tr="",
                species_comment_tr="",
                confidence="low",
                **meta,
            )
        hotspots = list(analysis.hotspots)
        top_ids = list(analysis.top_recommendations)

        ordered = _order_hotspots(hotspots, top_ids, request.focus_hotspot_id, request.scope)
        summary = captain_atlas_fallback_summary(_build_summary(analysis.session_advice, ordered))
        actions = _build_actions(ordered)
        insights = _build_insights(ordered)
        conditions = _conditions_comment(ordered)
        species = _species_comment(ordered)
        limitations = _limitations(analysis, request.scope)
        safety = _default_safety_reminders()

        payload = AiStructuredPayloadModel(
            summary_tr=summary,
            confidence="low",
            recommended_actions=actions,
            hotspot_insights=insights,
            conditions_comment_tr=conditions,
            species_comment_tr=species,
            limitations_tr=limitations,
            safety_reminders_tr=safety,
        )
        return _to_response(
            payload,
            source="fallback",
            model=None,
            prompt_version=prompt_version,
            fallback_reason=reason,
            processing_ms=processing_ms,
            cache_hit=False,
        )

    def _build_marine_compare_fallback(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        prompt_version: str,
        reason: str,
        processing_ms: int,
    ) -> AiFishingAssistantResponseModel:
        compare = request.marine_compare_context
        comparison = (compare.comparison or {}) if compare else {}
        left_label = compare.left_label if compare else "A"
        right_label = compare.right_label if compare else "B"
        summary_text = comparison.get("summary_tr") or (
            f"{left_label} ile {right_label} karşılaştırması — olasılıksal değerlendirme."
        )
        summary = captain_atlas_fallback_summary(str(summary_text))
        actions: List[RecommendedActionModel] = []
        winner = comparison.get("winner")
        if winner == "tie":
            actions.append(
                RecommendedActionModel(
                    priority=1,
                    title_tr="Benzer koşullar",
                    detail_tr=f"{left_label} ve {right_label} birbirine yakın görünüyor.",
                )
            )
        elif winner in {"left", "right"}:
            winner_label = comparison.get("winner_label") or (
                left_label if winner == "left" else right_label
            )
            actions.append(
                RecommendedActionModel(
                    priority=1,
                    title_tr=f"{CAPTAIN_ATLAS_NAME} karşılaştırması",
                    detail_tr=str(comparison.get("decision_delta_tr") or summary_text),
                )
            )
            actions.append(
                RecommendedActionModel(
                    priority=2,
                    title_tr="Daha uygun görünen",
                    detail_tr=f"{winner_label} şu an biraz daha mantıklı görünüyor.",
                )
            )
        payload = AiStructuredPayloadModel(
            summary_tr=summary,
            confidence="low",
            recommended_actions=actions or [
                RecommendedActionModel(
                    priority=1,
                    title_tr="Koşulları doğrulayın",
                    detail_tr="Yerel hava ve deniz raporlarını kontrol ederek plan yapın.",
                )
            ],
            hotspot_insights=[],
            conditions_comment_tr=comparison.get("risk_note_tr") or "",
            species_comment_tr="Tür tahmini bu kapsamda yapılmaz.",
            limitations_tr=["Karşılaştırma yorumu deterministik özetten üretildi."],
            safety_reminders_tr=_default_safety_reminders(),
        )
        return _to_response(
            payload,
            source="fallback",
            model=None,
            prompt_version=prompt_version,
            fallback_reason=reason,
            processing_ms=processing_ms,
            cache_hit=False,
        )

    def _build_marine_coordinate_fallback(
        self,
        request: AiFishingAssistantRequestModel,
        *,
        prompt_version: str,
        reason: str,
        processing_ms: int,
    ) -> AiFishingAssistantResponseModel:
        marine = request.marine_context
        decision = (marine.decision or {}) if marine else {}
        fishing = (marine.fishing_score or {}) if marine else {}
        timeline = (marine.decision_timeline or []) if marine else []
        go_score = decision.get("go_score")
        risk = fishing.get("risk_score")
        decision_label = decision.get("fishing_decision") or "borderline"
        summary = captain_atlas_fallback_summary(
            decision.get("short_summary_tr")
            or (
                f"Koordinat için karar: {decision_label} "
                f"(git skoru {go_score}, risk {risk}). Bu yalnızca planlama fikridir."
            )
        )
        best_slot = next((t for t in timeline if t.get("is_best_slot")), None)
        if best_slot is None and timeline:
            best_slot = max(timeline, key=lambda t: t.get("go_score") or 0)
        best_time_note = ""
        if best_slot:
            best_time_note = (
                f" En iyi pencere yaklaşık {best_slot.get('time')} "
                f"(git {best_slot.get('go_score')}) — tahmine dayalıdır."
            )
        risk_note = marine.most_sensitive_factor_tr if marine else None
        if not risk_note and risk is not None:
            risk_note = f"Risk skoru {risk}/100 — resmi deniz ve hava uyarılarını kontrol edin."
        actions: List[RecommendedActionModel] = []
        if decision.get("best_action_tr"):
            actions.append(
                RecommendedActionModel(
                    priority=1,
                    title_tr=f"{CAPTAIN_ATLAS_NAME} önerisi",
                    detail_tr=str(decision["best_action_tr"]),
                )
            )
        if marine and marine.scenario_top_items:
            top = marine.scenario_top_items[0]
            actions.append(
                RecommendedActionModel(
                    priority=2,
                    title_tr=str(top.get("title_tr") or "Senaryo"),
                    detail_tr=str(top.get("delta_summary_tr") or "Koşul değişimine dikkat edin."),
                )
            )
        if not actions:
            actions.append(
                RecommendedActionModel(
                    priority=1,
                    title_tr="Koşulları doğrulayın",
                    detail_tr="Yerel hava ve deniz raporlarını kontrol ederek plan yapın.",
                )
            )
        payload = AiStructuredPayloadModel(
            summary_tr=summary,
            confidence="low",
            recommended_actions=actions,
            hotspot_insights=[],
            conditions_comment_tr=(risk_note or "Deniz koşulları değişken olabilir.") + best_time_note,
            species_comment_tr="Tür tahmini bu kapsamda yapılmaz; yerel av yönetmeliğine uyun.",
            limitations_tr=[
                "AI yorumu kullanılamadı veya sınırlı — deterministik rapor özeti gösteriliyor.",
            ],
            safety_reminders_tr=_default_safety_reminders(),
        )
        return _to_response(
            payload,
            source="fallback",
            model=None,
            prompt_version=prompt_version,
            fallback_reason=reason,
            processing_ms=processing_ms,
            cache_hit=False,
        )


def build_fallback_response(
    request: AiFishingAssistantRequestModel,
    *,
    prompt_version: str,
    reason: str,
    processing_ms: int,
) -> AiFishingAssistantResponseModel:
    return AiAssistantFallbackBuilder().build(
        request,
        prompt_version=prompt_version,
        reason=reason,
        processing_ms=processing_ms,
    )


def _order_hotspots(
    hotspots: Sequence[Any],
    top_ids: Sequence[int],
    focus_id: Optional[int],
    scope: str,
) -> List[Any]:
    if not hotspots:
        return []
    if scope == "hotspot_detail" and focus_id is not None:
        focused = [h for h in hotspots if int(getattr(h, "id", -1)) == int(focus_id)]
        if focused:
            return focused[:1]
    by_id = {int(getattr(h, "id", -1)): h for h in hotspots}
    ordered: List[Any] = []
    seen: set[int] = set()
    for raw in top_ids:
        hid = int(raw)
        item = by_id.get(hid)
        if item is not None and hid not in seen:
            ordered.append(item)
            seen.add(hid)
        if len(ordered) >= 5:
            return ordered
    remainder = sorted(
        hotspots,
        key=lambda x: (
            getattr(x, "recommendation_rank", None)
            if getattr(x, "recommendation_rank", None) is not None
            else 10**9,
            -float(getattr(x, "score", 0.0)),
        ),
    )
    for item in remainder:
        hid = int(getattr(item, "id", -1))
        if hid in seen:
            continue
        ordered.append(item)
        seen.add(hid)
        if len(ordered) >= 5:
            break
    return ordered


def _build_summary(session_advice: Optional[str], ordered: Sequence[Any]) -> str:
    if session_advice and session_advice.strip():
        return session_advice.strip()
    if not ordered:
        return (
            "Henüz yorumlanacak analiz verisi sınırlı; haritayı sakin bir plan olarak "
            "değerlendirin — sonuçlar olasılıksal bir fikirdir."
        )
    first = ordered[0]
    cls = getattr(first, "classification", "C")
    hid = getattr(first, "id", "?")
    rt = (getattr(first, "reasoning_text", None) or "").strip()
    if rt:
        return f"Öncelikli aday Nokta #{hid} ({cls} sınıfı): {rt}"
    return (
        f"Öncelikli aday Nokta #{hid} ({cls} sınıfı) — yapısal skor yüksek görünüyor; "
        "bu yalnızca planlama fikridir."
    )


def _build_actions(ordered: Sequence[Any]) -> List[RecommendedActionModel]:
    actions: List[RecommendedActionModel] = []
    for idx, hotspot in enumerate(ordered[:3], start=1):
        hid = getattr(hotspot, "id", idx)
        rt = (getattr(hotspot, "reasoning_text", None) or "").strip()
        detail = rt or " ".join(getattr(hotspot, "reasoning", [])[:2]).strip()
        if not detail:
            detail = "Bu noktayı kısa bir deneme olarak değerlendirin; sonuç garanti değildir."
        actions.append(
            RecommendedActionModel(
                priority=idx,
                title_tr=f"Nokta #{hid} için olası plan",
                detail_tr=detail,
            )
        )
    if not actions:
        actions.append(
            RecommendedActionModel(
                priority=1,
                title_tr="Haritayı sakin tarayın",
                detail_tr=(
                    "Analiz verisi sınırlı; koşulları gözlemleyerek kısa denemeler yapın."
                ),
            )
        )
    return actions


def _build_insights(ordered: Sequence[Any]) -> List[HotspotInsightModel]:
    insights: List[HotspotInsightModel] = []
    for hotspot in ordered[:5]:
        hid = int(getattr(hotspot, "id", 0))
        cls = getattr(hotspot, "classification", "C")
        rt = (getattr(hotspot, "reasoning_text", None) or "").strip()
        fp = (getattr(hotspot, "fish_prediction", None) or "").strip()
        detail_parts = [p for p in (rt, fp) if p]
        detail = " ".join(detail_parts) if detail_parts else "Yapısal skor ve sınıf bilgisine göre olası aday."
        insights.append(
            HotspotInsightModel(
                hotspot_id=hid,
                headline_tr=f"{cls} sınıfı — Nokta #{hid}",
                detail_tr=detail,
            )
        )
    return insights


def _conditions_comment(ordered: Sequence[Any]) -> str:
    for hotspot in ordered:
        sea = getattr(hotspot, "sea_state", None)
        if sea is None:
            continue
        wave = getattr(sea, "wave_height_m", None)
        temp = getattr(sea, "water_temperature_c", None)
        if wave is not None or temp is not None:
            parts: List[str] = []
            if wave is not None:
                parts.append(f"dalga ~{float(wave):.1f} m")
            if temp is not None:
                parts.append(f"su ~{float(temp):.1f} °C")
            return (
                "Mevcut deniz durumu verisi: "
                + ", ".join(parts)
                + " — hava resmi kaynaklarla doğrulanmalıdır."
            )
    return "Deniz durumu verisi sınırlı; çıkış öncesi resmi hava ve deniz raporlarını kontrol edin."


def _species_comment(ordered: Sequence[Any]) -> str:
    for hotspot in ordered:
        matches = getattr(hotspot, "species_match", None) or []
        names: List[str] = []
        for item in matches[:3]:
            species = getattr(item, "species", None) or (
                item.get("species") if isinstance(item, Mapping) else None
            )
            if species:
                names.append(str(species))
        if names:
            return (
                "Bölgesel tür eşleşmeleri (olasılıksal): "
                + ", ".join(names)
                + ". Av yönetmeliğine ve mevsime dikkat edin."
            )
        fp = (getattr(hotspot, "fish_prediction", None) or "").strip()
        if fp:
            return f"Tür tahmini (heuristik): {fp}"
    return "Tür verisi sınırlı; yerel av yönetmeliği ve mevsim rehberlerini esas alın."


def _limitations(analysis: Any, scope: str) -> List[str]:
    out: List[str] = []
    mode = (getattr(analysis, "coordinate_mode", None) or "unknown").lower()
    if mode in {"image_space", "unknown"}:
        out.append("Bu analiz fotoğraf/koordinatsız modda; gerçek dünya konumu iddiası yoktur.")
    warn = (getattr(analysis, "user_warning_tr", None) or "").strip()
    if warn:
        out.append(warn)
    rel = (getattr(analysis, "calibration_reliability", None) or "").strip()
    if rel and rel not in {"excellent", "good"}:
        out.append(f"Kalibrasyon güveni: {rel} — konum sapması olabilir.")
    if scope == "live_context":
        out.append("Canlı skor olasılıksal bir göstergedir; av başarısı vaat edilmez.")
    if not out:
        out.append("Sonuçlar planlama amaçlıdır; resmi deniz haritası birincil referanstır.")
    return out[:4]


def _default_safety_reminders() -> List[str]:
    return [
        "Resmi deniz haritaları, şamandıra ve kıyı emniyet bilgilerine uyun.",
        "Hava ve deniz koşulları hızla değişebilir; kararınızı yalnızca bu uygulamaya dayanmayın.",
    ]


def _to_response(
    payload: AiStructuredPayloadModel,
    *,
    source: str,
    model: Optional[str],
    prompt_version: str,
    fallback_reason: Optional[str],
    processing_ms: int,
    cache_hit: bool,
) -> AiFishingAssistantResponseModel:
    meta = persona_metadata()
    return AiFishingAssistantResponseModel(
        source=source,  # type: ignore[arg-type]
        model=model,
        cache_hit=cache_hit,
        locale="tr",
        trust_note_tr=TRUST_NOTE_TR,
        prompt_version=prompt_version,
        summary_tr=payload.summary_tr,
        confidence=payload.confidence,
        recommended_actions=payload.recommended_actions,
        hotspot_insights=payload.hotspot_insights,
        conditions_comment_tr=payload.conditions_comment_tr,
        species_comment_tr=payload.species_comment_tr,
        limitations_tr=payload.limitations_tr,
        safety_reminders_tr=payload.safety_reminders_tr,
        fallback_reason=fallback_reason,
        processing_ms=processing_ms,
        assistant_name=meta["assistant_name"],
        persona_version=meta["persona_version"],
        tone=meta["tone"],
    )
