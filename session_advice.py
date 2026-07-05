"""
Oturum düzeyinde kısa yönlendirme metni — olasılıksal, tahmin iddiası taşımayan.

En fazla üç cümle; ``top_recommendations`` sırasına göre üst önerilere atıf yapar.
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Mapping, Sequence

_FORBIDDEN_SUBSTR = (
    "kesin avlan",
    "mutlaka avlan",
    "balık burada kesin",
    "guaranteed",
    "will catch",
    "fish are here",
)


def _safe(text: str) -> str:
    low = text.lower()
    if any(b in low for b in _FORBIDDEN_SUBSTR):
        return (
            "Bu ekranı rahat bir plan olarak görün: haritadaki sıcak çizgiler yalnızca fikir verir; "
            "hava, gelgit ve sezginiz yine birincil (burada kesinlik yoktur)."
        )
    return text.strip()


def _f(m: Mapping[str, Any], key: str, default: float = 0.0) -> float:
    try:
        v = m.get(key)
        if v is None:
            return default
        return float(v)
    except (TypeError, ValueError):
        return default


def _terrain_long(h: Mapping[str, Any]) -> str:
    """Küçük harfle başlayan tamlayıcı cümlecik (nokta yok)."""
    ft = str(h.get("feature_type", "")).lower()
    m = h.get("supporting_metrics")
    m = m if isinstance(m, Mapping) else {}
    drop_p = _f(m, "dropoff_proximity")
    ridge_p = _f(m, "ridge_likelihood")
    basin_p = _f(m, "basin_likelihood")
    trans = _f(m, "transition_band")
    struct = _f(m, "structure_score")

    if "drop" in ft or drop_p > 0.52:
        return "bu haritada daha belirgin derinlik kırığı / basamak hattına yakın"
    if "ridge" in ft or ridge_p > 0.42 or struct > 0.54:
        return "sırt ve yapı sinyallerinin daha güçlü göründüğü bölgede"
    if "basin" in ft or basin_p > 0.44:
        return "daha yumuşak çanak tarzı bir relef üzerinde"
    if "shelf" in ft or trans > 0.48:
        return "raf / geçiş bandı boyunca"
    return "bu batimetri işaretinde"


def _terrain_short(h: Mapping[str, Any]) -> str:
    ft = str(h.get("feature_type", "")).lower()
    m = h.get("supporting_metrics")
    m = m if isinstance(m, Mapping) else {}
    drop_p = _f(m, "dropoff_proximity")
    ridge_p = _f(m, "ridge_likelihood")
    if "drop" in ft or drop_p > 0.52:
        return "belirgin derinlik kırığı"
    if "ridge" in ft or ridge_p > 0.42:
        return "sırt tarzı yapı"
    if "basin" in ft:
        return "çanak tipi dip"
    return "bu harita özelliği"


def build_session_advice(
    hotspots: Sequence[Mapping[str, Any]],
    top_recommendation_ids: Sequence[int],
) -> str:
    """
    1–3 cümle; ``top_recommendation_ids`` sırasına göre Nokta #1 / #2 atfı.
    """
    hs = [h for h in hotspots if isinstance(h, Mapping)]
    if not hs:
        return _safe(
            "Hazır olduğunuzda haritayı sakin şekilde tarayın; bu ekran nazik bir plan ipucudur, "
            "günün sabit senaryosu değildir."
        )

    by_id = {int(h.get("id", -1)): h for h in hs}
    ordered: List[Mapping[str, Any]] = []
    seen: set[int] = set()
    for raw in top_recommendation_ids:
        hid = int(raw)
        if hid in seen:
            continue
        h = by_id.get(hid)
        if h is not None:
            ordered.append(h)
            seen.add(hid)
        if len(ordered) >= 3:
            break

    if not ordered:
        tmp = sorted(hs, key=lambda x: int(x.get("recommendation_rank", 10**9)))
        ordered = tmp[:3]

    if not ordered:
        return _safe(
            "İşaretli alanları kaba birer fikir olarak kullanın — yerel koşullar ve sizin gözünüz hâlâ belirleyicidir."
        )

    first = ordered[0]
    s1 = (
        f"Önce Nokta #1’e yaklaşmayı düşünün ({_terrain_long(first)}); sıralı listede "
        "tentatif ilk duraktır — ısırığın gelmesi garanti değildir."
    )

    if len(ordered) == 1:
        text = (
            f"{s1} "
            "Diğer işaretler bekleyebilir; her pozisyonu kolayca değiştirebileceğiniz denemeler gibi görün."
        )
        text = _cap_sentences(text, max_sentences=3)
        return _safe(text)

    second = ordered[1]
    s2 = (
        "Yaklaşık 20–30 dakika sakin kalırsa Nokta #2’ye kaymayı düşünün "
        f"({_terrain_short(second)}); aynı kısa listede sıradaki seçenektir."
    )
    s3 = (
        "Daha düşük sıradakileri başta atlayabilirsiniz — rüzgâr, gelgit veya sezginiz değişirse "
        "geri dönmek serbest (hiçbiri kesin vaat değildir)."
    )
    joined = _cap_sentences(f"{s1} {s2} {s3}", max_sentences=3)
    return _safe(joined)


def _cap_sentences(text: str, *, max_sentences: int) -> str:
    t = " ".join(text.split())
    if not t:
        return t
    parts = re.split(r"(?<=[.!?])\s+", t)
    parts = [p.strip() for p in parts if p.strip()]
    if not parts:
        return t
    return " ".join(parts[:max_sentences])
