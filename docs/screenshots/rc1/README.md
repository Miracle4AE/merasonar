# MeraSonar RC1 — Visual QA Screenshot Pack (RC1 Build9.7.1)

**Capture date:** 2026-07-05 · **Build:** RC1 Build9.7.1 (Dashboard Map Preview Runtime Cluster Fix)

## Dashboard map preview (RC1 Build9.7.1)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `dashboard-map-preview-runtime-cluster-fixed.png` | **Passed** | Widget export | RC1 Build9.7.1 | Runtime-like compact cluster fixture; selected score 37 centered; low-score markers capped; +N badge; no top-right chain |
| `dashboard-map-preview-reference-redesign.png` | **Passed** | Widget export | RC1 Build9.7 | Premium dark geo score preview; real-lat/lon projection path; selected marker reticle; no fake score marker |

**Capture command:**
```powershell
flutter test test/widget/dashboard_map_preview_redesign_test.dart --dart-define=DASH_MAP_QA_OUT=docs/screenshots/rc1
```

**Runtime QA note:** Canlı backend + gerçek fishing zone runtime QA önerilir. `PremiumMapPreviewCard` mission panel ayrı turda dashboard v2 painter ile hizalanabilir.

## Coordinate picker (RC1 Build9.7.2)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `coordinate-picker-selected-marker.png` | **Passed** | Widget export | RC1 Build9.7.2 | Haritadan koordinat seç modalı; seçili nokta marker/label; use button enabled |

## Map calibration confidence (RC1 Build9.6)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `map-calibration-low-confidence-warning.png` | **Passed** | Widget export | RC1 Build9.6 | Kullanıcı ince üçgen koordinatları · amber ribbon + marker alignment |
| `map-calibration-picker-thin-warning.png` | **Passed** | Widget export | RC1 Build9.6 | Picker helper — ince üçgen uyarısı |
| `map-calibration-valid-wide-triangle.png` | **Passed** | Widget export | RC1 Build9.6 | Sentetik geniş üçgen · yeşil valid banner (aynı referans foto pending) |

**Capture command:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\rc_build96_calibration_qa.ps1
```

## Premium Settings (RC1 Rebuild #9)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `settings-premium-screen.png` | **Passed** | Windows release runtime | RC1 Final Rebuild #9 | 6-kategori ayar ekranı; Bağlantı sekmesi görünür |

**Capture command:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\rc9_settings_premium_screenshot.ps1
```

## Captain Atlas live AI (RC1 Rebuild #8)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `captain-atlas-ai-live.png` | **Pending** | Windows release runtime | RC1 Final Rebuild #8 | API live smoke `source=ai` verified; UI screenshot pending after key rotation + backend restart |

**Live AI kanıt (API):**
- `python scripts/check_openai_config.py --live` → `LIVE_SOURCE: ai`
- `POST /api/v1/ai_fishing_assistant` → `source=ai`, `assistant_name=Captain Atlas`
- `POST /api/v1/marine_intelligence/coordinate` (`include_ai_comment=true`) → `ai_comment.source=ai`

## Map hotspot detail panel (RC1 Rebuild #6 — UI-15 bugfix)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `map-hotspot-detail-panel.png` | **Passed** | Windows release runtime | RC1 Final Rebuild #6 | Strip/marker tap opens detail panel; score, coord, Git/Kaydet/Karşılaştır/Captain Atlas visible |

## Map premium final (RC1 Rebuild #5 — UI-15)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `map-premium-final.png` | **Passed** | Windows release runtime | RC1 Final Rebuild #5 | Back/home button, compact top bar, filter toolbox, legend, hotspot strip, command bar dock; debug text gated |

## Map preview premium (RC1 Rebuild #4)

| File | Status | Platform | Build | Notes |
|------|--------|----------|-------|-------|
| `dashboard-map-preview-premium.png` | **Passed** | Windows release runtime | RC1 Final Rebuild #4 | Premium map preview verified; fake markers removed; real report/saved spot/compare data only; data integrity mode verified |

