# MeraSonar — Windows / Local Release Build

Short guide for local release builds on Windows.

## Local Build Environment Notes

### Recommended repo path

Prefer an ASCII-only path without spaces:

```
C:\dev\merasonar
D:\dev\merasonar
```

Paths with Turkish characters or spaces (e.g. `d:\Deniz uygulaması`) can break Flutter Android AOT builds.

### Flutter SDK (puro)

If Flutter is not on PATH, set `FLUTTER_BIN` once per terminal session:

```bat
set FLUTTER_BIN=C:\Users\sahin\.puro\envs\stable\flutter\bin\flutter.bat
scripts\release_verify.bat qa
```

Detection order in `release_verify.bat` (via `scripts\_resolve_flutter.bat` + `scripts\flutter_exec.bat`):

1. `FLUTTER_BIN` environment variable
2. `puro flutter` (when `puro` is on PATH — recommended for nested batch)
3. `flutter.bat` on PATH
4. `%USERPROFILE%\.puro\envs\stable\flutter\bin\flutter.bat`

Alternatively add Flutter `bin` to your user PATH permanently.

### Non-ASCII path — mapped drive (subst)

When the repo must stay on a non-ASCII path, map it to drive `M:` first:

```bat
scripts\prepare_windows_build_drive.bat
M:
set MERASONAR_BUILD_DRIVE=M:
scripts\release_verify.bat all
```

Optional: use another drive letter:

```bat
set MERASONAR_BUILD_DRIVE=N:
scripts\prepare_windows_build_drive.bat
```

To unmap when finished:

```bat
subst M: /d
```

**Note:** `prepare_windows_build_drive.bat` does not unmap automatically. It will not overwrite `M:` if it is already mapped elsewhere.

### Release verify modes

| Command | Purpose |
|---------|---------|
| `scripts\release_verify.bat qa` | Secrets, config, pytest, flutter analyze/test |
| `scripts\release_verify.bat windows` | Windows release build + zip + artifact scan |
| `scripts\release_verify.bat apk` | Android APK + artifact scan |
| `scripts\release_verify.bat all` | Windows + APK |

Build modes require an ASCII-safe path or `MERASONAR_BUILD_DRIVE` pointing at a prepared mapped drive.

### Pre-flight check

```bat
python scripts\check_release_config.py
```

Reports Flutter path, non-ASCII path warnings, version alignment, and release output paths.

### CI

GitHub Actions uses ASCII paths (`ubuntu-latest`, `windows-latest`) — local path issues do not affect CI.

---

*RC1 Final Rebuild #9 — ops cleanup (Flutter detection + build drive helper).*
