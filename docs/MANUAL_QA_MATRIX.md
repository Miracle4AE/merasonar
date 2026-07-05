# MeraSonar — Manual QA Matrix (RC1 Final Rebuild #9)

**RC1 Final date:** 2026-07-05 · Premium Settings Upgrade + binary rebuild

**Platform:** W = Windows desktop · AP = Android fiziksel · AE = Android emülatör

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

**Son güncelleme:** RC1 Final Rebuild #9 · `docs/releases/v1.0.0-rc1-artifacts.md`
