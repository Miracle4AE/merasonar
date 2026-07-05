#!/usr/bin/env python3
"""
Draw image-space hotspots on a chart and save PNG (defaults under ``run_logs/``).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def main() -> int:
    repo = _repo_root()
    sys.path.insert(0, str(repo))

    from image_space_overlay_export import (
        DEFAULT_OVERLAY_MAX_LABELED_RANKS,
        export_image_space_overlay,
    )

    defaults = repo / "run_logs"
    default_out = defaults / "image_space_hotspot_overlay.png"

    parser = argparse.ArgumentParser(
        description="Render ranked_hotspots onto a chart PNG (A=red, B=yellow, C=green).",
    )
    parser.add_argument("--chart", required=True, help="Path to chart image (BGR file readable by OpenCV).")
    parser.add_argument(
        "--json",
        required=True,
        dest="json_path",
        help="Response JSON path (e.g. run_logs/latest_image_space_response.json).",
    )
    parser.add_argument(
        "--output",
        "-o",
        default=str(default_out),
        help=f"PNG output path (default: {default_out})",
    )
    parser.add_argument(
        "--show-all-labels",
        action="store_true",
        help="Draw text for every hotspot; default is labels for top ranks only (see --max-labeled-ranks).",
    )
    parser.add_argument(
        "--max-labeled-ranks",
        type=int,
        default=DEFAULT_OVERLAY_MAX_LABELED_RANKS,
        metavar="N",
        help=f"Max rank (inclusive) to label when not using --show-all-labels (default: {DEFAULT_OVERLAY_MAX_LABELED_RANKS}).",
    )
    parser.add_argument(
        "--zoom",
        type=float,
        default=1.0,
        help="Image-space zoom hint: <1 overview (fewer labels), >1 detail (more secondary labels, larger markers). Default 1.",
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Do not write image_space_hotspot_overlay_clean.png alongside the labeled PNG.",
    )
    args = parser.parse_args()

    chart_path = Path(args.chart)
    json_path = Path(args.json_path)
    out_path = Path(args.output)
    if not chart_path.is_file():
        print(f"Chart not found: {chart_path}", file=sys.stderr)
        return 1
    if not json_path.is_file():
        print(f"JSON not found: {json_path}", file=sys.stderr)
        return 1

    paths = export_image_space_overlay(
        str(chart_path),
        str(json_path),
        str(out_path),
        overlay_show_all_labels=bool(args.show_all_labels),
        overlay_max_labeled_ranks=int(args.max_labeled_ranks),
        overlay_zoom_scale=float(args.zoom),
        write_clean_version=not bool(args.no_clean),
    )
    print(paths.get("labeled", ""))
    if paths.get("clean"):
        print(paths["clean"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
