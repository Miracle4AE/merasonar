# MeraSonar v1.0.0-rc1 — RC1 Distribution Package

**Sürüm:** v1.0.0-rc1 (pubspec `1.0.0+1`)  
**Build / paket tarihi:** 2026-07-05 (RC1 Final Rebuild #9 — Premium Settings Upgrade)  
**Gate kararı:** **GO** (Rebuild #9 QA + artifact sanity validated)

**Ops note (2026-07-05):** Script-only cleanup — Flutter auto-detection (`FLUTTER_BIN` / PATH / puro), `prepare_windows_build_drive.bat`, `docs/BUILD_WINDOWS.md`. **No app binary changes; Rebuild #9 artifacts remain current.**

## Final RC1 Build Tag

| Öğe | Değer |
|-----|--------|
| Final tag | `v1.0.0-rc1-build9.5` |
| Commit | `f9a5e2a` |
| GitHub Release Build | **Passed** — [run 28735788133](https://github.com/Miracle4AE/merasonar/actions/runs/28735788133) |
| CI artifacts | APK + Windows folder + zip uploaded |
| Lokal Rebuild #9 hashleri | Korunuyor (yeni lokal rebuild yok) |
| Dağıtım | CI artifact veya lokal `MeraSonar-windows-release.zip` / `app-release.apk` |

---

## Git / CI

| Öğe | Değer |
|-----|--------|
| Repository | https://github.com/Miracle4AE/merasonar |
| Branch | `main` |
| Tag | `v1.0.0-rc1-build9.5` @ `f9a5e2a` (final CI green) · `v1.0.0-rc1` @ `8fc4e99` (legacy) |
| Release Build CI | **Passed** — [28735788133](https://github.com/Miracle4AE/merasonar/actions/runs/28735788133) (build9.5) |
| CI artifacts | `MeraSonar-android-apk`, `MeraSonar-windows-release`, `MeraSonar-windows-release-zip` |

**CI artifact indirme:** GitHub Actions → Release Build run → Artifacts bölümü.

**Dağıtım notu:**
- Windows: `MeraSonar-windows-release.zip` (lokal veya CI)
- Android APK: test/internal distribution — Play upload için production signing gerekir
- Lokal ve CI hashleri farklı olabilir (Flutter sürüm farkı); her ikisi de artifact sanity geçer

---

## Test özeti

| Kapı | Sonuç |
|------|--------|
| `check_secrets.py` | OK |
| `check_release_config.py` | OK |
| `check_openai_config.py --live` | OK — `LIVE_SOURCE: ai` |
| `pytest` | 258 passed |
| `flutter analyze` | 0 issue |
| `flutter test` | 436 passed |
| `release_verify.bat qa` | OK |
| `check_release_artifacts.py` | OK |
| Manual QA | Rebuild #9 matrix — bkz. `docs/MANUAL_QA_MATRIX.md` |

---

## Dağıtım artifact’leri

### Windows

| Öğe | Yol |
|-----|-----|
| Release klasörü | `deniz_app/build/windows/x64/runner/Release/` |
| Çalıştırılabilir | `MeraSonar.exe` |
| Zip paketi | `deniz_app/MeraSonar-windows-release.zip` |
| Zip SHA256 | `39d0a3389406429cc156364dd128643954d870b5e8c5c91cb0b052e1737c887c` |
| Exe SHA256 | `385bc0a92a1e6a1e8c83bb22cd0f6c9d43bb6424b0f4358043d9febc2b3e2338` |
| `data/app.so` SHA256 | `4d5ce6819c3b554c3603019d04d309c7029678f8e333192c61629556b372e09c` |

**Zip hash notu:** RC1 Final Rebuild #9 — Premium Settings upgrade in `app.so`.

### Android

| Öğe | Yol |
|-----|-----|
| APK | `deniz_app/build/app/outputs/flutter-apk/app-release.apk` |
| SHA256 | `b22b6d7b8c6a1d85cf0f5230e0a2626cd282cf0dcaa6c1164ba958b4d6f1d39c` |
| İmzalama | Flutter debug/release keystore (Play upload key değil) |

---

## Security — key rotation

Önceki oturumda API key ekranda göründüğü için **ifşa kabul edilir**. OpenAI Dashboard üzerinden **revoke** edilmeli ve yeni key yalnızca lokal `.env` içine yazılmalıdır. Key değişikliği sonrası backend restart zorunludur.

---

## QA kanıt paketi

| İçerik | Konum |
|--------|--------|
| Screenshot’lar | `docs/screenshots/rc1/` |
| Screenshot README | `docs/screenshots/rc1/README.md` |
| Manual QA matrix | `docs/MANUAL_QA_MATRIX.md` |
| Live AI smoke | `python scripts/check_openai_config.py --live` → `LIVE_SOURCE: ai` |

---

## Release dokümantasyonu

| Doküman | Açıklama |
|---------|----------|
| `docs/releases/v1.0.0-rc1.md` | Release notes |
| `docs/releases/v1.0.0-rc1-artifacts.md` | Artifact manifest + hash |
| `docs/GIT_RELEASE_TAG_PLAN.md` | Tag / CI push planı |
| `docs/RELEASE_CHECKLIST.md` | Yayın öncesi checklist |
| `docs/PRIVACY_AND_STORE_CHECKLIST.md` | Mağaza / gizlilik |

---

## Bilinen pending maddeler

- Git repository / tag / CI release-build doğrulaması **Passed** (2026-07-05)
- Captain Atlas UI live AI screenshot **pending** — API live smoke `source=ai` kanıtlandı
- Premium Settings screenshot **Passed** — `settings-premium-screen.png`
- Android full QA matrisi **partial**
- Play upload signing **pending**
- OS-level reduce motion **pending**
- Windows exe dialog otomasyonu (saved spot / catch formları) **partial**
- **Key rotation:** kullanıcı aksiyonu gerekli (revoke + yeni key)

---

## Dağıtım talimatları

1. Backend: `uvicorn main:app --host 0.0.0.0 --port 8000` veya `docker compose up --build`
2. Windows: `deniz_app/MeraSonar-windows-release.zip` çıkar → `MeraSonar.exe`
3. Android: `app-release.apk` sideload (Play upload key değil)
4. `.env` içinde geçerli `OPENAI_API_KEY` + `AI_ASSISTANT_ENABLED=true` — key repo'ya commit edilmez

---

## Local Build Environment Notes

See **`docs/BUILD_WINDOWS.md`** for full details.

| Topic | Guidance |
|-------|----------|
| Recommended path | `C:\dev\merasonar` or `D:\dev\merasonar` |
| Non-ASCII / space path | Run `scripts\prepare_windows_build_drive.bat`, then `M:` and `set MERASONAR_BUILD_DRIVE=M:` |
| Puro Flutter | `set FLUTTER_BIN=%USERPROFILE%\.puro\envs\stable\flutter\bin\flutter.bat` |
| Unmap drive | `subst M: /d` (manual, when build finished) |

**No app binary changes in ops cleanup; Rebuild #9 artifact hashes remain current.**
