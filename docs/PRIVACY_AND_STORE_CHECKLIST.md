# MeraSonar — Privacy & Store Checklist

> Bu belge yasal metin değildir. Play Console / Microsoft Store formlarını doldururken kontrol listesi olarak kullanın.

## Toplanan veriler

| Veri | Toplandı mı? | Amaç | Kullanıcı kontrolü |
|------|--------------|------|---------------------|
| Konum (GPS) | Evet (izinle) | Canlı Alan, harita, mesafe | İzin reddedilebilir |
| Harita / fotoğraf görüntüsü | Evet (kullanıcı seçimi) | Balıkçılık bölgesi analizi | Galeri/kamera seçimi |
| Kayıtlı spotlar | Evet | Marine Intelligence | Silme / düzenleme |
| Av kayıtları | Evet | Catch intelligence | Silme / düzenleme |
| Cihaz kimliği (client id) | Evet (anonim UUID) | AI kota / oturum | Yerel üretim |
| AI istek içeriği | Koşullu | Captain Atlas yorumu | AI kapalıysa gönderilmez |

## Nerede saklanıyor?

| Veri | Yer |
|------|-----|
| Dashboard / marine cache | Flutter local (SharedPreferences / cache) |
| Kayıtlı spot + av | Backend SQLite (`MARINE_SPOT_STORAGE_PATH`) |
| Analiz geçmişi | Yerel storage + opsiyonel `run_logs` (dev) |
| AI istekleri | OpenAI API (backend üzerinden) — key istemcide değil |

## Kullanıcıya gösterilecek uyarılar

- [ ] Tavsiye niteliğinde — av garantisi yok (`kTrustAlways`, Live Area güvenlik kartları)
- [ ] Resmi deniz haritası / navigasyon cihazı yerine geçmez
- [ ] GPS ve kalibrasyon sonuçları etkiler
- [ ] Resmi deniz uyarılarını takip edin

## OpenAI / üçüncü taraf API

- [ ] OpenAI: yalnızca backend; istemci key taşımaz
- [ ] Open-Meteo / yerel astronomi: koordinat gönderilir (marine intelligence)
- [ ] Gizlilik politikasında üçüncü taraf listesi

## API key güvenliği

- [ ] `OPENAI_API_KEY` yalnızca sunucu `.env`
- [ ] `.env.example` placeholder
- [ ] CI artifact’lerinde `.env` yok
- [ ] `check_secrets.py` CI’da zorunlu

## Silme / temizleme

- [ ] Kayıtlı spot silme → cascade catch delete (backend)
- [ ] Yerel cache: uygulama verisi temizleme / reinstall
- [ ] Backend `run_logs` production’da minimal

## Store form alanları (özet)

| Platform | Doldurulacak |
|----------|--------------|
| Google Play | Data safety form — Location, Photos (user-selected), App activity |
| Microsoft Store | Privacy policy URL, capabilities (internet, location) |

---

**Son güncelleme:** RC Phase 3