## Forecast + tide activation (RC1 Rebuild #3)

| File | Status | Notes |
|------|--------|-------|
| `dashboard-forecast-tide-active.png` | **Pending** | Build included; screenshot pending — 7-day forecast + Deniz Hareketi wave chart |
| `dashboard-timeline-fixed.png` | **Passed** | RC1 Final — timeline regression proof |

## Dashboard timeline fix (RC1 Final)

| File | Status | Notes |
|------|--------|-------|
| `dashboard-timeline-fixed.png` | **Passed** | RC1 Final rebuild — no 6-row `-- / Veri yok`; real timeline slots or single CTA |
| `dashboard.png` | **Superseded** | RC8 capture; use `dashboard-timeline-fixed.png` for timeline regression proof |

## Windows (runtime — release exe)

| File | Status | Source |
|------|--------|--------|
| `settings-premium-screen.png` | **Passed** | runtime (rebuilt exe, Rebuild #9) |
| `dashboard-map-preview-premium.png` | **Passed** | runtime (rebuilt exe, Rebuild #4) |
| `map-hotspot-detail-panel.png` | **Passed** | runtime (rebuilt exe, Rebuild #6) |
| `map-premium-final.png` | **Passed** | runtime (rebuilt exe, Rebuild #5) |
| `dashboard-timeline-fixed.png` | **Passed** | RC1 Final runtime capture (rebuilt exe) |
| `dashboard.png` | **Passed** | `rc6_capture_screenshots.ps1` (RC8 refresh) |
| `dashboard-online.png` | **Passed** | runtime |
| `dashboard-offline.png` | **Passed** | runtime |
| `live-area.png` | **Passed** | runtime |
| `marine-intelligence-screen.png` | **Passed** | runtime |
| `map-world.png` | **Passed** | runtime |
| `chart-overlay-screen.png` | **Passed** | runtime |
| `compare-screen.png` | **Passed** | runtime |
| `captain-atlas.png` | **Passed** | runtime (sidebar CTA) |
| `battery-saver-dashboard.png` | **Passed** | runtime |
| `saved-spot-ui-walkthrough.png` | **Passed** | runtime marine screen (`rc8_windows_marine_walkthrough.ps1`) |
| `catch-crud-ui-walkthrough.png` | **Passed** | runtime marine screen (same session) |

## Android (emulator-5554 runtime)

| File | Status | Source |
|------|--------|-------|
| `android-dashboard.png` | **Passed** | `rc8_android_qa_matrix.ps1` |
| `android-marine-intelligence.png` | **Passed** | runtime |
| `android-map.png` | **Passed** | runtime |
| `android-captain-atlas.png` | **Passed** | runtime |
| `android-smoke.png` | **Passed** | RC7 launch smoke (superseded by above) |

## Widget exports (supplemental)

| File | Status | Notes |
|------|--------|-------|
| `catch-dialog.png` | **Passed** | Widget export (RC7) |
| `saved-spot-crud.png` | **Passed** | Widget export (RC7) |

## Capture commands

```powershell
# Dashboard timeline fix (RC1 Final — single shot)
powershell -ExecutionPolicy Bypass -File scripts\rc1_dashboard_timeline_screenshot.ps1

# Full pack (RC8)
powershell -ExecutionPolicy Bypass -File scripts\rc9_settings_premium_screenshot.ps1
powershell -ExecutionPolicy Bypass -File scripts\rc6_capture_screenshots.ps1
powershell -ExecutionPolicy Bypass -File scripts\rc8_windows_marine_walkthrough.ps1
powershell -ExecutionPolicy Bypass -File scripts\rc8_android_qa_matrix.ps1
```

## Acceptance (RC1 Final)

- [x] Dashboard timeline: no 6-row `-- / Veri yok`
- [x] Timeline shows real slots or single contextual CTA
- [x] Overflow / debug border yok
- [x] Mission Control metni yok
- [x] CTA kırılması yok
- [x] Premium dark theme tutarlı
