# MeraSonar v1.0.0-rc1 — RC1 Distribution Package

**Sürüm:** v1.0.0-rc1 (pubspec `1.0.0+1`)  
**Build / paket tarihi:** 2026-07-05 (RC1 Build9.7.1 — Dashboard Map Preview Runtime Cluster Fix)  
**Gate kararı:** **GO** (Build9.7.1 CI QA + artifact sanity validated)

## Final RC1 Build Tag

| Öğe | Değer |
|-----|--------|
| Final tag | `v1.0.0-rc1-build9.7.1` (CI green · dağıtım) |
| Commit | `6f144f1` |
| GitHub Release Build | **Passed** — [run 28745454536](https://github.com/Miracle4AE/merasonar/actions/runs/28745454536) |
| Not | Dashboard Map Preview runtime cluster fix; `build9.7` önceki redesign tag’i olarak korunuyor |
| CI artifacts | APK + Windows folder + zip uploaded |
| Lokal Rebuild #9.6 hashleri | **Preserved** — CI build9.7 artifactleri dağıtım kaynağı |
| Dağıtım | CI artifact veya lokal `MeraSonar-windows-release.zip` / `app-release.apk` |

---

## Git / CI

| Öğe | Değer |
|-----|--------|
| Repository | https://github.com/Miracle4AE/merasonar |
| Branch | `main` |
| Tag | `v1.0.0-rc1-build9.7.1` @ `6f144f1` (final CI green) · `v1.0.0-rc1-build9.7` @ `aaaf0f3` |
| Release Build CI | **Passed** — [28745454536](https://github.com/Miracle4AE/merasonar/actions/runs/28745454536) (build9.7.1) |
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
| `flutter test` | 465 passed |
| `release_verify.bat qa` | OK |
| `check_release_artifacts.py` | OK |
| Manual QA | Build9.7.1 runtime cluster fixture export — bkz. `docs/MANUAL_QA_MATRIX.md` |

---

## Dağıtım artifact’leri

### Windows (CI build9.7.1 — dağıtım)

| Öğe | Değer |
|-----|--------|
| CI run | [28745454536](https://github.com/Miracle4AE/merasonar/actions/runs/28745454536) |
| Zip SHA256 | `0a19d10d846ecdb0f1a8f1a96a9f6830daf04088d48f8284580e14dbbcef4d55` |
| Exe SHA256 | `d881455332db6483b2877eeed48c27a934b65957ff412fe82a920ede7b15132c` |
| `data/app.so` SHA256 | `22debc742094797d9c9cea271f957b45afcff90244c97a33b77daa03e80865c8` |

### Windows (lokal Rebuild #9.6)

| Öğe | Değer |
|-----|--------|
| Zip SHA256 | `a9701c25abd3cc0d69145d6f608e6080430471d92b40269ff841ce46853975ef` |
| Exe SHA256 | `385bc0a92a1e6a1e8c83bb22cd0f6c9d43bb6424b0f4358043d9febc2b3e2338` |
| `data/app.so` SHA256 | `b44d56b747485a37d331c7c5f29fcc62e5de2e0ee28abdc88ba1a6a6bef8d473` |

### Android (CI build9.7.1 — dağıtım)

| Öğe | Değer |
|-----|--------|
| SHA256 | `d964ba8840b337b7db8c2d6cd4998cc224987a98e6ab81e980ae9fd0326b49df` |

### Android (lokal Rebuild #9.6)

| Öğe | Değer |
|-----|--------|
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
