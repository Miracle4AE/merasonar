# MeraSonar v1.0.0-rc1 — RC1 Distribution Package

**Sürüm:** v1.0.0-rc1 (pubspec `1.0.0+1`)  
**Build / paket tarihi:** 2026-07-05 (RC1 Build9.6 — Map Calibration Confidence Fix)  
**Gate kararı:** **GO** (Build9.6 QA + artifact sanity validated)

## Final RC1 Build Tag

| Öğe | Değer |
|-----|--------|
| Final tag | `v1.0.0-rc1-build9.6` |
| Commit | Pending push |
| GitHub Release Build | Pending — tag push sonrası güncellenecek |
| Prior CI green | [run 28735788133](https://github.com/Miracle4AE/merasonar/actions/runs/28735788133) (build9.5) |
| CI artifacts | APK + Windows folder + zip uploaded |
| Lokal Rebuild #9.6 hashleri | **Current** — aşağıdaki tablolar |
| Dağıtım | CI artifact veya lokal `MeraSonar-windows-release.zip` / `app-release.apk` |

---

## Git / CI

| Öğe | Değer |
|-----|--------|
| Repository | https://github.com/Miracle4AE/merasonar |
| Branch | `main` |
| Tag | `v1.0.0-rc1-build9.6` (pending) · `v1.0.0-rc1-build9.5` @ `f9a5e2a` · `v1.0.0-rc1` @ `8fc4e99` (legacy) |
| Release Build CI | Pending build9.6 · prior [28735788133](https://github.com/Miracle4AE/merasonar/actions/runs/28735788133) (build9.5) |
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
| `flutter test` | 450 passed |
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
| Zip SHA256 | `a9701c25abd3cc0d69145d6f608e6080430471d92b40269ff841ce46853975ef` |
| Exe SHA256 | `385bc0a92a1e6a1e8c83bb22cd0f6c9d43bb6424b0f4358043d9febc2b3e2338` |
| `data/app.so` SHA256 | `b44d56b747485a37d331c7c5f29fcc62e5de2e0ee28abdc88ba1a6a6bef8d473` |

**Zip hash notu:** RC1 Build9.6 — Map Calibration Confidence Fix in `app.so`.

### Android

| Öğe | Yol |
|-----|-----|
| APK | `deniz_app/build/app/outputs/flutter-apk/app-release.apk` |
| SHA256 | `bf0ce1d6c418b6dd0e2b0e8f850a011eb664bff1fbf186cbf09dd1ae599b6f58` |
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
