# Deniz uygulaması (Maritime Fishing Zone) — MeraSonar

Flutter istemci uygulama adı: **MeraSonar**. Harita/ekran görüntüsü ile **balıkçılık bölgesi analizi** yapan proje: **Python (FastAPI)** arka uç, **Flutter** istemci (Windows / Android; diğer platformlar standart Flutter desteğiyle derlenebilir). Analiz fotoğrafı baz alır; gerçek koordinat istenirse fotoğraf üzerinde en az 3 kontrol noktası girilir.

## Bileşenler

| Klasör / dosya | Açıklama |
|----------------|----------|
| `main.py` | FastAPI uygulaması, varsayılan port **8000** |
| `deniz_app/` | Flutter uygulaması |
| `Dockerfile`, `docker-compose.yml` | Arka ucu konteynerde çalıştırmak için |
| `tests/` | Pytest testleri (orkestratör, bati vb.) |

Dış servis zenginleştirmesi (deniz durumu, derinlik, türler) `marine_data_client.py` üzerinden ücretsiz API’lere gider; ayrıntılar kod içinde.

## Gereksinimler

- **Python 3.10+** (Docker imajı 3.10 kullanır)
- **Flutter SDK** (Flutter doctor ile SDK ve platform araçları)

## Arka ucu çalıştırma (yerel)

Proje kökünde:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

- Sağlık kontrolü: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)
- API: `POST /api/v1/analyze_fishing_zone` (istek detayı Flutter `api_service` ile aynı sözleşmeyi kullanır)

## Image-space debug overlay (heatmap / piksel hizalı analiz)

Kontrol noktası yokken arka uç **image-space** modunda döner; hotspot koordinatları **yüklenen grafik görüntüsünün** pikselleridir. Hata ayıklama için grafik üzerine sınıflandırılmış noktaları (A=kırmızı, B=sarı, C=yeşil) ve `sınıf + rank + score` etiketi basan PNG üretebilirsiniz:

- Dosyalar **`run_logs/`** altına yazılır (geçici `temp` klasörleri kullanılmaz).
- API ile analiz sonrası isteğe bağlı kayıt: form alanı **`debug=true`**. Grafik **`run_logs/debug_input_chart.<uzantı>`** olarak saklanır, overlay **`run_logs/image_space_hotspot_overlay.png`** yolunda oluşur (başarıda `diagnostics.image_space_debug_overlay_path` ile döner).
- Tüm hotspot **daireleri** her zaman çizilir; **etiketler** üst üste binmeyi azaltacak şekilde yerleştirilir: **A sınıfı ilk 10** (rank) zorunlu; diğerleri çakışma ve yakınlaştırma ipucu (`debug_overlay_zoom`, varsayılan 1.0; düşük = daha az ikincil etiket, yüksek = daha fazla) ile eklenir.
- Çıktı iki dosyadır: **`image_space_hotspot_overlay.png`** (etiketli + sınıf göstergesi) ve **`image_space_hotspot_overlay_clean.png`** (sadece işaretleyiciler ve gösterge).
- Tüm metin etiketleri isteğe bağlı: **`debug_show_all_labels=true`** (`debug=true` ile).

Yerelde JSON + grafik görüntüsünden yeniden oluşturmak için (proje kökünden):

```bash
python scripts/export_image_space_overlay.py --chart run_logs/debug_input_chart.png --json run_logs/latest_image_space_response.json --output run_logs/image_space_hotspot_overlay.png
```

Temiz (etiketsiz) PNG’yi üretmemek için `--no-clean`.

Tüm sıra için etiket veya yakınlaştırma ipucu:

```bash
python scripts/export_image_space_overlay.py --chart run_logs/debug_input_chart.png --json run_logs/latest_image_space_response.json --show-all-labels
python scripts/export_image_space_overlay.py --chart run_logs/debug_input_chart.png --json run_logs/latest_image_space_response.json --zoom 1.4
```

Ek etiket sırası üst sınırı ( `--show-all-labels` yokken): `--max-labeled-ranks 30`.

Üçüncü argümana gerek kalmadan `--output` atlanabilir (varsayılan yukarıdaki `run_logs/image_space_hotspot_overlay.png`).

## Docker ile arka uç

Proje kökünde:

```bash
docker compose up --build
```

