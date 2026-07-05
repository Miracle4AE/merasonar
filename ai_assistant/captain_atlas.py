from __future__ import annotations

import os
from typing import Any, Mapping, Optional, Tuple

CAPTAIN_ATLAS_NAME = "Captain Atlas"
CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT = "captain_atlas_v1"
CAPTAIN_ATLAS_TONE = "calm_expert"

CAPTAIN_ATLAS_FORBIDDEN_PHRASES = (
    "kesin balık",
    "garanti av",
    "mutlaka git",
    "risk yok",
    "tehlike yok",
    "kesin",
    "garanti",
    "mutlaka",
)

CAPTAIN_ATLAS_FORBIDDEN_WORDS = frozenset({"kesin", "garanti", "mutlaka"})


def get_persona_version() -> str:
    raw = os.getenv("CAPTAIN_ATLAS_PERSONA_VERSION", CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT)
    stripped = (raw or CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT).strip()
    return stripped or CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT


# Geriye dönük test/import uyumluluğu
CAPTAIN_ATLAS_PERSONA_VERSION = CAPTAIN_ATLAS_PERSONA_VERSION_DEFAULT


def persona_metadata() -> dict[str, str]:
    return {
        "assistant_name": CAPTAIN_ATLAS_NAME,
        "persona_version": get_persona_version(),
        "tone": CAPTAIN_ATLAS_TONE,
    }


def resolve_assistant_for_scope(scope: str) -> Tuple[str, str, str]:
    """Tüm AI scope'ları Captain Atlas persona kullanır."""
    _ = scope
    meta = persona_metadata()
    return meta["assistant_name"], meta["persona_version"], meta["tone"]


def captain_atlas_system_prompt(*, prompt_version: str) -> str:
    persona_version = get_persona_version()
    return (
        f"Sen {CAPTAIN_ATLAS_NAME}'sın — deneyimli, sakin ve öğretici bir deniz balıkçılığı "
        "rehberisin. MeraSonar analiz ve deniz verilerine dayanarak yalnızca sana verilen JSON "
        "bağlamını yorumlarsın; yeni koordinat, tür veya derinlik uydurmazsın.\n\n"
        "Ton kuralları:\n"
        "- Türkçe konuş; kısa, net ve denizci dili kullan.\n"
        "- Sakin ve deneyimli bir kaptan gibi rehberlik et; öğretici ol.\n"
        "- Her yorum olasılıksal / tahmine dayalıdır; kesinlik iddiası yok.\n"
        "- «kesin», «garanti», «mutlaka», «risk yok», «tehlike yok» gibi ifadeler kullanma.\n"
        "- Resmi denizcilik, hava ve güvenlik kaynaklarının birincil olduğunu hatırlat.\n"
        "- Resmi denizcilik güvenliğinin yerini almazsın.\n"
        "- Yalnızca istenen JSON şemasına uygun yanıt ver; ek açıklama metni ekleme.\n"
        f"- prompt_version: {prompt_version}\n"
        f"- persona_version: {persona_version}\n"
    )


def captain_atlas_session_summary_task() -> str:
    return (
        f"{CAPTAIN_ATLAS_NAME} olarak oturum geneli av planı yorumu üret.\n"
        "Şunları kapsa (kısa ve net, olasılıksal dil):\n"
        "- Oturum genel değerlendirmesi ve üst öneriler.\n"
        "- En fazla beş hotspot için kısa insight.\n"
        "- Koşullar ve belirsizlikler.\n"
        "Kesin av veya garanti iddiası yapma."
    )


def captain_atlas_hotspot_detail_task(focus_hotspot_id: Optional[int]) -> str:
    hid = focus_hotspot_id if focus_hotspot_id is not None else "?"
    return (
        f"{CAPTAIN_ATLAS_NAME} olarak yalnızca hotspot #{hid} odaklı kısa yorum üret.\n"
        "Diğer noktaları ikincil tut.\n"
        "Kesin av, garanti veya mutlaka git iddiası yapma."
    )


