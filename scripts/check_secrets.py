#!/usr/bin/env python3
"""MeraSonar secret scanner — CI ve release öncesi çalıştırın."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Taranmayacak dizinler
SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "node_modules",
    "build",
    ".dart_tool",
    ".pytest_cache",
    "__pycache__",
    "ephemeral",
    ".plugin_symlinks",
}

# Taranacak uzantılar
SCAN_EXTENSIONS = {
    ".md",
    ".py",
    ".dart",
    ".yaml",
    ".yml",
    ".json",
    ".env",
    ".example",
    ".txt",
    ".bat",
    ".sh",
}

PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("OpenAI project key (sk-proj-)", re.compile(r"sk-proj-[A-Za-z0-9_\-]{20,}")),
]

# Satır bazlı .env atamaları (çok satırlı yanlış eşleşmeyi önler)
ENV_KEY_LINE = re.compile(
    r"^(?:export\s+)?(?:(?:WINDY|POSEIDON|MGM|OPENAI)_API_KEY)\s*=\s*(\S.*?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)

PLACEHOLDER_OK = re.compile(
    r"^(?:|your-[\w-]+|changeme|placeholder|<.*>|xxx+|sk-your-key-here)$",
    re.IGNORECASE,
)

ALWAYS_SCAN_FILES = [
    ROOT / ".env.example",
    ROOT / "README.md",
    ROOT / "deniz_app" / "README.md",
]


def _should_skip(path: Path) -> bool:
    return any(part in SKIP_DIRS for part in path.parts)


def _scan_file(path: Path) -> list[str]:
    hits: list[str] = []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return hits

    rel = path.relative_to(ROOT).as_posix()
    is_example = path.name == ".env.example"
    is_python = path.suffix == ".py"

    for label, pattern in PATTERNS:
        for match in pattern.finditer(text):
            hits.append(f"{rel}: {label}")

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if is_python and ("_env_str(" in stripped or "openai_api_key=" in stripped.lower()):
            continue
        m = ENV_KEY_LINE.match(stripped)
        if not m:
            continue
        value = m.group(1).strip().strip('"').strip("'")
        if not value:
            continue
        if PLACEHOLDER_OK.match(value):
            continue
        if value.startswith("sk-") and len(value) > 12:
            hits.append(f"{rel}: OPENAI_API_KEY with real value")
        elif len(value) >= 8:
            hits.append(f"{rel}: API_KEY assignment (non-placeholder)")

    # .env.example özel: boş olmayan OPENAI_API_KEY
    if is_example:
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("OPENAI_API_KEY="):
                value = stripped.split("=", 1)[1].strip()
                if value and not PLACEHOLDER_OK.match(value):
                    hits.append(f"{rel}: OPENAI_API_KEY must be empty or placeholder")
                return hits

    return hits


def iter_files() -> list[Path]:
    files: set[Path] = set()
    for path in ROOT.rglob("*"):
        if not path.is_file() or _should_skip(path):
            continue
        if path.name == ".env":
            continue  # yerel .env kullanıcı makinesinde kalır; repo taramasına dahil etme
        if path.suffix.lower() in SCAN_EXTENSIONS or path.name.startswith(".env"):
            files.add(path)
    for f in ALWAYS_SCAN_FILES:
        if f.is_file():
            files.add(f)
    return sorted(files)


def main() -> int:
    all_hits: list[str] = []
    for path in iter_files():
        all_hits.extend(_scan_file(path))

    if all_hits:
        print("SECRET SCAN FAILED — potential credentials in tracked files:", file=sys.stderr)
        for hit in sorted(set(all_hits)):
            print(f"  - {hit}", file=sys.stderr)
        print(
            "\nUse placeholders in .env.example. Real keys belong only in local .env (gitignored).",
            file=sys.stderr,
        )
        return 1

    print("SECRET SCAN OK — no credentials found in scanned files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
