"""
POST /api/v1/live_fishing_score — probabilistic live score from GPS + optional chart hotspots.

Does not detect fish; never fabricates coordinates.
"""

from __future__ import annotations

from math import isfinite
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

from geo_navigation import calculate_bearing_and_distance

TRUST_NOTE_FIXED = (
    "Canlı öneriler olasılıksal olarak üretilir; av başarısı garanti edilmez."
)


def _clamp_int(x: float) -> int:
    return int(max(0, min(100, round(x))))


def _rating_label(score: int) -> str:
    if score >= 80:
        return "Excellent"
    if score >= 60:
        return "Good"
    if score >= 40:
        return "Fair"
    return "Low"


def _valid_lat_lon(lat: float, lon: float) -> bool:
    return (
        isfinite(lat)
        and isfinite(lon)
        and -90.0 <= lat <= 90.0
        and -180.0 <= lon <= 180.0
    )


def _extract_hotspots(raw: Any) -> List[Dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    out: List[Dict[str, Any]] = []
    for item in raw:
        if isinstance(item, Mapping):
            out.append(dict(item))
    return out


def _hotspot_lat_lon(h: Mapping[str, Any]) -> Optional[Tuple[float, float]]:
    lat = h.get("latitude")
    lon = h.get("longitude")
    if lat is not None and lon is not None:
        try:
            la, lo = float(lat), float(lon)
            if _valid_lat_lon(la, lo):
                return la, lo
        except (TypeError, ValueError):
            pass
    geo = h.get("geo_coordinate")
    if isinstance(geo, Mapping):
        try:
            la = float(geo.get("lat"))
            lo = float(geo.get("lon"))
            if _valid_lat_lon(la, lo):
                return la, lo
        except (TypeError, ValueError):
            pass
    return None


def _distance_boost_m(d: float) -> int:
    if d <= 50.0:
        return 35
    if d <= 150.0:
        return 25
    if d <= 300.0:
        return 15
    if d <= 700.0:
        return 8
    return 0


def _rank_bonus(rank: Optional[int]) -> int:
    if rank is None:
        return 0
    try:
        r = int(rank)
    except (TypeError, ValueError):
        return 0
    if 1 <= r <= 3:
        return 10
    if 4 <= r <= 10:
        return 5
    return 0


def compute_live_fishing_score(body: Mapping[str, Any]) -> Dict[str, Any]:
    """
    Build response dict for ``/api/v1/live_fishing_score``.
    """
    try:
        lat = float(body.get("current_lat"))
        lon = float(body.get("current_lon"))
    except (TypeError, ValueError):
        return {
            "live_score": 0,
            "rating": "Low",
            "reasoning": "Canlı yönlendirme için geçerli enlem ve boylam gerekir.",
            "nearest_hotspot": None,
            "trust_note": TRUST_NOTE_FIXED,
        }

    if not _valid_lat_lon(lat, lon):
        return {
            "live_score": 0,
            "rating": "Low",
            "reasoning": "GPS koordinatları geçersiz veya aralık dışı; bu konum için skor üretilemez.",
            "nearest_hotspot": None,
            "trust_note": TRUST_NOTE_FIXED,
        }

    gps_acc: Optional[float] = None
    raw_acc = body.get("gps_accuracy_m")
    if raw_acc is not None:
        try:
            acc = float(raw_acc)
            if isfinite(acc) and acc >= 0.0:
                gps_acc = acc
        except (TypeError, ValueError):
            gps_acc = None

    mode = str(body.get("coordinate_mode") or "").strip().lower()
    hotspots = _extract_hotspots(body.get("latest_hotspots"))

    # Only ``geo_referenced`` uses hotspot haversine. Everything else stays conservative.
    geo_distance_mode = mode == "geo_referenced"

    # Base GPS score
    score = 45.0
    if gps_acc is not None:
        if gps_acc > 50.0:
            score -= 10.0
        elif gps_acc <= 15.0:
            score += 5.0

    reasoning_parts: List[str] = []
    nearest_payload: Optional[Dict[str, Any]] = None

    # image_space / unknown / omitted / unrecognized → no real-world hotspot distance math
    if not geo_distance_mode:
        score = max(40.0, min(55.0, score))
        reasoning_parts.append(
            "Mesafeye dayalı mera ipuçları için kalibre harita koordinatları gerekir; "
            "yalnızca görüntü analizi canlı GPS ile hizalanmaz."
        )
        reasoning_parts.append(
            "Skor yalnızca GPS kalitesini yansıtır; daha zengin öneri için coğrafi hizalı bir analiz şarttır."
        )
        final = _clamp_int(score)
        return {
            "live_score": final,
            "rating": _rating_label(final),
            "reasoning": " ".join(reasoning_parts).strip(),
            "nearest_hotspot": None,
            "trust_note": TRUST_NOTE_FIXED,
        }

    usable: List[Tuple[Dict[str, Any], float, float]] = []
    for h in hotspots:
        ll = _hotspot_lat_lon(h)
        if ll is None:
            continue
        usable.append((h, ll[0], ll[1]))

    if not usable:
        score = max(40.0, min(55.0, score))
        final = _clamp_int(score)
        reasoning_parts.append(
            "Geçerli koordinata sahip harita mera noktası verilmedi; skor yalnızca GPS varlığına dayanıyor."
        )
        reasoning_parts.append(
            "Sıralı işaretlere yakın mesafe ipuçları için kalibre fotoğraf analizi çalıştırın."
        )
        return {
            "live_score": final,
            "rating": _rating_label(final),
            "reasoning": " ".join(reasoning_parts).strip(),
            "nearest_hotspot": None,
            "trust_note": TRUST_NOTE_FIXED,
        }

    # Nearest hotspot by haversine
    best: Optional[Tuple[Dict[str, Any], float, float, float]] = None
    for h, hlat, hlon in usable:
        dist = float(
            calculate_bearing_and_distance(lat, lon, hlat, hlon)["distance_m"]
        )
        if best is None or dist < best[3]:
            best = (h, hlat, hlon, dist)

    assert best is not None
    h_best, hlat, hlon, d_min = best

    dist_boost = _distance_boost_m(d_min)
    rid = h_best.get("recommendation_rank")
    try:
        rank_int = int(rid) if rid is not None else None
    except (TypeError, ValueError):
        rank_int = None
    r_bonus = _rank_bonus(rank_int)

    score += float(dist_boost + r_bonus)

    hid: Any = h_best.get("id", None)
    try:
        hid_out = int(hid) if hid is not None else None
    except (TypeError, ValueError):
        hid_out = None

    nearest_payload = {
        "id": hid_out,
        "distance_m": round(d_min, 1),
        "recommendation_rank": rank_int,
        "latitude": hlat,
        "longitude": hlon,
    }

    reasoning_parts.append(
        f"En yakın işaretlenen nokta yaklaşık {d_min:.0f} m uzakta "
        f"(harita koordinatları); mesafe ve sıra bağlamına göre güçlendirilir."
    )
    if gps_acc is not None:
        reasoning_parts.append(
            f"GPS doğruluğu (~{gps_acc:.0f} m) hesaba katıldı; bunu yumuşak bir ipucu, tahmin değil gibi düşünün."
        )
    else:
        reasoning_parts.append(
            "GPS doğruluğu verilmedi; sıkı bir fix’e göre skor daha az kesin olabilir."
        )

    final = _clamp_int(score)
    return {
        "live_score": final,
        "rating": _rating_label(final),
        "reasoning": " ".join(reasoning_parts).strip(),
        "nearest_hotspot": nearest_payload,
        "trust_note": TRUST_NOTE_FIXED,
    }
