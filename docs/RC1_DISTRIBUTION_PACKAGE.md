# MeraSonar v1.0.0-rc1 — RC1 Distribution Package

**Sürüm:** v1.0.0-rc1 (pubspec `1.0.0+1`)  
**Build / paket tarihi:** 2026-07-05 (RC1 Final Rebuild #8 + RC Phase 10 Git/CI)  
**Gate kararı:** **GO** (RC8 + Rebuild #8 + CI validated)

---

## Git / CI

| Öğe | Değer |
|-----|--------|
| Repository | https://github.com/Miracle4AE/merasonar |
| Branch | `main` |
| Tag | `v1.0.0-rc1` @ `8fc4e99584acfb995ab461a69859bb0ce966df1a` |
| Release Build CI | **Passed** — run [28732259611](https://github.com/Miracle4AE/merasonar/actions/runs/28732259611) |
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
| `flutter test` | 423 passed |
| `release_verify.bat all` | OK |
| `check_release_artifacts.py` | OK |
| Manual QA | RC8 matrix + Rebuild #8 — bkz. `docs/MANUAL_QA_MATRIX.md` |

---

## Dağıtım artifact’leri

### Windows

| Öğe | Yol |
|-----|-----|
| Release klasörü | `deniz_app/build/windows/x64/runner/Release/` |
| Çalıştırılabilir | `MeraSonar.exe` |
| Zip paketi | `deniz_app/MeraSonar-windows-release.zip` |
| Zip SHA256 | `e49728002a41a8c7208ee91a9c19710be0086d83e899eb4df2df6f4d347c7ac6` |
| Exe SHA256 | `561cb78cda7d0a0dc2779d36c52c377d31f7b6f33f178cad2f534869951a7762` |
| `data/app.so` SHA256 | `1dd05d0fea841997703030664c6cff6f3e868463ff1fadd64b542692920412a7` |

**Zip hash notu:** RC1 Final Rebuild #8 — Captain Atlas live AI schema fix + `force_refresh` cache bypass in `app.so`.

### Android

| Öğe | Yol |
|-----|-----|
| APK | `deniz_app/build/app/outputs/flutter-apk/app-release.apk` |
| SHA256 | `ba949ba4efc1518daf67d415889cb83e6236d1cdd7a3bd67cc620482765cf0c3` |
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
