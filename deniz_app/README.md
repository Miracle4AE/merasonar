# deniz_app (Flutter) — MeraSonar

**MeraSonar** arayüzü: fotoğraf/chart overlay üzerinde hotspot’lar, kontrol noktaları, analiz geçmişi.

## Çalıştırma

```bash
cd deniz_app
flutter pub get
flutter run
```

Arka uç (köke dön): `uvicorn` veya `docker compose` — bkz. üst dizindeki `README.md`.

**GPX dışa aktarma:** Üst çubuktaki indirme simgesi filtrelerle görünen tüm noktaları; **mera detayı** panelindeki **“Bu noktayı GPX olarak paylaş”** yalnızca o noktayı **GPX 1.1** dosyası olarak paylaşır.

**Analiz geçmişi:** Favoriler ayrı bölüm; satırlarda chart küçük önizleme (dosya hâlâ mevcutsa) ve sınıf özeti. Eski veya silinmiş dosyada rozet. **Kalibrasyon profilleri** (üst çubuk, ayar simgesi): kontrol noktalarını ad vererek kaydedin, aynı çözünürlükte tekrar yükleyin.

**Güven / feragat:** Altta her zaman tavsiye bandı; «Tam metin» ile ayrıntılı metin. İlk açılışta kısa tanıtım, sunucu IP ve onay adımları.

Uygulama adı, API portu ve feragat metinleri: `lib/config/app_config.dart`.

**Fotoğraf modu:** `Alanı Tara` cihaz GPS’i istemeden fotoğraf seçtirir. En az 3 kontrol noktası girerseniz sonuçlar gerçek harita koordinatlarına oturur; atlayınca analiz yalnızca fotoğraf üzerindeki yapıya göre yapılır ve dış deniz verisi zenginleştirmesi kullanılmaz.

**Önemli:** Telefondan test ederken arka uç PC’deyse, uygulamadaki sunucu adresine bilgisayarın **yerel ağ IP**’sini verin; `localhost` yalnızca uygulama ve API aynı cihazdayken uygundur.

## Geliştirme

- Statik analiz: `flutter analyze`
- Testler: `flutter test` (kökteki `README.md` içinde anlatılan CI aynı adımları PR’larda da çalıştırır). İsteğe bağlı splash süresi (ms): `flutter test --dart-define=MERASONAR_SPLASH_MS=50` — birim testlerinde `DenizApp(splashDuration: Duration(milliseconds: 1))` ile de kısaltılır.
