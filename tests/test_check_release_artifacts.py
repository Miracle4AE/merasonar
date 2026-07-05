"""check_release_artifacts.py tests."""

from __future__ import annotations

import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_release_artifacts.py"


def test_missing_paths_fail() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--apk", "nonexistent/fake.apk"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0


def test_fake_windows_dir_with_env_fails(tmp_path: Path) -> None:
    release = tmp_path / "Release"
    release.mkdir()
    (release / "merasonar.exe").write_bytes(b"MZ")
    (release / ".env").write_text("OPENAI_API_KEY=sk-proj-" + "x" * 30, encoding="utf-8")
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--windows-dir",
            str(release),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0


def test_clean_fake_windows_dir_passes(tmp_path: Path) -> None:
    release = tmp_path / "Release"
    release.mkdir()
    (release / "merasonar.exe").write_bytes(b"MZ")
    (release / "data" / "flutter_assets").mkdir(parents=True)
    (release / "data" / "flutter_assets" / "AssetManifest.json").write_text(
        "{}", encoding="utf-8"
    )
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--windows-dir",
            str(release),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_fake_windows_zip_with_run_logs_fails(tmp_path: Path) -> None:
    release = tmp_path / "Release"
    release.mkdir()
    (release / "MeraSonar.exe").write_bytes(b"MZ")
    zpath = tmp_path / "bundle.zip"
    with zipfile.ZipFile(zpath, "w") as zf:
        zf.writestr("MeraSonar.exe", b"MZ")
        zf.writestr("run_logs/debug.log", "secret")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--windows-zip", str(zpath)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0


def test_clean_windows_zip_passes(tmp_path: Path) -> None:
    zpath = tmp_path / "bundle.zip"
    with zipfile.ZipFile(zpath, "w") as zf:
        zf.writestr("MeraSonar.exe", b"MZ" + b"\0" * 2048)
        zf.writestr("data/flutter_assets/AssetManifest.json", "{}")
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--windows-zip", str(zpath)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout


def test_fake_apk_passes(tmp_path: Path) -> None:
    apk = tmp_path / "app-release.apk"
    with zipfile.ZipFile(apk, "w") as zf:
        zf.writestr("AndroidManifest.xml", "<manifest/>" + (" " * 2048))
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--apk", str(apk)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr or result.stdout
