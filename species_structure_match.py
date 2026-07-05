"""
Heuristic coupling of hotspot bathymetric/structure cues with OBIS/GBIF species names.

Not predictive of catch; aligns regional occurrence labels with terrain-derived behavior guesses.
"""

from __future__ import annotations

from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

_ARCHETYPE_KEYS = (
    "ambush_predator",
    "structure_oriented",
    "mid_depth_predator",
    "demersal_bottom",
    "transitional_reef",
    "pelagic_predator",
)

def _sanitize_tuple_rules() -> Tuple[Tuple[Tuple[str, ...], str, str], ...]:
    out: List[Tuple[Tuple[str, ...], str, str]] = []
    seen: set[str] = set()
    raw = (
        (("dicentrarchus", "morone"), "seabass", "ambush_predator"),
        (("epinephelus", "mycteroperca", "cephalopholis", "hyporthodus", "variola"), "grouper", "structure_oriented"),
        (("lutjanus", "rhomboplites", "macolor"), "snapper", "mid_depth_predator"),
        (("seriola", "seriolina"), "amberjack", "pelagic_predator"),
        (("sparus", "diplodus", "pagrus", "pagellus", "sparidae"), "sea_bream", "transitional_reef"),
        (("mullus", "upeneus", "nematistiidae"), "goatfish", "demersal_bottom"),
        (("merluccius", "phycis", "zeus"), "demersal_predator", "demersal_bottom"),
        (("scomber", "auxis"), "mackerel", "pelagic_predator"),
        (("scomberomorus",), "Spanish_mackerel", "pelagic_predator"),
        (("thunnus", "elagatis", "katsuwonus"), "pelagic_gamefish", "pelagic_predator"),
        (("trachurus", "decapterus"), "jack_mackerel", "mid_depth_predator"),
        (("trigla", "chelidonichthys"), "gurnard", "demersal_bottom"),
        (("pegusa", "solea", "bothus", "microchirus"), "flatfish", "demersal_bottom"),
        (("xiphias",), "swordfish", "pelagic_predator"),
        (("mugil", "liza"), "mullet", "transitional_reef"),
        (("blenniidae", "parablennius"), "blenny", "structure_oriented"),
        (("scorpaena", "pterois", "sebastes"), "scorpionfish", "structure_oriented"),
        (("acanthurus", "zebrasoma"), "surgeonfish", "transitional_reef"),
        (("serranus", "anthias"), "comber_anthias", "structure_oriented"),
        (("ballistidae", "balistes", "monacanthidae"), "triggerfish", "structure_oriented"),
        (("anguilla", "conger", "muraena"), "eel", "structure_oriented"),
    )
    for tu in raw:
        slug = tu[1]
        if not slug or slug in seen:
            continue
        seen.add(slug)
        out.append(tu)
    return tuple(out)


GENUS_ARCHETYPE_RULES = _sanitize_tuple_rules()

_FORBIDDEN_REASON = frozenset(
    ("guaranteed", "definitely", "certain", "certainty", "proof", "fish are here", "will catch", "always catch")
)


def _as_float(v: Any) -> float:
    try:
        if v is None:
            return 0.0
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _norm_scientific(name: str) -> str:
    return str(name or "").strip().lower()


def map_scientific_to_group(name: str) -> Optional[Tuple[str, str]]:
    """
    Map a scientific name (or fragment) to (canonical_group_slug, archetype_key).
    """
    n = _norm_scientific(name)
    if len(n) < 3:
        return None
    genus = n.replace(".", "").split()[0] if n.split() else n
    for tokens, slug, arch in GENUS_ARCHETYPE_RULES:
        for tok in tokens:
            tl = tok.lower()
            if len(tl) < 3:
                continue
            if genus == tl or genus.startswith(tl) or n.startswith(tl + " "):
                return (slug, arch)
    return None