Port **8000** hosta yayınlanır (`docker-compose.yml`).

## Flutter istemciyi çalıştırma

```bash
cd deniz_app
flutter pub get
flutter run
```

Harita ekranından **GPX dışa aktarma** (mera noktalarını dosya olarak paylaşma) için bkz. `deniz_app/README.md`.

## Telefon / ağ: neden `localhost` yetmez?

- **Aynı makinede** (ör. Windows’ta `flutter run -d windows`): `127.0.0.1` veya `localhost` arka uca gidebilir.
- **Fiziksel telefon veya emülatör**, arka uç **bilgisayarda** çalışıyorsa: cihazın `localhost`’u telefonun kendisidir, bilgisayarın API’si değildir. İstemcide uygulama içi **Sunucu IP** alanına bilgisayarın **yerel ağ IP adresini** yazın (ör. `192.168.x.x`), port **8000** sabit kalır. Bilgisayar ve telefon aynı Wi-Fi’da olmalı; Windows güvenlik duvarı 8000’e izin vermelidir.

## Python testleri

Geliştirme ve CI, `requirements.txt` yanında `pytest` içeren `requirements-dev.txt` dosyasını kullanır:

```bash
pip install -r requirements-dev.txt
pytest
```

## Sürekli entegrasyon (CI)

Her **push** ve **pull request**’te **GitHub Actions** çalışır:

- **Python:** `pip install -r requirements-dev.txt` → `pytest`
- **Flutter:** `deniz_app` içinde `flutter analyze` ve `flutter test`

İş akışı dosyası: `.github/workflows/ci.yml`.

## AI Fishing Assistant (Faz 1–5 — backend)

Sidecar endpoint; mevcut `analyze_fishing_zone` pipeline'ına dokunmaz.

```bash
# .env.example dosyasını kopyalayıp OPENAI_API_KEY ve OPENAI_MODEL doldurun
POST /api/v1/ai_fishing_assistant
```

### Ortam değişkenleri

| Değişken | Açıklama | Varsayılan |
|----------|----------|------------|
| `OPENAI_API_KEY` | OpenAI API anahtarı (yalnızca sunucuda) | — |
| `OPENAI_MODEL` | Model adı | — |
| `AI_ASSISTANT_ENABLED` | AI endpoint aktif | `false` |
| `PROMPT_VERSION` | Prompt sürüm etiketi | `v1` |
| `VISION_ENABLED` | Grafik görüntüsü vision | `false` |
| `STREAMING_ENABLED` | Akış (henüz uygulanmadı) | `false` |
| `CACHE_TTL` | Yanıt önbellek süresi (sn) | `900` |
| `AI_RATE_LIMIT_ENABLED` | IP bazlı dakikalık limit | `false` |
| `AI_RATE_LIMIT_PER_MINUTE` | Limit aşımında 429 | `30` |
| `AI_MAX_ESTIMATED_COST_PER_REQUEST_USD` | Maliyet guard eşiği (0=kapalı) | `0` |
| `AI_COST_INPUT_PER_1M` / `AI_COST_OUTPUT_PER_1M` | Tahmini maliyet hesabı | `0` |
| `AI_QUOTA_ENABLED` | Günlük cihaz/kullanıcı kotası | `false` |
| `AI_FREE_DAILY_LIMIT` | Ücretsiz günlük limit | `10` |
| `AI_PREMIUM_DAILY_LIMIT` | Premium günlük limit | `100` |
| `AI_TELEMETRY_PERSIST_ENABLED` | JSONL telemetri kalıcılığı | `false` |
| `AI_TELEMETRY_JSONL_PATH` | Telemetri dosya yolu | `run_logs/ai_telemetry.jsonl` |
| `AI_USAGE_ADMIN_KEY` | Usage summary admin koruması | — |

### Client identity (Faz 5)

İstek gövdesine opsiyonel `client_identity` eklenebilir:

- `device_id`, `user_id` (nullable), `app_version`, `platform`, `is_premium`
- Kimlik yoksa IP fallback kullanılır
- Mevcut Flutter istekleri `client_identity` olmadan çalışmaya devam eder

### Usage summary

```http
GET /api/v1/ai_usage_summary?device_id=...&user_id=...
X-AI-Usage-Admin-Key: ...   # AI_USAGE_ADMIN_KEY tanımlıysa zorunlu
```

