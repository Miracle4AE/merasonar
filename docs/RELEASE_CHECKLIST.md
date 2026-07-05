# MeraSonar — Release Checklist (RC Phase 2)

Yayın öncesi bu listeyi sırayla tamamlayın. Otomasyon: `scripts/` + GitHub Actions `ci.yml`.

## 1. Secret scan

- [ ] `python scripts/check_secrets.py` — exit code 0
- [ ] `python scripts/check_release_config.py` — exit code 0
- [ ] `python scripts/check_release_artifacts.py` — build sonrası (CI veya yerel)

## 2. Automated tests (CI gates)

- [ ] GitHub **CI** workflow yeşil (push/PR)
- [ ] GitHub **Release Build** workflow yeşil (tag veya manual dispatch)
- [ ] `scripts\release_verify.bat qa`
- [ ] Detaylı manuel matris: `docs/MANUAL_QA_MATRIX.md`

## 3. Build artifacts

- [ ] `scripts\build_windows_release.bat` (analyze + test + build)
- [ ] `scripts\build_android_apk.bat` (analyze + test + build)
- [ ] Windows çıktı: `deniz_app\build\windows\x64\runner\Release\`
- [ ] APK çıktı: `deniz_app\build\app\outputs\flutter-apk\app-release.apk`

---

## 4. Windows manual QA

- [ ] İlk açılış — splash → onboarding/home, crash yok
- [ ] Dashboard V2 — boş/dolu state, bağlantı rozeti
- [ ] Backend offline — “Bağlantı yok”, önbellek banner
- [ ] Map / fotoğraf analizi — chart yükle, analiz, hotspot panel
- [ ] Marine Intelligence — koordinat analizi
- [ ] Captain Atlas komuta merkezi + AI sheet
- [ ] Compare — iki nokta, winner kartı
- [ ] Live Area — mock/canlı skor bölümü
- [ ] Battery saver mod — animasyon/blur azaltılmış
- [ ] Reduce motion — geçişler sadeleşmiş
- [ ] Desktop: quick dock yok; mobil: dock var
- [ ] “Mission Control” metni yok

## 5. Android manual QA

- [ ] APK kurulumu ve açılış
- [ ] Sunucu IP girişi (localhost yerine LAN IP)
- [ ] Portrait kilidi / UI taşması yok
- [ ] Geri tuşu — sheet/dialog kapanışı
- [ ] Battery saver / arka plan — crash yok (temel smoke)

## 6. GPS permissions

- [ ] İlk Live Area açılışında izin isteği
- [ ] Reddedilince açıklayıcı mesaj + ayarlara yönlendirme
- [ ] Konum kapalıyken crash yok

## 7. Photo picker

- [ ] Harita analizi — galeriden görsel seçimi
- [ ] Broad storage izni gerektirmiyor (Photo Picker)
- [ ] İptal / hata durumunda crash yok

## 8. Backend offline

- [ ] Dashboard — son kayıtlı veri / bağlantı yok
- [ ] Map — cached analiz görünümü
- [ ] Marine — offline banner
- [ ] AI — cache-only veya devre dışı mesajı

## 9. AI disabled vs enabled

- [ ] `AI_ASSISTANT_ENABLED=false` — fallback metin, crash yok
- [ ] Key yok — Captain yorumu fallback
- [ ] Key + enabled — sheet yüklenir (staging ortamında)

## 10. Marine coordinate analysis

- [ ] Koordinat gir → rapor kartları
- [ ] Partial data / timeout mesajları
- [ ] Kayıtlı nokta olarak ekleme

## 11. Saved spots — CRUD

- [ ] Oluştur / favori / yenile
- [ ] Sil — onay + liste güncelleme
- [ ] Compare modunda iki seçim

## 12. Catch — CRUD

- [ ] Av ekle dialog — kaydet
- [ ] Liste — düzenle / sil
- [ ] Hata durumunda fallback (ErrorBoundary)

## 13. Compare mode

- [ ] İki koordinat veya iki kayıtlı spot
- [ ] Winner / tie / captain comment (varsa)
- [ ] AI comment kapalı — captain null

## 14. Map / photo analysis

- [ ] Image-space analiz (kontrol noktası yok)
- [ ] Geo kalibrasyon (3+ nokta)
- [ ] Hotspot detay paneli — ErrorBoundary fallback

## 15. Performance / accessibility smoke

- [ ] Dashboard ilk paint kabul edilebilir
- [ ] Sidebar semantics (screen reader)
- [ ] Quick dock / Captain butonları label’lı

## 16. Store privacy checklist

- [ ] Konum, fotoğraf, ağ kullanımı açıklandı
- [ ] OpenAI / hava-deniz API veri akışı
- [ ] Çocuk / hassas veri toplanmıyor
- [ ] HTTPS production tercihi

## 17. Legal disclaimer

- [ ] Tavsiye niteliğinde — av garantisi yok
- [ ] Resmi deniz uyarıları hatırlatması
- [ ] Uygulama içi güvenlik metinleri görünür

---

## 18. Backend port 8000 (dev ergonomics)

WinError 10048 (`port already in use`) — release blocker değil; yerel QA için:

```powershell
powershell -File scripts\check_port_8000.ps1
```

Port boşsa güvenli başlatma:

```bat
scripts\start_backend_safe.bat
```

Doluysa script PID ve süreç adını gösterir; eski uvicorn örneğini kapatın veya mevcut backend'i kullanın.

---

**Versiyon:** pubspec `1.0.0+1` · AppConfig `1.0.0`  
**Son güncelleme:** RC Phase 7

**İlgili dokümanlar:** `MANUAL_QA_MATRIX.md` · `PRIVACY_AND_STORE_CHECKLIST.md` · `VISUAL_QA_GUIDE.md` · `releases/v1.0.0-rc1.md`