def _hotspot_archetype_scores(hotspot: Mapping[str, Any]) -> Dict[str, float]:
    m = hotspot.get("supporting_metrics")
    m = m if isinstance(m, Mapping) else {}
    ft = str(hotspot.get("feature_type", "")).lower()

    slope = _as_float(m.get("slope"))
    cd = _as_float(m.get("contour_density"))
    structure = _as_float(m.get("structure_score"))
    ridge_p = _as_float(m.get("ridge_likelihood"))
    basin_p = _as_float(m.get("basin_likelihood"))
    transition = _as_float(m.get("transition_band"))
    drop_px = _as_float(m.get("dropoff_proximity"))
    local_relief = _as_float(m.get("local_relief"))
    coast_px = _as_float(m.get("coast_distance_px"))

    scores: Dict[str, float] = {k: 0.0 for k in _ARCHETYPE_KEYS}

    if "drop" in ft:
        scores["ambush_predator"] += 0.55
    if "ridge" in ft:
        scores["structure_oriented"] += 0.45
    if "basin" in ft:
        scores["demersal_bottom"] += 0.45
    if "shelf" in ft:
        scores["transitional_reef"] += 0.35
        scores["mid_depth_predator"] += 0.30

    scores["ambush_predator"] += min(0.55, 0.35 * slope + 0.25 * cd + 0.15 * drop_px + 0.10 * local_relief)
    scores["structure_oriented"] += min(0.55, 0.40 * structure + 0.35 * ridge_p + 0.12 * local_relief)
    scores["mid_depth_predator"] += min(0.50, 0.40 * transition + 0.18 * structure + 0.12 * slope)
    scores["demersal_bottom"] += min(0.55, 0.45 * basin_p + 0.20 * max(0.0, 1.0 - slope) * 0.5)
    scores["transitional_reef"] += min(0.50, 0.40 * transition + 0.18 * (1.0 if coast_px < 12.0 else 0.12))
    scores["pelagic_predator"] += min(0.45, 0.15 * (1.0 - structure) + 0.10 * (1.0 - basin_p))

    for k in scores:
        scores[k] = max(0.0, min(1.0, scores[k]))
    return scores


def _structure_phrase(hotspot: Mapping[str, Any]) -> str:
    m = hotspot.get("supporting_metrics")
    m = m if isinstance(m, Mapping) else {}
    ft = str(hotspot.get("feature_type", "")).lower()
    slope = _as_float(m.get("slope"))
    transition = _as_float(m.get("transition_band"))
    ridge_p = _as_float(m.get("ridge_likelihood"))
    basin_p = _as_float(m.get("basin_likelihood"))

    if "drop" in ft or slope > 0.55:
        return "belirgin batimetrik kırılım (dik kontur / kırığı sinyali)"
    if "ridge" in ft or ridge_p > 0.50:
        return "sığınma odaklı hareketin yoğunlaşabileceği sırt yapısı"
    if "basin" in ft or basin_p > 0.50:
        return "diple bağlantılı hareket için uygun yumuşak çanak tipi relieff"
    if "shelf" in ft or transition > 0.55:
        return "raf / derinlik geçiş bandı"
    if transition > 0.45:
        return "orta derinlikte geçiş bandı"
    return "harita metriklerinden gelen karma kontur ve yapı göstergeleri"


def _safe_reason(text: str) -> bool:
    low = text.lower()
    return not any(b in low for b in _FORBIDDEN_REASON)


def _short_sci(name: str, max_len: int = 44) -> str:
    s = str(name).strip()
    if len(s) <= max_len:
        return s
    return s[: max_len - 1] + "…"


def compute_species_matches(
    hotspot: Mapping[str, Any],
    regional_species_names: Sequence[str],
    *,
    max_items: int = 3,
) -> List[Dict[str, str]]:
    """
    Returns up to ``max_items`` dicts: species (group slug), confidence, reason.
    Empty when no mappable regional names or no overlap with structure scores.
    """
    if not regional_species_names:
        return []

    h_scores = _hotspot_archetype_scores(hotspot)
    struct_phrase = _structure_phrase(hotspot)

    ranked: List[Tuple[float, str, str, str]] = []
    for idx, sci in enumerate(regional_species_names):
        mapped = map_scientific_to_group(sci)
        if mapped is None:
            continue
        slug, arch = mapped
        base = h_scores.get(arch, 0.0)
        decay = max(0.72, 1.0 - 0.035 * float(idx))
        score = min(1.0, base * decay)
        if score < 0.02:
            continue
        ranked.append((score, slug, sci, arch))

    ranked.sort(key=lambda t: t[0], reverse=True)

    out: List[Dict[str, str]] = []
    used_slugs: set[str] = set()
    for score, slug, sci, _arch in ranked:
        if slug in used_slugs:
            continue
        used_slugs.add(slug)
        if score >= 0.48:
            conf = "yüksek"
        elif score >= 0.28:
            conf = "orta"
        else:
            conf = "düşük"

        label = slug.replace("_", " ").strip().lower()

        reason = (
            f"Bu çizim için bölgesel bulun kayıtlarında {_short_sci(sci)} yer alır; "
            f"yerel yapı metrikleri {struct_phrase} uygunluğu düşündürür. "
            f"{label}-benzeri davranış ile gevşek bir örtüşme olasılığı vardır — hipotezdır; doğrudan alanda bulundukları iddia edilmez."
        )
        if not _safe_reason(reason):
            continue
        out.append({"species": label, "confidence": conf, "reason": reason})
        if len(out) >= max_items:
            break

    return out
