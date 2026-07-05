"""check_release_config.py tests."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_release_config.py"


def test_check_release_config_passes() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_release_checklist_exists() -> None:
    assert (ROOT / "docs" / "RELEASE_CHECKLIST.md").is_file()


def test_gitignore_has_env() -> None:
    text = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert ".env" in text


def test_version_base_matches_app_config() -> None:
    pubspec = (ROOT / "deniz_app" / "pubspec.yaml").read_text(encoding="utf-8")
    app_config = (ROOT / "deniz_app" / "lib" / "config" / "app_config.dart").read_text(
        encoding="utf-8"
    )
    version_line = next(l for l in pubspec.splitlines() if l.startswith("version:"))
    full = version_line.split(":", 1)[1].strip()
    base = full.split("+", 1)[0].strip()
    assert f"appVersion = '{base}'" in app_config