def captain_atlas_live_context_task(context: Mapping[str, Any]) -> str:
    warnings = context.get("live_context_warnings") or []
    matched = context.get("matched_nearest_hotspot_id")
    live = context.get("live_context") or {}
    nearest = live.get("nearest_hotspot")
    parts = [
        f"{CAPTAIN_ATLAS_NAME} olarak canlı tekne/GPS bağlamını analiz özetiyle birleştir.",
        "Şunları kapsa (kısa ve net, olasılıksal dil):",
        "- Şu an teknenin durumu (live_score, rating, GPS doğruluğu).",
        "- En yakın hotspot mantıklı mı? Kalınmalı mı, geçilmeli mi?",
        "- Risk veya belirsizlik (koordinat modu, kalibrasyon, GPS).",
        "- Kısa rota / hareket önerisi.",
        "Kesin av veya garanti iddiası yapma.",
    ]
    if nearest is not None:
        parts.append(
            f"En yakın hotspot id={nearest}; mesafe/bearing live_context içinde varsa kullan."
        )
    if matched is not None:
        parts.append(
            f"Hotspot listesinde eşleşen nearest id={matched}; bu noktayı önceliklendir."
        )
    if warnings:
        parts.append("Uyarılar: " + "; ".join(str(w) for w in warnings))
    return "\n".join(parts)


def captain_atlas_marine_coordinate_task(*, has_catch_context: bool = False) -> str:
    base = (
        f"{CAPTAIN_ATLAS_NAME} olarak Marine Intelligence koordinat raporunu yorumla.\n"
        "Şunları kapsa (kısa ve net, olasılıksal dil):\n"
        "- Bu koordinat bugün av için genel olarak uygun mu?\n"
        "- En iyi zaman penceresi hangisi (decision_timeline)?\n"
        "- Risk nedir (rüzgar, dalga, yağış)?\n"
        "- En hassas faktör nedir (most_sensitive_factor_tr veya scenario)?\n"
        "- Ne zaman beklemek daha mantıklı olabilir?\n"
        "Kesin av, garanti veya mutlaka git iddiası yapma.\n"
        "species_comment_tr alanına balık türü uydurma; genel deniz koşulu yorumu yaz."
    )
    if has_catch_context:
        base += (
            "\nKayıtlı spot geçmiş av verileri (catch_context) varsa olasılıksal bağlam olarak kullan; "
            "geçmiş kayıtları kesin kanıt gibi sunma."
        )
    return base


def captain_atlas_marine_compare_task() -> str:
    return (
        f"{CAPTAIN_ATLAS_NAME} olarak iki deniz noktasını karşılaştır.\n"
        "Şunları kapsa (kısa ve net, olasılıksal dil):\n"
        "- Hangisi bugün av için biraz daha mantıklı görünüyor?\n"
        "- Risk farkı ne?\n"
        "- En iyi zaman penceresi hangisinde?\n"
        "- Berabere veya belirsizse bunu açıkça söyle.\n"
        "Kesin av, garanti veya mutlaka git iddiası yapma.\n"
        "Geçmiş av kayıtları varsa olasılıksal bağlam olarak kullan; kesin kanıt gibi sunma."
    )


def captain_atlas_scope_task(scope: str, context: Mapping[str, Any]) -> str:
    if scope == "hotspot_detail":
        hid = context.get("focus_hotspot_id")
        return captain_atlas_hotspot_detail_task(
            int(hid) if hid is not None else None
        )
    if scope == "live_context":
        return captain_atlas_live_context_task(context)
    if scope == "marine_coordinate":
        has_catch = bool(context.get("catch_context"))
        return captain_atlas_marine_coordinate_task(has_catch_context=has_catch)
    if scope == "marine_compare":
        return captain_atlas_marine_compare_task()
    return captain_atlas_session_summary_task()


def captain_atlas_fallback_prefix() -> str:
    return "Denizden selamlar —"


def captain_atlas_fallback_summary(decision_summary: Optional[str] = None) -> str:
    prefix = captain_atlas_fallback_prefix()
    if decision_summary:
        return f"{prefix} {decision_summary.strip()}"
    return (
        f"{prefix} Rapora göre plan yapabilirsiniz. "
        "Resmi deniz ve hava uyarıları birincil kaynağınızdır."
    )
