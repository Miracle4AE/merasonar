#!/usr/bin/env python3
"""Release artifact sanity check — build sonrası çalıştırın."""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SK_PROJ = re.compile(r"sk-proj-[A-Za-z0-9_\-]{20,}")
ENV_KEY = re.compile(
    r"OPENAI_API_KEY\s*=\s*sk-[A-Za-z0-9_\-]{10,}",
    re.IGNORECASE,
)

SKIP_SCAN_SUFFIXES = {
    ".exe",
    ".dll",
    ".pdb",
    ".so",
    ".dylib",
    ".png",
    ".jpg",
    ".jpeg",
    ".ico",
    ".webp",
    ".ttf",
    ".otf",
    ".bin",
    ".dat",
}

SKIP_SCAN_NAMES = {".env", ".env.local", ".env.production"}

FORBIDDEN_ARTIFACT_NAMES = {
    ".env",
    ".env.local",
    ".env.production",
    "marine_spots.db",
    "ai_telemetry.jsonl",
}

FORBIDDEN_ARTIFACT_PARTS = {"run_logs"}


def _scan_text_file(path: Path) -> list[str]:
    hits: list[str] = []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return hits
    if SK_PROJ.search(text):
        hits.append(f"{path}: sk-proj- pattern")
    if ENV_KEY.search(text):
        hits.append(f"{path}: OPENAI_API_KEY with value")
    if path.name == ".env":
        hits.append(f"{path}: .env must not be in release artifact")
    if path.name == ".env.example":
        for line in text.splitlines():
            if line.strip().startswith("OPENAI_API_KEY="):
                val = line.split("=", 1)[1].strip()
                if val and not re.match(
                    r"^(your-|changeme|placeholder|<.*>|sk-your-key-here)$",
                    val,
                    re.I,
                ):
                    hits.append(f"{path}: .env.example must be placeholder-only")
    return hits


def _forbidden_artifact_hit(path: Path | str, *, in_zip: bool = False) -> list[str]:
    """Return issues for forbidden local-state / secret files in artifacts."""
    hits: list[str] = []
    p = Path(path) if not isinstance(path, Path) else path
    name = p.name
    parts = set(p.parts)
    prefix = "ZIP contains" if in_zip else "forbidden in artifact"
    if name in FORBIDDEN_ARTIFACT_NAMES:
        hits.append(f"{prefix}: {p}")
    if parts & FORBIDDEN_ARTIFACT_PARTS:
        hits.append(f"{prefix}: {p} (run_logs)")
    if name.startswith(".env") and name != ".env.example":
        hits.append(f"{prefix}: {p}")
    return hits


def scan_tree(root: Path) -> list[str]:
    hits: list[str] = []
    if not root.exists():
        return [f"missing path: {root}"]
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        hits.extend(_forbidden_artifact_hit(path))
        if path.name in SKIP_SCAN_NAMES:
            continue
        if "run_logs" in path.parts:
            hits.append(f"{path}: run_logs must not be in artifact")
            continue
        suffix = path.suffix.lower()
        if suffix in SKIP_SCAN_SUFFIXES:
            continue
        if suffix in {".apk", ".zip"}:
            continue
        if suffix in {".txt", ".json", ".yaml", ".yml", ".md", ".env", ".example", ".xml"}:
            hits.extend(_scan_text_file(path))
        elif path.name.startswith(".env"):
            hits.extend(_scan_text_file(path))
    return hits


def check_apk(apk: Path) -> list[str]:
    hits: list[str] = []
    if not apk.is_file():
        return [f"APK not found: {apk}"]
    if apk.suffix.lower() != ".apk":
        hits.append(f"not an APK file: {apk}")
    if apk.stat().st_size < 1024:
        hits.append(f"APK suspiciously small: {apk}")
    try:
        with zipfile.ZipFile(apk, "r") as zf:
            for name in zf.namelist():
                if name.endswith(".env") or name.split("/")[-1] == ".env":
                    hits.append(f"APK contains .env: {name}")
    except zipfile.BadZipFile:
        hits.append(f"invalid APK zip: {apk}")
    return hits


def check_windows_zip(path: Path) -> list[str]:
    hits: list[str] = []
    if not path.is_file():
        return [f"Windows zip not found: {path}"]
    if path.suffix.lower() != ".zip":
        hits.append(f"not a zip file: {path}")
        return hits
    try:
        with zipfile.ZipFile(path, "r") as zf:
            names = zf.namelist()
            if not any(n.lower().endswith(".exe") for n in names):
                hits.append(f"no .exe in Windows zip: {path}")
            for name in names:
                if name.endswith("/"):
                    continue
                inner = Path(name)
                hits.extend(_forbidden_artifact_hit(inner, in_zip=True))
                if inner.suffix.lower() in {".txt", ".json", ".yaml", ".yml", ".md", ".xml", ".env"}:
                    try:
                        text = zf.read(name).decode("utf-8", errors="ignore")
                    except KeyError:
                        continue
                    if SK_PROJ.search(text):
                        hits.append(f"ZIP entry sk-proj pattern: {name}")
                    if ENV_KEY.search(text):
                        hits.append(f"ZIP entry OPENAI_API_KEY with value: {name}")
    except zipfile.BadZipFile:
        hits.append(f"invalid zip: {path}")
    return hits


def check_windows_dir(path: Path) -> list[str]:
    hits: list[str] = []
    if not path.is_dir():
        return [f"Windows release dir not found: {path}"]
    exe = list(path.glob("*.exe"))
    if not exe:
        hits.append(f"no .exe in Windows release: {path}")
    hits.extend(scan_tree(path))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description="MeraSonar release artifact check")
    parser.add_argument("--apk", type=Path, help="Path to app-release.apk")
    parser.add_argument(
        "--windows-dir",
        type=Path,
        help="Path to build/windows/x64/runner/Release",
    )
    parser.add_argument(
        "--windows-zip",
        type=Path,
        help="Path to MeraSonar-windows-release.zip",
    )
    args = parser.parse_args()

    if not args.apk and not args.windows_dir and not args.windows_zip:
        parser.error("Specify --apk, --windows-dir, and/or --windows-zip")

    all_hits: list[str] = []
    if args.apk:
        apk = args.apk if args.apk.is_absolute() else ROOT / args.apk
        all_hits.extend(check_apk(apk))
    if args.windows_dir:
        win = args.windows_dir if args.windows_dir.is_absolute() else ROOT / args.windows_dir
        all_hits.extend(check_windows_dir(win))
    if args.windows_zip:
        wzip = args.windows_zip if args.windows_zip.is_absolute() else ROOT / args.windows_zip
        all_hits.extend(check_windows_zip(wzip))

    if all_hits:
        print("RELEASE ARTIFACT CHECK FAILED:", file=sys.stderr)
        for hit in all_hits:
            print(f"  - {hit}", file=sys.stderr)
        return 1

    print("RELEASE ARTIFACT CHECK OK")
    if args.apk:
        p = args.apk if args.apk.is_absolute() else ROOT / args.apk
        print(f"  APK: {p}")
    if args.windows_dir:
        p = args.windows_dir if args.windows_dir.is_absolute() else ROOT / args.windows_dir
        print(f"  Windows: {p}")
    if args.windows_zip:
        p = args.windows_zip if args.windows_zip.is_absolute() else ROOT / args.windows_zip
        print(f"  Windows zip: {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