Dönen alanlar: `total_requests`, `ai_requests`, `fallback_requests`, `cache_hit_rate`, `estimated_total_cost`, `by_scope`, `by_model`, `quota_remaining`.

### Redis-ready altyapı

Cache (`AiResponseCacheProtocol`), rate limit (`AiRateLimiterProtocol`), quota (`AiQuotaStoreProtocol`) ve telemetry store (`AiTelemetryStoreProtocol`) arayüzleri production'da **Redis** implementasyonu takmaya hazırdır. Şu an in-memory varsayılan kullanılır.

### Scope: `live_context`

Flutter Faz 3 canlı alan ekranı `live_context` nesnesi gönderir:

- `current_lat`, `current_lon`, `gps_accuracy_m`
- `live_score`, `rating`, `reasoning`
- `nearest_hotspot`, `distance_to_nearest`, `bearing_to_nearest`
- `coordinate_mode` — `image_space` ise backend konum iddiası yapmaz

Bilinmeyen ek alanlar güvenle yok sayılır (`extra=ignore`).

### Production notları

- API anahtarları yanıt, log veya `/health` içinde **asla** dönmez.
- Rate limit varsayılan **kapalı**; açıldığında limit aşımı fallback değil **429** döner.
- Cost guard varsayılan **kapalı**; açıldığında eşik aşımında OpenAI çağrısı yapılmaz, deterministik fallback döner.
- Yanıtta opsiyonel alanlar: `mode`, `focus_hotspot_id`, `telemetry`, `remaining_ai_requests`, `is_premium_feature` — mevcut Flutter istemcisi bunları zorunlu görmez.
- Kota varsayılan **kapalı**; açıldığında limit aşımı **429** (`quota_exceeded`) döner.
- Telemetri kalıcılığı varsayılan **kapalı**; açıldığında JSONL dosyasına yazar (secret/key asla yazılmaz).

`GET /health` yanıtına geriye uyumlu `ai_assistant` bloğu eklenir (`quota_enabled`, `telemetry_persist_enabled`, `usage_summary_enabled` dahil).

## Marine Intelligence (Faz 7a)

Sidecar paket: `marine_intelligence/` — mevcut `analyze_fishing_zone` pipeline'ına dokunmaz.

### Endpoint

`POST /api/v1/marine_intelligence/coordinate`

```json
{
  "lat": 37.12345,
  "lon": 27.12345,
  "include_ai_comment": false,
  "force_refresh": false
}
```

Çalışan provider'lar: **Open-Meteo** (weather/wind/marine), **Astronomy Local** (güneş/ay, API çağrısı yok). MGM, Windy, Windy.app, Poseidon stub olarak hazır; varsayılan kapalı.

Gelecek faz alanları (`tide`, `fish_activity`, `marine_risk`, `decision`, `scenario`, `decision_timeline`, `historical`, `trends`, `ai_comment`) yanıtta **null** döner. Faz 7b ile `provider_comparison` ve `explainability` dolu döner.

Ortam değişkenleri: `.env.example` içindeki `MARINE_INTELLIGENCE_*` ve provider bayrakları.

### Faz 7b — Weighted Consensus + Provider Comparison + Explainability

- **Weighted consensus:** Sayısal metriklerde ağırlıklı ortalama; açılarda dairesel ağırlıklı ortalama. Tek kaynak `confidence ≤ 0.60`; çok kaynakta anlaşmazlık seviyesine göre güven.
- **Provider comparison:** Her sağlayıcı için `weight`, `confidence`, `status`, `metrics_provided` ve özet sayaçlar.
- **Explainability foundation:** AI yok; rüzgar/dalga/swell/yağış ve kısmi veri durumuna göre deterministik Türkçe faktör listesi.

Örnek yanıt parçası:

