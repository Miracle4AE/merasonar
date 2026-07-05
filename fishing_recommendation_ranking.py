"""
Heuristic ``final_fishing_score`` and ``recommendation_rank`` for ranked hotspots.

Combines bathymetry class/score, species_match confidence, and local cluster density.
Outputs are prioritization hints only—not catch guarantees.
"""

from __future__ import annotations

from math import hypot
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple


def _pixel_xy(h: Mapping[str, Any]) -> Tuple[float, float]:
    pc = h.get("pixel_centroid")
    ha = h.get("hotspot_pixel_anchor")
    if isinstance(pc, Mapping):
        x = pc.get("x")
        y = pc.get("y")
        if x is not None and y is not None:
            return float(x), float(y)
    if isinstance(ha, Mapping):
        x = ha.get("x")
        y = ha.get("y")
        if x is not None and y is not None:
            return float(x), float(y)
    return 0.0, 0.0


def _species_match_tier(matches: Any) -> Tuple[int, int]:
    """
    Returns (bonus_points_0_30, best_tier_0_3) where tier: 0 none, 1 low, 2 medium, 3 high.
    """
    if not isinstance(matches, Sequence) or not matches:
        return 0, 0
    best_tier = 0
    bonus = 0
    for item in matches:
        if not isinstance(item, Mapping):
            continue
        c = str(item.get("confidence", "")).lower().strip()
        if c == "high":
            best_tier = max(best_tier, 3)
            bonus = max(bonus, 28)
        elif c == "medium":
            best_tier = max(best_tier, 2)
            bonus = max(bonus, 15)
        elif c == "low":
            best_tier = max(best_tier, 1)
            bonus = max(bonus, 6)
    return bonus, best_tier


def _class_letter(raw: Any) -> str:
    s = str(raw or "C").strip().upper()
    return s[:1] if s else "C"


def _class_weight(letter: str) -> float:
    if letter == "A":
        return 22.0
    if letter == "B":
        return 12.0
    return 4.0


def _neighbor_counts(
    positions: List[Tuple[int, float, float]],
    cluster_radius_px: float,
) -> Dict[int, int]:
    out: Dict[int, int] = {}
    for hid, x, y in positions:
        n = 0
        for ohid, ox, oy in positions:
            if ohid == hid:
                continue
            if hypot(x - ox, y - oy) <= cluster_radius_px:
                n += 1
        out[hid] = n
    return out


def attach_fishing_recommendation_metrics(
    hotspots: List[Dict[str, Any]],
    *,
    width: int,
    height: int,
) -> List[int]:
    """
    Mutates each hotspot with ``final_fishing_score`` (0–100 int) and ``recommendation_rank`` (1..n).

    Returns up to five hotspot ids in priority order (best first).
    """
    if not hotspots:
        return []

    w = max(1, int(width))
    h = max(1, int(height))
    diag = hypot(float(w), float(h))
    cluster_radius_px = max(42.0, min(0.062 * diag, 0.32 * float(min(w, h))))

    positions: List[Tuple[int, float, float]] = []
    for h in hotspots:
        hid = int(h.get("id", -1))
        x, y = _pixel_xy(h)
        positions.append((hid, x, y))
    neighbor_map = _neighbor_counts(positions, cluster_radius_px)

    scored: List[Dict[str, Any]] = []

    for idx, h in enumerate(hotspots):
        hid = int(h.get("id", idx))
        raw_score = float(h.get("score", 0.0) or 0.0)
        if raw_score > 1.001:
            norm_score = max(0.0, min(1.0, raw_score / 100.0))
        else:
            norm_score = max(0.0, min(1.0, raw_score))

        base = norm_score**0.88 * 46.0
        letter = _class_letter(h.get("classification"))
        class_pts = _class_weight(letter)

        spec_bonus, spec_tier = _species_match_tier(h.get("species_match"))

        neighbors = int(neighbor_map.get(hid, 0))
        cluster_pts = min(14.0, float(neighbors) * 3.4)

        synergy = 0.0
        if letter == "A" and spec_tier >= 3:
            synergy = 7.0
        elif letter in ("A", "B") and spec_tier >= 2:
            synergy = 4.0

        isolated = neighbors <= 1
        isolated_penalty = 0.0
        if isolated and spec_tier <= 1:
            isolated_penalty = 13.0
        elif isolated:
            isolated_penalty = 5.0

        raw_total = base + class_pts + spec_bonus + cluster_pts + synergy - isolated_penalty
        final = int(round(max(0.0, min(100.0, raw_total))))

        scored.append(
            {
                "_idx": idx,
                "id": hid,
                "final_fishing_score": final,
            }
        )

    scored.sort(
        key=lambda r: (
            -int(r["final_fishing_score"]),
            -float(hotspots[int(r["_idx"])].get("score", 0.0) or 0.0),
            int(r["id"]),
        )
    )

    for rnk, row in enumerate(scored, start=1):
        i = int(row["_idx"])
        hotspots[i]["recommendation_rank"] = rnk
        hotspots[i]["final_fishing_score"] = int(row["final_fishing_score"])

    return [int(x["id"]) for x in scored[:5]]
