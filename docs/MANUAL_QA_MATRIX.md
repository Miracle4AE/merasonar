# MeraSonar — Manual QA Matrix (RC1 Build9.7.1)

**RC1 Final date:** 2026-07-05 · Build9.7.1 Dashboard Map Preview Runtime Cluster Fix

**Platform:** W = Windows desktop · AP = Android fiziksel · AE = Android emülatör

## RC1 Build9.7.1 — Dashboard Map Preview Runtime Cluster Fix

**Date:** 2026-07-05 · **Tag:** `v1.0.0-rc1-build9.7.1` · **Commit:** `6f144f1` · **CI run:** [28745454536](https://github.com/Miracle4AE/merasonar/actions/runs/28745454536)

| Scenario | W | Status | Notes |
|----------|---|--------|-------|
| Runtime-like compact cluster fixture | ✓ | **Passed** | Selected score 37 + nine score-1 markers; no top-right chain |
| Compact cluster detector | ✓ | **Passed** | Meter span / overlap / top-right cluster assessment |
| Preview spread layout | ✓ | **Passed** | Selected centered; real marker lat/lon/score preserved |
| Low-score cap / summary badge | ✓ | **Passed** | Max 7 orbs; `+N düşük skor` badge |
| CI QA gates | ✓ | **Passed** | `pytest` 258 · `flutter analyze` 0 · `flutter test` 465 |
| Windows release artifact | ✓ | **Passed** | Build, zip, artifact sanity, upload |
| Android APK artifact | — | **Passed** | CI APK build + artifact sanity + upload |
| Artifact sanity on downloaded CI outputs | ✓ | **Passed** | APK + Windows dir + Windows zip OK |
| Runtime cluster screenshot | ✓ | **Passed** | `dashboard-map-preview-runtime-cluster-fixed.png` |

## RC1 Build9.7 — Dashboard Map Preview Premium Redesign

**Date:** 2026-07-05 · **Tag:** `v1.0.0-rc1-build9.7` · **Commit:** `aaaf0f3` · **CI run:** [28744783423](https://github.com/Miracle4AE/merasonar/actions/runs/28744783423)

| Scenario | W | Status | Notes |
|----------|---|--------|-------|
| CI QA gates | ✓ | **Passed** | `pytest` 258 · `flutter analyze` 0 · `flutter test` 460 |
| Windows release artifact | ✓ | **Passed** | Build, zip, artifact sanity, upload |
| Android APK artifact | — | **Passed** | CI APK build + artifact sanity + upload |
| CI artifact hash validation | ✓ | **Passed** | Downloaded artifacts hashed locally |
| Artifact sanity on downloaded CI outputs | ✓ | **Passed** | APK + Windows dir + Windows zip OK |
| Dashboard map preview screenshot | ✓ | **Passed** | `dashboard-map-preview-reference-redesign.png` widget export |
| Fake marker / fake score guard | ✓ | **Passed** | Projection/unit/widget tests; empty/limited state keeps map honest |
| Selected marker reticle | ✓ | **Passed** | Widget export + painter tests |

**Runtime QA note:** Canlı backend + gerçek fishing zone runtime QA önerilir. `PremiumMapPreviewCard` mission panel ayrı turda dashboard v2 painter ile hizalanabilir.

## RC1 Build9.6 — Map Calibration Confidence Manual QA

**Date:** 2026-07-05 · **Tag:** `v1.0.0-rc1-build9.6.1` · **CI run:** [28740932100](https://github.com/Miracle4AE/merasonar/actions/runs/28740932100)

| Scenario | W | Status | Notes |
|----------|---|--------|-------|
| Kullanıcı ince üçgen koordinatları → lowConfidence | ✓ | **Passed** | `37°23.755'N` … `37°26.769'N` · spread ~0.14 · geometry unit + ribbon export |
| Yeşil iddialı banner yok | ✓ | **Passed** | Eski *gerçek konuma oturmuş* metni kaldırıldı |
| Amber düşük güven şeridi | ✓ | **Passed** | `map-calibration-low-confidence-warning.png` |
| Marker string alignment warning | ✓ | **Passed** | 8+ hotspot tek meridyende → ribbon metnine ek uyarı |
| Picker helper / invalid guard | ✓ | **Passed** | `map-calibration-picker-thin-warning.png` · invalid → analiz kapalı |
| Geniş üçgen valid banner (aynı foto) | — | **Pending** | Referans harita dosyası repoda yok; sentetik valid panel doğrulandı |
| Geniş üçgen valid banner (sentetik) | ✓ | **Passed** | `map-calibration-valid-wide-triangle.png` |
| Marker tap / hotspot detail regression | ✓ | **Passed** | `flutter test` 450 · mevcut map widget testleri |
| Full rebuild + artifact sanity | ✓ | **Passed** | `release_verify.bat all` (subst `M:`) |

**Screenshots:** `docs/screenshots/rc1/map-calibration-*.png` · **Script:** `scripts/rc_build96_calibration_qa.ps1`

## RC1 Build9.5 Device Smoke QA

**Date:** 2026-07-05 · **Tag:** `v1.0.0-rc1-build9.5` · **CI run:** [28735788133](https://github.com/Miracle4AE/merasonar/actions/runs/28735788133)

| Scenario | W | AP | AE | Status | Notes |
|----------|---|---|---|--------|-------|
| CI artifact indir + hash doğrulama | ✓ | ✓ | — | **Passed** | APK `6C087D…ADFBD3` · zip `994B09…C239E` |
| Uygulama crash olmadan açılıyor | ✓ | — | ✓ | **Passed** | Process alive after smoke |
| Dashboard yükleniyor | ✓ | — | ✓ | **Passed** | `win-dashboard.png` · `android-02-dashboard.png` |
| Ayarlar / sunucu IP-port görünür | ✓ | — | ◐ | **Partial** | W: header `Bağlı: localhost:8000`; Premium Settings runtime shot CI exe'de otomasyon drift |
| Bağlantı testi / backend fallback | ✓ | — | ✓ | **Passed** | W: live marine data; AE offline modal dismiss OK; AE `Bağlı: 10.0.2.2:8000` |
| Harita ekranı | ✓ | — | ◐ | **Partial** | W: live API + markers; AE: Canlı Alan live score, map nav otomasyonu tamamlanmadı |
| Hotspot / strip detay | ✓ | — | ◐ | **Partial** | W: marker etiketleri + Yakındaki Meralar strip; bottom sheet shot eksik |
| Captain Atlas akışı (crash yok) | ✓ | — | ✓ | **Passed** | W: dashboard widget + map dock; AE: Koordinat ekranı açılıyor |
| GPS izin akışı | — | — | ✓ | **Passed** | Sistem diyaloğu crash yapmıyor; `pm grant` sonrası live GPS |
| Temiz Windows cihaz | — | — | — | **Not run** | Geliştirme makinesi (Win11 Pro) |
| Android fiziksel cihaz | — | ☐ | — | **Pending** | `sdk_gphone64_x86_64` emülatör kullanıldı |
| Overflow / crash | ✓ | — | ✓ | **Passed** | Gözle görülür taşma yok |

**Screenshots:** `docs/screenshots/rc1/build95-smoke/`

**Gate:** Windows CI smoke **Passed** (dev machine). Android **Partial** — fiziksel cihaz smoke pending.

## RC1 Final Rebuild #9 — Premium Settings Upgrade

| Scenario | W | AP | AE | Status | Notes |
|----------|---|---|---|--------|-------|
| Premium Settings ekranı (6 kategori) | ✓ | — | — | **Passed** | Widget + runtime screenshot |
| Server IP/port kaydet + health test | ✓ | — | — | **Passed** | Unit + connection test |
| ApiService base URL değişimi | ✓ | — | — | **Passed** | `app_settings_connection_test` |
| Dashboard auto-refresh timer | ✓ | — | — | **Passed** | Widget test + code review |
| Cache-first skeleton | ✓ | — | — | **Passed** | Dashboard bootstrap |
| Map defaults (mod/filtre/koordinat) | ✓ | — | — | **Passed** | Map screen init |
| Captain Atlas enable/disable | ✓ | — | — | **Passed** | Launcher guard |
| AI force refresh payload | ✓ | — | — | **Passed** | Controller + backend |
| Glow / reduce motion / compact | ✓ | — | — | **Passed** | Animation policy + shell |
| Reset all / cache clear | ✓ | — | — | **Passed** | Service tests |
| Legacy migration (server_ip only) | ✓ | — | — | **Passed** | `app_settings_service_test` |
| Fake toggle denetimi | ✓ | — | — | **Passed** | Helper/chip wired |
| Responsive settings UI | ✓ | ☐ | ☐ | **Partial** | Widget test 390px; runtime W OK |
| Artifact sanity Rebuild #9 | ✓ | ✓ | — | **Passed** | `check_release_artifacts.py` |
| `flutter test` 436 | ✓ | — | — | **Passed** | |

## RC1 Final Rebuild #8 — Captain Atlas Live AI

| Scenario | W | AP | AE | Status | Notes |
|----------|---|---|---|--------|-------|
| Captain Atlas live AI backend smoke | ✓ | — | — | **Passed** | `check_openai_config.py --live` → `LIVE_SOURCE: ai` |
| AI endpoint live smoke | ✓ | — | — | **Passed** | `/api/v1/ai_fishing_assistant` → `source=ai` |
| Marine coordinate AI comment smoke | ✓ | — | — | **Passed** | `include_ai_comment=true` → `ai_comment.source=ai` |
| Captain Atlas UI live AI (no fallback banner) | ☐ | ☐ | ☐ | **Pending** | API smoke passed; runtime screenshot pending |
| Fallback reason debug chip (kDebugMode) | ✓ | — | — | **Passed** | Widget + marine comment card |
| Key rotation (revoke exposed key) | — | — | — | **User action required** | OpenAI Dashboard revoke; new key local `.env` only |
| Artifact sanity Rebuild #8 | ✓ | ✓ | — | **Passed** | `release_verify.bat all` |
| GitHub Actions Release Build (tag v1.0.0-rc1) | — | — | — | **Passed** | run 28732259611 |

## RC1 Final priority summary

| Scenario | W | AP | AE | Status | Notes |
|----------|---|---|---|--------|-------|
| App opens | ✓ | ☐ | ✓ | **Passed** | RC1 Rebuild #3 exe |
| Dashboard visible | ✓ | ☐ | ✓ | **Passed** | |
| **Dashboard 7 Günlük Tahmin** | ✓ | ☐ | ☐ | **Build included** | Open-Meteo daily; runtime screenshot pending |
| **Dashboard Gelgit / Deniz Hareketi** | ✓ | ☐ | ☐ | **Build included** | `sea_movement` wave chart; runtime screenshot pending |
| Forecast fake data | — | — | — | **Not used** | No synthetic 7-day forecast |
| Tide fake data | — | — | — | **Not used** | No synthetic astronomical tide |
| Tide provider (WorldTides) | — | — | — | **Disabled** | `TIDE_PROVIDER_ENABLED=false` default |
| **Dashboard fresh data (live score / akıntı)** | ✓ | ☐ | ☐ | **Passed** | |
| **Dashboard timeline regression** | ✓ | ☐ | ☐ | **Passed** | No 6-row Veri yok |
| Backend online | ✓ | ☐ | ◐ | **Partial** | W Passed |
| Live Area | ✓ | ☐ | ☐ | **Passed** | |
| Coordinate Analysis | ✓ | ☐ | ✓ | **Passed** | |
| Compare | ✓ | ☐ | ☐ | **Passed** | |
| Captain Atlas Command Center | ✓ | ☐ | ✓ | **Passed** | Live AI backend smoke Rebuild #8 |
| No obvious overflow | ✓ | ☐ | ✓ | **Passed** | |

## Build artifact smoke

| # | Check | Status |
|---|-------|--------|
| A | Windows RC1 Rebuild #8 exe | **Passed** |
| B | Android RC1 Rebuild #8 APK | **Passed** |
| C | Artifact sanity | **Passed** |
| D | CI tag validation | **Pending** — no local git repo |

---

**Son güncelleme:** RC1 Build9.6 Map Calibration Confidence · `docs/releases/v1.0.0-rc1-artifacts.md`