```json
{
  "consensus_summary": {
    "overall_confidence": 0.6,
    "provider_count": 2,
    "source_count_by_group": {"weather": 1, "wind": 1, "marine": 1},
    "strongest_group": "weather",
    "weakest_group": "marine",
    "disagreement_groups": [],
    "partial_data_reason": null
  },
  "provider_comparison": {
    "providers": [
      {
        "name": "open_meteo",
        "enabled": true,
        "status": "ok",
        "weight": 1.0,
        "confidence": 0.75,
        "metrics_provided": ["temperature_c", "wind_speed_kmh", "wave_height_m"]
      }
    ],
    "summary": {
      "provider_count": 2,
      "healthy_count": 2,
      "overall_provider_confidence": 0.75
    }
  },
  "explainability": {
    "positive_factors": ["Rüzgar seviyesi yönetilebilir görünüyor."],
    "negative_factors": [],
    "uncertainty_factors": ["Veri yalnızca tek sağlayıcıdan geldiği için güven orta seviyede."],
    "explanation_summary_tr": "Olumlu: Rüzgar seviyesi yönetilebilir görünüyor."
  }
}
```

### Faz 7c — Saved Spots (Spot Intelligence CRUD + Refresh)

Kullanıcı koordinatları isim vererek kaydeder, listeler, günceller, siler ve **Güncelle** ile güncel marine raporu alır.

Storage: varsayılan **SQLite** (`MARINE_SPOT_STORAGE_PATH`); `SpotIntelligenceStoreProtocol` ile PostgreSQL JSONB'ye taşınmaya hazır.

| Endpoint | Açıklama |
|----------|----------|
| `POST /saved_spots` | Yeni spot kaydet |
| `GET /saved_spots?favorite=` | Listele (favorite önce, `updated_at` desc) |
| `PATCH /saved_spots/{id}` | name/note/favorite/tags güncelle |
| `DELETE /saved_spots/{id}` | Sil |
| `POST /saved_spots/{id}/refresh` | Coordinate service çağır, `last_report` + `visit_count` güncelle |

Refresh akışı: spot bulunur → `get_coordinate_intelligence` → `last_report` snapshot (trim) saklanır → `visit_count++`.

### Faz 8c — Catch Intelligence (Av Kaydı + Spot Learning)

Kullanıcı yakaladığı balıkları spot ile ilişkilendirir. ML/AI tahmin yok; veri modeli + SQLite + learning summary.

| Endpoint | Açıklama |
|----------|----------|
| `POST /saved_spots/{id}/catch` | Av kaydı oluştur; spot `last_success_*` ve `spot_reputation` güncellenir |
| `GET /saved_spots/{id}/catches` | Spot av kayıtları + özet |
| `DELETE /catches/{id}` | Av kaydı sil |
| `GET /saved_spots/{id}/learning_summary` | catch_count, top_species, reputation, level |

Örnek istek:

```json
POST /api/v1/marine_intelligence/saved_spots/{spot_id}/catch
{
  "species": "Levrek",
  "length_cm": 53,
  "weight_kg": 2.1,
  "bait": "Silikon",
  "method": "Spin",
  "caught_at": "2026-07-03T06:42:00Z",
  "notes": "Sabah gün doğumuna yakın"
}
```

Catch oluşturulunca spot `last_report` varsa `weather/marine/decision/scenario/moon` snapshot alanları kaydedilir. `visit_count` catch sırasında artmaz.

`GET /health` → `catch_intelligence_enabled` (`MARINE_CATCH_STORAGE_ENABLED`).

Captain Atlas hook: `build_catch_context_for_spot(spot_id)` — saved spot refresh + `include_ai_comment=true` iken AI prompt'a bağlanır (Phase 8D).

### Faz 8d — Catch Intelligence Hardening

| Endpoint | Açıklama |
|----------|----------|
| `POST /saved_spots/learning_summaries` | Toplu learning summary (max 100 spot_id) |
| `PATCH /catches/{id}` | Av kaydı güncelle + reputation yeniden hesapla |
| `DELETE /catches/{id}` | Sil + `learning_summary` döner |
| `DELETE /saved_spots/{id}` | Spot sil + cascade catch delete (`deleted_catches`) |

Saved spot refresh + `include_ai_comment=true` → Captain Atlas catch context (olasılıksal dil).

`GET /health` → `bulk_learning_summary_enabled`.

### Faz 8e — Marine Compare Mode

| Endpoint | Açıklama |
|----------|----------|
| `POST /compare` | İki koordinat veya iki kayıtlı spot karşılaştırması |

Request: `left` / `right` (`lat`/`lon` veya `spot_id`, opsiyonel `label`), `include_ai_comment`, `force_refresh`.

