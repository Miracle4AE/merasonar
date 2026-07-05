"""
Image-space hotspot overlays: professional-style PNG export (clean + labeled).

Artifacts are written under ``run_logs/`` (never temp-only paths).
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Mapping, MutableMapping, Optional, Sequence, Tuple

import cv2
import numpy as np

BGR_CLASS = {
    "A": (0, 0, 255),
    "B": (0, 255, 255),
    "C": (0, 220, 0),
}

CLASS_TITLE = {
    "A": "Yüksek olasılık",
    "B": "Orta",
    "C": "Düşük",
}

_DEFAULT_OVERLAY_FILENAME = "image_space_hotspot_overlay.png"
_DEFAULT_CLEAN_OVERLAY_FILENAME = "image_space_hotspot_overlay_clean.png"
DEFAULT_OVERLAY_MAX_LABELED_RANKS = 20
TOP_A_LABELS = 10
CLUSTER_DIST_FRAC = 0.016
GLOW_LAYERS_A = 3


@dataclass
class _SpotModel:
    x: float
    y: float
    cls: str
    score: float
    rank: int
    raw: Mapping[str, Any]


@dataclass
class _VisualItem:
    """One drawable entity: a single hotspot or a dense cluster."""

    kind: str  # "single" | "cluster"
    cx: float
    cy: float
    cls: str
    score: float
    best_rank: int
    member_indices: List[int]
    cluster_size: int = 1

    def anchor_point(self) -> Tuple[int, int]:
        return int(round(self.cx)), int(round(self.cy))


def run_logs_dir(repo_root: Optional[Path] = None) -> Path:
    root = repo_root if repo_root is not None else Path(__file__).resolve().parent
    logs = root / "run_logs"
    logs.mkdir(parents=True, exist_ok=True)
    return logs


def default_overlay_png_path(repo_root: Optional[Path] = None) -> Path:
    return run_logs_dir(repo_root) / _DEFAULT_OVERLAY_FILENAME


def default_clean_overlay_png_path(repo_root: Optional[Path] = None) -> Path:
    return run_logs_dir(repo_root) / _DEFAULT_CLEAN_OVERLAY_FILENAME


def load_response_payload(json_path: str | Path) -> Dict[str, Any]:
    path = Path(json_path)
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("Response JSON must be an object at the root.")
    return data


def _normalize_class(raw: Any) -> str:
    s = str(raw or "C").strip().upper()[:1]
    return s if s in BGR_CLASS else "C"


def _hotspot_xy(h: Mapping[str, Any], scale_x: float, scale_y: float) -> Optional[Tuple[float, float]]:
    centroid = h.get("pixel_centroid")
    if isinstance(centroid, Mapping):
        cx = centroid.get("x")
        cy = centroid.get("y")
        if cx is not None and cy is not None:
            return float(cx) * scale_x, float(cy) * scale_y
    x = h.get("x")
    y = h.get("y")
    if x is not None and y is not None:
        return float(x) * scale_x, float(y) * scale_y
    return None


def _ordered_hotspots(response: Mapping[str, Any]) -> List[Mapping[str, Any]]:
    ranked = response.get("ranked_hotspots")
    if isinstance(ranked, list) and ranked:
        return [h for h in ranked if isinstance(h, Mapping)]
    hs = response.get("hotspots")
    if isinstance(hs, list) and hs:
        return [h for h in hs if isinstance(h, Mapping)]
    return []


def _scale_from_response_and_image(
    response: Mapping[str, Any],
    image_shape: Tuple[int, int, int],
) -> Tuple[float, float]:
    ih, iw = image_shape[0], image_shape[1]
    size = response.get("image_size")
    if not isinstance(size, Mapping):
        return 1.0, 1.0
    jw = size.get("width")
    jh = size.get("height")
    try:
        jw_f = float(jw)
        jh_f = float(jh)
    except (TypeError, ValueError):
        return 1.0, 1.0
    if jw_f <= 0 or jh_f <= 0:
        return 1.0, 1.0
    return iw / jw_f, ih / jh_f


def _hotspot_rank_value(hmap: Mapping[str, Any]) -> int:
    try:
        return int(hmap.get("rank", hmap.get("rank_overall", 9999)))
    except (TypeError, ValueError):
        return 9999


def _score_value(hmap: Mapping[str, Any]) -> float:
    try:
        v = float(hmap.get("score", 0.0))
    except (TypeError, ValueError):
        return 0.0
    return max(0.0, min(1.0, v))


class _UnionFind:
    def __init__(self, n: int) -> None:
        self._p = list(range(n))
        self._r = [0] * n

    def find(self, x: int) -> int:
        while self._p[x] != x:
            self._p[x] = self._p[self._p[x]]
            x = self._p[x]
        return x

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra == rb:
            return
        if self._r[ra] < self._r[rb]:
            self._p[ra] = rb
        elif self._r[ra] > self._r[rb]:
            self._p[rb] = ra
        else:
            self._p[rb] = ra
            self._r[ra] += 1


def _build_spot_models(
    response: Mapping[str, Any],
    scale_x: float,
    scale_y: float,
    h: int,
    w: int,
) -> List[_SpotModel]:
    models: List[_SpotModel] = []
    for hmap in _ordered_hotspots(response):
        xy = _hotspot_xy(hmap, scale_x, scale_y)
        if xy is None:
            continue
        x, y = xy
        x = float(np.clip(x, 0.0, w - 1.0))
        y = float(np.clip(y, 0.0, h - 1.0))
        cls = _normalize_class(hmap.get("classification") or hmap.get("class"))
        models.append(
            _SpotModel(
                x=x,
                y=y,
                cls=cls,
                score=_score_value(hmap),
                rank=_hotspot_rank_value(hmap),
                raw=hmap,
            )
        )
    return models


def _cluster_spots(models: List[_SpotModel], cluster_dist: float) -> List[_VisualItem]:
    n = len(models)
    if n == 0:
        return []
    uf = _UnionFind(n)
    for i in range(n):
        for j in range(i + 1, n):
            dx = models[i].x - models[j].x
            dy = models[i].y - models[j].y
            if dx * dx + dy * dy <= cluster_dist * cluster_dist:
                uf.union(i, j)

    groups: Dict[int, List[int]] = {}
    for i in range(n):
        r = uf.find(i)
        groups.setdefault(r, []).append(i)

    items: List[_VisualItem] = []
    for _root, members in groups.items():
        members.sort(key=lambda k: models[k].rank)
        if len(members) == 1:
            m = models[members[0]]
            items.append(
                _VisualItem(
                    kind="single",
                    cx=m.x,
                    cy=m.y,
                    cls=m.cls,
                    score=m.score,
                    best_rank=m.rank,
                    member_indices=[members[0]],
                    cluster_size=1,
                )
            )
        else:
            sx = sum(models[i].x for i in members) / len(members)
            sy = sum(models[i].y for i in members) / len(members)
            best = max(members, key=lambda k: models[k].score)
            cls = models[best].cls
            best_rank = min(models[i].rank for i in members)
            score = max(models[i].score for i in members)
            items.append(
                _VisualItem(
                    kind="cluster",
                    cx=sx,
                    cy=sy,
                    cls=cls,
                    score=score,
                    best_rank=best_rank,
                    member_indices=members,
                    cluster_size=len(members),
                )
            )
    return items


def _blend_bgr_disk(
    img: np.ndarray,
    cx: int,
    cy: int,
    r: int,
    color_bgr: Tuple[int, int, int],
    alpha: float,
) -> None:
    if r <= 0 or alpha <= 0:
        return
    h, w = img.shape[:2]
    y0, y1 = max(0, cy - r - 1), min(h, cy + r + 2)
    x0, x1 = max(0, cx - r - 1), min(w, cx + r + 2)
    if y0 >= y1 or x0 >= x1:
        return
    yy = np.arange(y0, y1, dtype=np.float64)[:, None]
    xx = np.arange(x0, x1, dtype=np.float64)[None, :]
    dist2 = (xx - cx) ** 2 + (yy - cy) ** 2
    mask = (dist2 <= r * r).astype(np.float64)
    a = alpha * mask
    if not np.any(a):
        return
    roi = img[y0:y1, x0:x1].astype(np.float64)
    cb = np.array(color_bgr, dtype=np.float64).reshape(1, 1, 3)
    a3 = a[..., None]
    roi[:] = np.clip(roi * (1.0 - a3) + cb * a3, 0, 255)
    img[y0:y1, x0:x1] = roi.astype(np.uint8)


def _draw_a_glow(img: np.ndarray, cx: int, cy: int, base_r: int) -> None:
    for layer in range(GLOW_LAYERS_A, 0, -1):
        rad = base_r + layer * 5
        # Soft red halation (BGR)
        intensity = 0.06 / layer
        _blend_bgr_disk(img, cx, cy, rad, (80, 80, 255), intensity)
        _blend_bgr_disk(img, cx, cy, rad - 1, (55, 55, 255), intensity * 0.6)


def _marker_radius(base_r: int, score: float) -> int:
    t = max(0.0, min(1.0, score))
    return max(2, int(round(base_r * (0.72 + 0.55 * t))))


def _marker_alpha_fill(score: float) -> float:
    t = max(0.0, min(1.0, score))
    return 0.36 + 0.64 * t


def _draw_visual_item_markers(
    canvas: np.ndarray,
    item: _VisualItem,
    models: List[_SpotModel],
    base_r: int,
) -> None:
    h, w = canvas.shape[0], canvas.shape[1]
    ix, iy = int(np.clip(round(item.cx), 0, w - 1)), int(np.clip(round(item.cy), 0, h - 1))
    color = BGR_CLASS.get(item.cls, BGR_CLASS["C"])

    if item.kind == "cluster":
        r = max(base_r + 3, int(base_r * 1.15 + 0.4 * item.cluster_size))
        if item.cls == "A":
            _draw_a_glow(canvas, ix, iy, r)
        _blend_bgr_disk(canvas, ix, iy, r + 2, (255, 255, 255), 0.35)
        _blend_bgr_disk(canvas, ix, iy, r, color, 0.55)
        # Inner ring
        cv2.circle(canvas, (ix, iy), r, (40, 40, 40), 1, lineType=cv2.LINE_AA)
        badge = str(item.cluster_size)
        bf = max(0.35, min(w, h) / 1800.0)
        (tw, th), _ = cv2.getTextSize(badge, cv2.FONT_HERSHEY_SIMPLEX, bf, 1)
        bx = int(np.clip(ix - tw // 2, 2, w - tw - 2))
        by = int(np.clip(iy + r + th + 4, th + 4, h - 4))
        cv2.rectangle(
            canvas,
            (bx - 2, by - th - 2),
            (bx + tw + 2, by + 2),
            (20, 20, 20),
            thickness=-1,
        )
        cv2.putText(
            canvas,
            badge,
            (bx, by),
            cv2.FONT_HERSHEY_SIMPLEX,
            bf,
            (250, 250, 250),
            1,
            cv2.LINE_AA,
        )
        return

    m = models[item.member_indices[0]]
    rr = _marker_radius(base_r, m.score)
    alpha = _marker_alpha_fill(m.score)
    if m.cls == "A":
        _draw_a_glow(canvas, ix, iy, rr)
    _blend_bgr_disk(canvas, ix, iy, rr + 1, (255, 255, 255), min(0.9, alpha + 0.15))
    _blend_bgr_disk(canvas, ix, iy, rr, color, alpha)


def _draw_legend(canvas: np.ndarray) -> None:
    h, w = canvas.shape[0], canvas.shape[1]
    pad = max(8, min(w, h) // 120)
    line_h = max(16, int(min(w, h) / 55))
    box_w = min(int(w * 0.38), 320)
    box_h = pad * 2 + line_h * 5
    overlay = canvas[pad : pad + box_h, pad : pad + box_w].copy().astype(np.float64)
    dark = np.zeros_like(overlay)
    alpha_panel = 0.42
    canvas[pad : pad + box_h, pad : pad + box_w] = np.clip(
        overlay * (1 - alpha_panel) + dark * alpha_panel, 0, 255
    ).astype(np.uint8)

    font = cv2.FONT_HERSHEY_SIMPLEX
    fs = max(0.42, min(w, h) / 1600.0)
    y = pad + line_h
    x = pad + 8
    cv2.putText(canvas, "Hotspot class", (x, y), font, fs * 1.05, (255, 255, 255), 1, cv2.LINE_AA)
    y += line_h + 4
    for cls, bgr in (("A", BGR_CLASS["A"]), ("B", BGR_CLASS["B"]), ("C", BGR_CLASS["C"])):
        cv2.circle(canvas, (x + 7, y - 4), 5, bgr, -1, lineType=cv2.LINE_AA)
        text = f"{cls} = {CLASS_TITLE[cls]} ({'red' if cls == 'A' else 'yellow' if cls == 'B' else 'green'})"
        cv2.putText(canvas, text, (x + 20, y), font, fs * 0.92, (235, 235, 235), 1, cv2.LINE_AA)
        y += line_h + 2


def _rect_intersects(a: Tuple[int, int, int, int], b: Tuple[int, int, int, int]) -> bool:
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    return not (ax1 < bx0 or bx1 < ax0 or ay1 < by0 or by1 < ay0)


def _inflate_rect(r: Tuple[int, int, int, int], margin: int) -> Tuple[int, int, int, int]:
    x0, y0, x1, y1 = r
    return (x0 - margin, y0 - margin, x1 + margin, y1 + margin)


def _label_text_for_item(item: _VisualItem, models: List[_SpotModel]) -> str:
    if item.kind == "cluster":
        return f"{item.cls} x{item.cluster_size} r{item.best_rank}"
    m = models[item.member_indices[0]]
    return f"{m.cls} r{m.rank} {m.score:.2f}"


def _label_priority_top_n_a(models: List[_SpotModel], n: int) -> List[int]:
    """Model list indices of the top ``n`` class-A hotspots by rank."""
    a_idx = [i for i, m in enumerate(models) if m.cls == "A"]
    a_idx.sort(key=lambda i: models[i].rank)
    return a_idx[:n]


def _base_marker_radius(w: int, h: int, overlay_zoom_scale: float) -> int:
    z = max(0.45, min(2.3, float(overlay_zoom_scale)))
    zm = 0.82 + 0.18 * (z - 0.45) / 1.85
    return max(3, int(round((min(w, h) / 420.0) * zm)))


def _zoom_extra_label_budget(zoom_scale: float) -> int:
    z = max(0.35, min(2.2, float(zoom_scale)))
    # overview -> detail: more secondary labels
    return int(6 + (z - 0.35) * 28)


def _place_labels_smart(
    canvas: np.ndarray,
    models: List[_SpotModel],
    items: List[_VisualItem],
    *,
    h: int,
    w: int,
    base_r: int,
    font_scale: float,
    thickness: int,
    mandatory_a_indices: Sequence[int],
    overlay_show_all_labels: bool,
    overlay_max_labeled_ranks: int,
    zoom_scale: float,
) -> None:
    font = cv2.FONT_HERSHEY_SIMPLEX
    placed: List[Tuple[int, int, int, int]] = []

    # Build candidate list: (priority, model_index or -1 for cluster-only, item ref, is_mandatory)
    candidates: List[Tuple[int, int, _VisualItem, bool]] = []

    mandatory_set = set(mandatory_a_indices)

    for item in items:
        if item.kind == "cluster":
            rep = min(item.member_indices, key=lambda k: models[k].rank)
            man = bool(mandatory_set.intersection(item.member_indices))
            pr = 3500 - models[rep].rank if man else 400 - models[rep].rank
            candidates.append((pr, rep, item, man))
        else:
            mi = item.member_indices[0]
            m = models[mi]
            man = mi in mandatory_set
            pr = 4000 - m.rank if man else 1200 - m.rank
            if m.cls == "B":
                pr -= 200
            if m.cls == "C":
                pr -= 400
            candidates.append((pr, mi, item, man))

    candidates.sort(key=lambda t: (-t[0], models[t[1]].rank))

    extra_budget = _zoom_extra_label_budget(zoom_scale)
    if overlay_show_all_labels:
        extra_budget = 10_000

    placed_extra = 0

    for pr, midx, item, is_mand in candidates:
        m = models[midx]
        rank = item.best_rank if item.kind == "cluster" else m.rank
        if not overlay_show_all_labels:
            if not is_mand:
                if placed_extra >= extra_budget:
                    continue
                if not (1 <= rank <= overlay_max_labeled_ranks):
                    continue

        text = _label_text_for_item(item, models)
        (tw, th), baseline = cv2.getTextSize(text, font, font_scale, thickness)
        ax, ay = item.anchor_point()

        best_rect: Optional[Tuple[int, int, int, int, int, int]] = None
        rr = _marker_radius(base_r, m.score) if item.kind == "single" else base_r + 6

        # Radial search + axis offset
        angles = [0, 40, 80, 120, 160, 200, 240, 280, 320, 15, 55, 95]
        dists = [rr + 10, rr + 22, rr + 36, rr + 52]

        for dist in dists:
            for angdeg in angles:
                rad = math.radians(angdeg)
                tx = int(round(ax + math.cos(rad) * dist))
                ty = int(round(ay - math.sin(rad) * dist))
                # putText baseline ty
                tx = int(np.clip(tx, 4, w - tw - 6))
                ty = int(np.clip(ty, th + 6, h - baseline - 4))
                rect = (tx - 2, ty - th - 3, tx + tw + 2, ty + baseline + 2)
                inf = _inflate_rect(rect, 3)
                if any(_rect_intersects(inf, _inflate_rect(p, 2)) for p in placed):
                    continue
                best_rect = (tx, ty, *rect)
                break
            if best_rect:
                break

        if best_rect is None:
            if is_mand:
                # Last resort: shorter text for single
                if item.kind == "single" and len(text) > 10:
                    text = f"{m.cls} r{m.rank}"
                    (tw, th), baseline = cv2.getTextSize(text, font, font_scale * 0.88, thickness)
                    tx = int(np.clip(ax + rr + 4, 4, w - tw - 6))
                    ty = int(np.clip(ay, th + 6, h - baseline - 4))
                    rect = (tx - 2, ty - th - 3, tx + tw + 2, ty + baseline + 2)
                    inf = _inflate_rect(rect, 2)
                    if not any(_rect_intersects(inf, _inflate_rect(p, 2)) for p in placed):
                        best_rect = (tx, ty, *rect)
            if best_rect is None:
                continue

        tx, ty = best_rect[0], best_rect[1]
        rect = best_rect[2:6]
        cv2.rectangle(canvas, (rect[0], rect[1]), (rect[2], rect[3]), (15, 15, 15), thickness=-1)
        cv2.putText(canvas, text, (tx, ty), font, font_scale, (245, 245, 245), thickness, cv2.LINE_AA)
        placed.append(rect)
        if not is_mand:
            placed_extra += 1


def render_image_space_overlay_clean_bgr(
    chart_bgr: np.ndarray,
    response: Mapping[str, Any],
    *,
    overlay_zoom_scale: float = 1.0,
) -> np.ndarray:
    """Markers, clusters, glow, legend — no per-hotspot text labels."""
    canvas = chart_bgr.copy().astype(np.uint8)
    scale_x, scale_y = _scale_from_response_and_image(response, chart_bgr.shape)
    h, w = canvas.shape[0], canvas.shape[1]
    models = _build_spot_models(response, scale_x, scale_y, h, w)
    cluster_dist = max(10.0, min(w, h) * CLUSTER_DIST_FRAC)
    items = _cluster_spots(models, cluster_dist)
    base_r = _base_marker_radius(w, h, overlay_zoom_scale)

    items_draw = sorted(items, key=lambda it: it.best_rank, reverse=True)
    for it in items_draw:
        _draw_visual_item_markers(canvas, it, models, base_r)

    _draw_legend(canvas)
    return canvas


def render_image_space_overlay_labeled_bgr(
    chart_bgr: np.ndarray,
    response: Mapping[str, Any],
    *,
    overlay_show_all_labels: bool = False,
    overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
    overlay_zoom_scale: float = 1.0,
) -> np.ndarray:
    """Full overlay: same as clean, then smart labels (top 10 A mandatory, adaptive)."""
    canvas = render_image_space_overlay_clean_bgr(
        chart_bgr,
        response,
        overlay_zoom_scale=overlay_zoom_scale,
    )
    scale_x, scale_y = _scale_from_response_and_image(response, chart_bgr.shape)
    h, w = canvas.shape[0], canvas.shape[1]
    models = _build_spot_models(response, scale_x, scale_y, h, w)
    cluster_dist = max(10.0, min(w, h) * CLUSTER_DIST_FRAC)
    items = _cluster_spots(models, cluster_dist)
    base_r = _base_marker_radius(w, h, overlay_zoom_scale)
    font_scale = max(0.32, min(w, h) / 2400.0)
    thickness = max(1, int(round(font_scale * 2)))

    mandatory = _label_priority_top_n_a(models, TOP_A_LABELS)

    _place_labels_smart(
        canvas,
        models,
        items,
        h=h,
        w=w,
        base_r=base_r,
        font_scale=font_scale,
        thickness=thickness,
        mandatory_a_indices=mandatory,
        overlay_show_all_labels=overlay_show_all_labels,
        overlay_max_labeled_ranks=overlay_max_labeled_ranks,
        zoom_scale=overlay_zoom_scale,
    )
    return canvas


def render_image_space_overlay_bgr(
    chart_bgr: np.ndarray,
    response: Mapping[str, Any],
    *,
    overlay_show_all_labels: bool = False,
    overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
    overlay_zoom_scale: float = 1.0,
) -> np.ndarray:
    """Backward-compatible alias: labeled professional overlay."""
    return render_image_space_overlay_labeled_bgr(
        chart_bgr,
        response,
        overlay_show_all_labels=overlay_show_all_labels,
        overlay_max_labeled_ranks=overlay_max_labeled_ranks,
        overlay_zoom_scale=overlay_zoom_scale,
    )


def export_image_space_overlay_from_response(
    chart_image_path: str | Path,
    response: Mapping[str, Any],
    output_png_path: str | Path,
    *,
    overlay_show_all_labels: bool = False,
    overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
    overlay_zoom_scale: float = 1.0,
    write_clean_version: bool = True,
) -> Dict[str, str]:
    """
    Write labeled PNG to ``output_png_path`` and optionally a clean (no labels) sibling.

    Returns ``{"labeled": path, "clean": path | ""}``.
    """
    chart_path = Path(chart_image_path)
    if not chart_path.is_file():
        raise FileNotFoundError(f"Chart image not found: {chart_path}")

    bgr = cv2.imread(str(chart_path), cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError(f"Could not decode image: {chart_path}")

    out_labeled = Path(output_png_path)
    out_labeled.parent.mkdir(parents=True, exist_ok=True)

    labeled = render_image_space_overlay_labeled_bgr(
        bgr,
        response,
        overlay_show_all_labels=overlay_show_all_labels,
        overlay_max_labeled_ranks=overlay_max_labeled_ranks,
        overlay_zoom_scale=overlay_zoom_scale,
    )
    cv2.imwrite(str(out_labeled), labeled)

    clean_path_str = ""
    if write_clean_version:
        clean_path = out_labeled.parent / _DEFAULT_CLEAN_OVERLAY_FILENAME
        clean_img = render_image_space_overlay_clean_bgr(
            bgr,
            response,
            overlay_zoom_scale=overlay_zoom_scale,
        )
        cv2.imwrite(str(clean_path), clean_img)
        clean_path_str = str(clean_path.resolve())

    return {
        "labeled": str(out_labeled.resolve()),
        "clean": clean_path_str,
    }


def export_image_space_overlay(
    chart_image_path: str | Path,
    response_json_path: str | Path,
    output_png_path: str | Path,
    *,
    overlay_show_all_labels: bool = False,
    overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
    overlay_zoom_scale: float = 1.0,
    write_clean_version: bool = True,
) -> Dict[str, str]:
    """CLI-oriented: load JSON and export labeled + optional clean overlays."""
    payload = load_response_payload(response_json_path)
    return export_image_space_overlay_from_response(
        chart_image_path,
        payload,
        output_png_path,
        overlay_show_all_labels=overlay_show_all_labels,
        overlay_max_labeled_ranks=overlay_max_labeled_ranks,
        overlay_zoom_scale=overlay_zoom_scale,
        write_clean_version=write_clean_version,
    )


def export_image_space_debug_overlay_if_applicable(
    chart_image_path: str | Path,
    analysis_result: Mapping[str, Any],
    output_png_path: Optional[str | Path] = None,
    repo_root: Optional[Path] = None,
    *,
    overlay_show_all_labels: bool = False,
    overlay_max_labeled_ranks: int = DEFAULT_OVERLAY_MAX_LABELED_RANKS,
    overlay_zoom_scale: float = 1.0,
) -> Optional[str]:
    if analysis_result.get("coordinate_mode") != "image_space":
        return None
    out = output_png_path if output_png_path is not None else default_overlay_png_path(repo_root)
    paths = export_image_space_overlay_from_response(
        chart_image_path,
        analysis_result,
        out,
        overlay_show_all_labels=overlay_show_all_labels,
        overlay_max_labeled_ranks=overlay_max_labeled_ranks,
        overlay_zoom_scale=overlay_zoom_scale,
        write_clean_version=True,
    )
    return paths.get("labeled")


def attach_overlay_path_to_diagnostics(
    payload: MutableMapping[str, Any],
    overlay_path: str,
) -> None:
    attach_image_space_overlay_paths(payload, labeled_path=overlay_path, clean_path="")


def attach_image_space_overlay_paths(
    payload: MutableMapping[str, Any],
    *,
    labeled_path: str,
    clean_path: str = "",
) -> None:
    diag = payload.get("diagnostics")
    if not isinstance(diag, MutableMapping):
        return
    diag["image_space_debug_overlay_path"] = labeled_path
    if clean_path:
        diag["image_space_clean_overlay_path"] = clean_path

