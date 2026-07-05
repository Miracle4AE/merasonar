# MeraSonar — Android’e APK kurulumu

Bu belge, **release APK**’yı telefona kurmak ve aynı Wi‑Fi üzerindeki **PC’de çalışan backend**’e bağlanmak içindir.

## 1) APK’yı telefona alma

1. Geliştirme makinesinde `flutter build apk --release` çalıştırıldıktan sonra APK yolu:
   - `build/app/outputs/flutter-apk/app-release.apk`
2. Dosyayı USB ile kopyalayın, bulut sürücü ile paylaşın veya `adb install app-release.apk` kullanın.

### Bilinmeyen kaynaklar

Android genelde “bilinmeyen kaynaklar”dan yükleme gerektirir:

- **Ayarlar → Güvenlik** veya **Uygulama yükleme özel izni** menüsünden, kullandığınız dosya tarayıcısı / APK seçici için izin verin.
- İzin akışı OEM’e göre değişir; yükleme sırasında çıkan uyarıda “yine de yükle” benzeri seçeneği onaylayın.

## 2) PC’de backend’i açma

MeraSonar istemcisi, yerel ağdaki sunucuya HTTP ile bağlanır (varsayılan port **8000**).

1. Backend’i geliştirdiğiniz makinede sunucuyu çalıştırın (projede kullandığınız komut ne ise — örn. `uvicorn`, `python main.py`, Docker vb.).
2. Sunucunun **0.0.0.0:8000** (tüm arayüzler) veya en azından LAN IP’si üzerinden dinlediğinden emin olun; yalnız `127.0.0.1`’e bağlıysa telefondan erişilemez.

## 3) PC’nin yerel IP adresini bulma

- **Windows (PowerShell):** `ipconfig` → “Kablosuz LAN bağdaştırıcı Wi‑Fi” veya “Ethernet” altındaki **IPv4 Adresi** (ör. `192.168.1.42`).
- Telefon ve PC **aynı Wi‑Fi ağında** olmalı; misafir ağ / AP izolasyonu açıksa cihazlar birbirini göremez.

## 4) Uygulamada sunucu IP’si

1. MeraSonar’da **sunucu / backend rozetine** veya IP giriş ekranına gidin.
2. `127.0.0.1` veya `localhost` **telefonda geçerli değildir**; **PC’nin IPv4 adresini** yazın, örn. `192.168.1.42` (ve uygulama portu 8000 ise genelde `192.168.1.42:8000` veya uyarlanmış adres biçimi).

## 5) Güvenlik duvarı (Windows)

İlk bağlantıda Windows Güvenlik Duvarı istemi çıkabilir; Python / sunucu sürecine **özel ağ** için izin verin.

- İzin vermezseniz telefon bağlantısı zaman aşımına düşer.
- Port **8000** TCP’nin engellenmediğinden emin olun.

## 6) HTTP (cleartext) ve LAN

Projede LAN üzerinden **HTTP** kullanımına izin veren `network_security_config` bulunur (HTTPS’li üretim önerilir). Telefon ile PC aynı güvenilir LAN’da olmalıdır.

---

## Sorun giderme

| Sorun | Olası neden |
|--------|----------------|
| Sürekli çevrimdışı / bağlanamıyor | Farklı Wi‑Fi, AP izolasyonu, yanlış IP, backend kapalı, firewall |
| Sadece localhost çalışıyor | Sunucu yalnız loopback’te dinliyor |
| Yüklenemiyor | Bilinmeyen kaynak izni verilmedi |