Response: `left_report`, `right_report`, `comparison` (winner, score/risk/confidence delta, main_reasons, summary_tr), opsiyonel `captain_comment`, `updated_at`.

Compare engine (`compare_engine.py`): go_score farkı < 5 → tie; yüksek risk penalty; partial_data → belirsizlik nedeni.

Captain Atlas scope: `marine_compare` — `include_ai_comment=false` → AI çağrısı yok, `captain_comment` null.

`GET /health` → `marine_compare_enabled` (`MARINE_COMPARE_ENABLED`).

Flutter: `MarineCompareScreen`, kayıtlı noktalardan iki seçim + koordinat girişi, `fetchMarineCompare`.

`last_report` ham provider dump değil; coordinate yanıtının özeti (`weather`, `wind`, `marine`, `fishing_score`, `explainability`, vb.).

`GET /health` → `saved_spots_enabled`, `saved_spots_storage` (path/secret dönmez).

### Gelecek mimari modüller (Faz 7d+)

| Modül | Amaç |
|-------|------|
| **Decision Engine** | Tüm motor çıktılarını tek karar katmanında birleştirir (`fishing_decision`, `go_score`, `wait_score`); AI yalnızca yorumlar, hesaplamaz. |
| **Scenario Engine** | "Rüzgar 5 km/h artsa ne olur?" gibi what-if simülasyonları (future-ready model). |
| **Decision Timeline** | Saatlik karar akışı (`decision_timeline[]`: time, go_score, risk_score, decision, reason_tr). |

Placeholder dosyalar: `decision_engine.py`, `explainability_engine.py`, `scenario_engine.py`, `trend_engine.py`, `tide_engine.py`, `fish_activity_engine.py`, `marine_risk_engine.py`, `marine_index_engine.py`, `weather_stability.py`.

`GET /health` yanıtına geriye uyumlu `marine_intelligence` bloğu eklenir (`enabled`, `cache_ttl_minutes`, `providers_enabled`).

## Daha fazla bilgi

- Flutter uygulamasına özel notlar: `deniz_app/README.md`
- Yayın öncesi kontrol listesi: `docs/RELEASE_CHECKLIST.md`

---

## Release Candidate — yerel kurulum ve yayın

### Ortam dosyası (.env)

```bash
copy .env.example .env
```

**Önemli:** Gerçek API anahtarlarını yalnızca yerel `.env` dosyasına yazın. `.env.example` içine asla gerçek key koymayın — yalnızca boş veya placeholder değerler kullanın. `.env`, `.env.local` ve `.env.production` git tarafından izlenmez.

**Key rotation / `.env` değişikliği:** `OPENAI_API_KEY`, `OPENAI_MODEL` veya diğer AI değişkenlerini güncelledikten sonra backend sürecini yeniden başlatın (`uvicorn` durdurup tekrar çalıştırın). Docker kullanıyorsanız: `docker compose down` ardından `docker compose up --build`.

| Değişken | Açıklama |
|----------|----------|
| `OPENAI_API_KEY` | OpenAI (yalnızca backend sunucusunda) |
| `AI_ASSISTANT_ENABLED` | AI assistant aç/kapa |
| `WINDY_API_KEY` / `POSEIDON_API_KEY` | Opsiyonel deniz verisi sağlayıcıları |

### Backend başlatma

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Docker: `docker compose up --build` → port **8000**.

Sağlık: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

### Flutter başlatma

```bash
cd deniz_app
flutter pub get
flutter run -d windows
```

Telefon/emülatör için sunucu IP’sini uygulama içinden girin (localhost telefonda çalışmaz).

### Test komutları (Windows)

| Script | Açıklama |
|--------|----------|
| `scripts\check_secrets.py` | Repo içinde gizli key taraması |
| `scripts\check_release_config.py` | Release config sanity (pubspec, manifest, checklist) |
| `scripts\release_verify.bat` | Tam doğrulama; opsiyonel `windows` / `apk` / `all` build |
| `scripts\run_flutter_tests.bat` | `flutter analyze` + `flutter test` |
| `scripts\run_backend_tests.bat` | `pytest` |
| `scripts\run_all_tests.bat` | Secret + release config + backend + flutter |

Manuel:

```bash
python scripts/check_secrets.py
python scripts/check_release_config.py
pytest
cd deniz_app && flutter analyze && flutter test
scripts\release_verify.bat
scripts\release_verify.bat windows
```

