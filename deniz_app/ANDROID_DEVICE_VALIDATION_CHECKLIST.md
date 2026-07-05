# Real Android device validation (manual)

Use this after `flutter build apk --debug` or `flutter install` with USB debugging enabled.

**Prerequisites**
- Developer options + USB debugging on the phone, or `adb connect` over LAN.
- Backend (FastAPI) running on your PC; phone and PC on the **same Wi‑Fi**.
- Server field: **LAN IP of the PC** (e.g. `192.168.x.x`), never `localhost` or `127.0.0.1`.

## Commands (from `deniz_app/`)

```powershell
flutter pub get
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
# or: flutter install   (with device connected)
adb logcat | findstr /i flutter deniz
```

## Checklist (tick when verified)

1. [ ] **Install** — Debug APK installs and launches without immediate crash.
2. [ ] **LAN IP** — In Photo Analysis → server / IP dialog: save **PC LAN IP** only; app rejects loopback on Android for **Live Area** (can still open Photo Analysis to fix IP).
3. [ ] **Gallery** — **Alanı Tara** → pick chart from gallery; Photo Picker opens; image loads into overlay flow.
4. [ ] **Analysis completes** — Loading ends; hotspots / session copy shown; no permanent red error banner (unless backend down).
5. [ ] **image_space overlay** — Analysis without 3+ control points (or image-only mode): chart stays in **overlay / image_space** view as designed.
6. [ ] **Live Area** — From home, open Live Area (with valid LAN IP).
7. [ ] **image_space warning** — If last analysis is `image_space`, nearby card shows image-only + **Calibrate Map** path (no fake GPS distance to image-space hotspots).
8. [ ] **Calibrated run** — Map → place **≥3 control points** → re-run analysis → `coordinate_mode` geo.
9. [ ] **Nearest hotspot (geo only)** — Live Area with **geo_referenced** cache: after GPS fix, server may return `nearest_hotspot` when hotspots have real lat/lon; with **image_space** cache, API must **not** claim real-world nearest distance (warning UI).
10. [ ] **Resilience** (no crash, sensible UI):
    - [ ] **GPS off** — System location off → Live Area shows message + **Open location settings**.
    - [ ] **Permission denied** — Deny location → explanation + **Request again** / **App settings**.
    - [ ] **Server down** — Stop FastAPI → refresh → error text + retry hint, no crash.
    - [ ] **Background** — Send app to background 30s, return → no crash; auto-refresh resumes per toggle.

## Optional log capture

```powershell
adb logcat *:E flutter:V AndroidRuntime:E > deniz_crash_log.txt
```

If something fails, attach `deniz_crash_log.txt` and the exact step number.
