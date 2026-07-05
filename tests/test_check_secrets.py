"""check_secrets.py script tests."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_secrets.py"


def test_check_secrets_passes_on_clean_repo() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_env_example_openai_key_is_placeholder_or_empty() -> None:
    example = (ROOT / ".env.example").read_text(encoding="utf-8")
    for line in example.splitlines():
        if line.strip().startswith("OPENAI_API_KEY="):
            value = line.split("=", 1)[1].strip()
            assert value == "" or "your" in value.lower() or value == "sk-your-key-here"
            return
    raise AssertionError("OPENAI_API_KEY not found in .env.example")