### CI (GitHub Actions)

- **CI (`ci.yml`):** push/PR — secret scan, release config, pytest, flutter analyze/test
- **Release Build (`release-build.yml`):** tag `v*` / `*-rc*` (ör. `v1.0.0-rc1`) veya manual dispatch — APK + Windows build, artifact upload, `check_release_artifacts.py`
- Artifact adları: `MeraSonar-android-apk`, `MeraSonar-windows-release`, `MeraSonar-windows-release-zip`

### Git tag ile RC1 yayını

Yerel git repo yoksa **init/commit/tag/push yapmayın** — adımlar: `docs/GIT_RELEASE_TAG_PLAN.md`

Dağıtım paketi özeti: `docs/RC1_DISTRIBUTION_PACKAGE.md`

Onay sonrası özet:

```bash
git status
git add .
git commit -m "chore: prepare v1.0.0-rc1 release candidate"
git tag v1.0.0-rc1
git push origin main
git push origin v1.0.0-rc1
```

Tag push → GitHub Actions **Release Build** → APK + Windows artifact indir.

### Port 8000 (dev)

```powershell
powershell -File scripts/check_port_8000.ps1
scripts\start_backend_safe.bat
```

```bash
scripts\release_verify.bat qa
scripts\release_verify.bat windows
scripts\release_verify.bat apk
scripts\release_verify.bat all
python scripts\check_release_artifacts.py ^
  --apk deniz_app\build\app\outputs\flutter-apk\app-release.apk ^
  --windows-dir deniz_app\build\windows\x64\runner\Release ^
  --windows-zip deniz_app\MeraSonar-windows-release.zip
```

**Not (Windows yerel build):** Repo yolu Türkçe/non-ASCII karakter içeriyorsa (`Deniz uygulaması` gibi) Flutter MSBuild/Gradle `app.dill` okuyamaz. `release_verify.bat` otomatik `subst M:` kullanır; alternatif olarak projeyi ASCII-only bir yola klonlayın. CI (`windows-latest` / `ubuntu-latest`) etkilenmez.

### Crash reporting (RC Phase 2)

`deniz_app/lib/services/crash_reporter.dart` — `CrashReporter` soyutlaması. Debug’da `DebugLogCrashReporter` (sanitize log); release’de `NoopCrashReporter`. İleride Sentry veya Firebase Crashlytics bu arayüze bağlanabilir; production’da şu an dış servise gönderim yok.

### Release build

| Script | Çıktı |
|--------|-------|
| `scripts\build_windows_release.bat` | `deniz_app\build\windows\x64\runner\Release\` |
| `scripts\build_android_apk.bat` | `deniz_app\build\app\outputs\flutter-apk\app-release.apk` |

### Android izinleri

- **INTERNET** — API iletişimi
- **ACCESS_FINE/COARSE_LOCATION** — Canlı Alan ve harita konumu
- **Fotoğraf seçimi** — sistem Photo Picker (geniş depolama izni yok)

Konum ve veri kullanımı Play Console gizlilik formunda açıklanmalıdır.

### Known limitations

- Canlı skor ve Marine Intelligence backend bağlantısı gerektirir; offline modda son önbellek gösterilir.
- AI Assistant `OPENAI_API_KEY` olmadan devre dışı kalır.
- Image-space analiz GPS/kalibrasyon olmadan yalnızca görüntü piksellerinde çalışır.
- Compare / forecast tam zenginlik backend domain verisine bağlıdır.

### Disclaimer / güvenlik

MeraSonar balık tespiti yapmaz; olasılık temelli planlama aracıdır. Av başarısı garanti edilmez. Resmi deniz ve hava uyarılarını takip edin. Uygulama içi metinler tavsiye niteliğindedir.

### Store release yapılacaklar (özet)

1. `docs/RELEASE_CHECKLIST.md` tamamla
2. `check_secrets.py` + tüm testler yeşil
3. Windows/Android release build doğrula
4. Uygulama ikonu ve `version: 1.0.0+1` (pubspec) / mağaza sürümü
5. Gizlilik politikası + konum/fotoğraf açıklamaları
6. Play/App Store imzalama anahtarları (CI dışında güvenli saklama)
