#!/usr/bin/env python3
"""Release config sanity check — CI ve release öncesi."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DENIZ_APP = ROOT / "deniz_app"

FAILURES: list[str] = []
WARNINGS: list[str] = []


def fail(msg: str) -> None:
    FAILURES.append(msg)


def warn(msg: str) -> None:
    WARNINGS.append(msg)


def parse_pubspec_version(raw: str) -> tuple[str, str | None]:
    """1.0.0+1 -> ('1.0.0', '1'); 1.0.0 -> ('1.0.0', None)."""
    text = raw.strip()
    if "+" in text:
        base, build = text.split("+", 1)
        return base.strip(), build.strip() or None
    return text, None


def check_env_example() -> None:
    path = ROOT / ".env.example"
    if not path.is_file():
        fail(".env.example missing")
        return
    text = path.read_text(encoding="utf-8")
    if re.search(r"sk-proj-[A-Za-z0-9_\-]{20,}", text):
        fail(".env.example contains OpenAI project key")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or not stripped:
            continue
        if stripped.startswith("OPENAI_API_KEY="):
            value = stripped.split("=", 1)[1].strip()
            if value and not re.match(
                r"^(your-|changeme|placeholder|<.*>|sk-your-key-here)$",
                value,
                re.I,
            ):
                fail(".env.example OPENAI_API_KEY must be empty or placeholder")


def check_gitignore() -> None:
    path = ROOT / ".gitignore"
    if not path.is_file():
        fail(".gitignore missing")
        return
    text = path.read_text(encoding="utf-8")
    if ".env" not in text:
        fail(".gitignore must ignore .env")


def check_pubspec_version() -> str | None:
    path = DENIZ_APP / "pubspec.yaml"
    if not path.is_file():
        fail("deniz_app/pubspec.yaml missing")
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip()
    fail("pubspec.yaml version: not found")
    return None


def check_app_config_version(pubspec_version: str | None) -> None:
    path = DENIZ_APP / "lib" / "config" / "app_config.dart"
    if not path.is_file():
        fail("AppConfig file missing")
        return
    text = path.read_text(encoding="utf-8")
    m = re.search(r"appVersion\s*=\s*'([^']+)'", text)
    if not m:
        fail("AppConfig.appVersion not found")
        return
    app_ver = m.group(1)
    if not pubspec_version:
        return
    pubspec_base, _build = parse_pubspec_version(pubspec_version)
    if app_ver != pubspec_base:
        fail(
            f"version mismatch: pubspec base={pubspec_base} "
            f"(full {pubspec_version}) AppConfig={app_ver}"
        )


def check_readme_version_note(pubspec_version: str | None) -> None:
    readme = ROOT / "README.md"
    if not readme.is_file() or not pubspec_version:
        return
    text = readme.read_text(encoding="utf-8")
    pubspec_base, _ = parse_pubspec_version(pubspec_version)
    if pubspec_base not in text and pubspec_version not in text:
        warn("README may not mention current release version")


def check_android_app_name() -> None:
    strings = DENIZ_APP / "android" / "app" / "src" / "main" / "res" / "values" / "strings.xml"
    if not strings.is_file():
        fail("Android strings.xml missing")
        return
    text = strings.read_text(encoding="utf-8")
    if "MeraSonar" not in text:
        fail("Android app_name should be MeraSonar")
    manifest = DENIZ_APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if manifest.is_file() and "@string/app_name" not in manifest.read_text(encoding="utf-8"):
        warn("AndroidManifest should reference @string/app_name")


def check_windows_app_name() -> None:
    rc = DENIZ_APP / "windows" / "runner" / "Runner.rc"
    if not rc.is_file():
        warn("Windows Runner.rc missing")
        return
    text = rc.read_text(encoding="utf-8")
    if "MeraSonar" not in text:
        fail("Windows ProductName should be MeraSonar")


def check_android_manifest() -> None:
    path = DENIZ_APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not path.is_file():
        fail("AndroidManifest.xml missing")
        return
    text = path.read_text(encoding="utf-8")
    if "android.permission.INTERNET" not in text:
        fail("AndroidManifest missing INTERNET permission")
    if "ACCESS_FINE_LOCATION" not in text and "ACCESS_COARSE_LOCATION" not in text:
        fail("AndroidManifest missing location permissions")


def check_docs() -> None:
    readme = ROOT / "README.md"
    if not readme.is_file():
        fail("README.md missing")
    else:
        text = readme.read_text(encoding="utf-8")
        if "Release Candidate" not in text and "release" not in text.lower():
            warn("README may be missing release section")
        if "API key" not in text.lower() and "OPENAI" not in text:
            warn("README may be missing API key security note")
    checklist = ROOT / "docs" / "RELEASE_CHECKLIST.md"
    if not checklist.is_file():
        fail("docs/RELEASE_CHECKLIST.md missing")
    matrix = ROOT / "docs" / "MANUAL_QA_MATRIX.md"
    if not matrix.is_file():
        warn("docs/MANUAL_QA_MATRIX.md missing")


def main() -> int:
    pubspec_ver = check_pubspec_version()
    check_env_example()
    check_gitignore()
    check_app_config_version(pubspec_ver)
    check_readme_version_note(pubspec_ver)
    check_android_app_name()
    check_windows_app_name()
    check_android_manifest()
    check_docs()

    for w in WARNINGS:
        print(f"WARNING: {w}", file=sys.stderr)
    if FAILURES:
        print("RELEASE CONFIG CHECK FAILED:", file=sys.stderr)
        for f in FAILURES:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("RELEASE CONFIG CHECK OK")
    if pubspec_ver:
        base, build = parse_pubspec_version(pubspec_ver)
        print(f"  version: pubspec={pubspec_ver} (base {base}, build {build or 'n/a'})")
    if WARNINGS:
        print(f"({len(WARNINGS)} warning(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
