/// Ürün adı, API uç noktası ve yasal/feragat metinleri — tek merkez (bakım).
class AppConfig {
  AppConfig._();

  /// Görünen ürün adı (splash, onboarding, masaüstü başlığı, Android label ile uyumlu).
  static const String productName = 'MeraSonar';
  static const String productShortName = 'MeraSonar';

  /// Analiz API’si (FastAPI) varsayılan portu; `buildApiBaseUrl` ile birleşir.
  static const int defaultApiPort = 8000;

  /// API ortamı: release/mobil varsayılanı production, yerel geliştirme için:
  /// `--dart-define=MERASONAR_ENV=development`.
  static const String apiEnvironment = String.fromEnvironment(
    'MERASONAR_ENV',
    defaultValue: 'production',
  );

  static bool get isDevelopmentEnvironment {
    final env = apiEnvironment.trim().toLowerCase();
    return env == 'dev' || env == 'development' || env == 'local';
  }

  /// Fiziksel telefon ve production build varsayılan canlı backend adresi.
  static const String productionApiHost = '187.124.183.138';
  static const String productionApiBaseUrl =
      'http://$productionApiHost:$defaultApiPort';

  /// Yerel geliştirme adresleri. API adresleri burada merkezi tutulur.
  static const String developmentApiHost = loopbackIpv4Host;
  static const String loopbackIpv4Host = '127.0.0.1';
  static const String loopbackHostname = 'localhost';
  static const String loopbackIpv6Host = '::1';

  /// Uygulama sürümü — pubspec `version` ile senkron tutulmalı.
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  /// Örnek LAN adresi — gerçek cihazda bilgisayar IP’sini takip eden metinlerde kullanılır.
  static const String defaultLanHostExample = '192.168.1.20';

  /// Android emülatör → geliştirme makinesi (host) köprüsü.
  static const String defaultEmulatorLanHost = '10.0.2.2';

  static String get defaultApiHost =>
      isDevelopmentEnvironment ? developmentApiHost : productionApiHost;

  static String get defaultApiBaseUrl => buildApiBaseUrl(defaultApiHost);

  /// Kullanıcı girdisi / kayıtlı değerlerden host normalize eder.
  ///
  /// Kabul edilen örnekler:
  /// - `127.0.0.1` → `127.0.0.1`
  /// - `localhost:8000` → `localhost`
  /// - `http://127.0.0.1:8000/` → `127.0.0.1`
  static String normalizeHost(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    // Şema ile gelirse (http/https), host kısmını al.
    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      if (uri != null && uri.host.trim().isNotEmpty) {
        return uri.host.trim();
      }
    }

    // Slash ile gelmişse (örn: localhost:8000/health), ilk parçayı al.
    final slash = s.indexOf('/');
    if (slash >= 0) {
      s = s.substring(0, slash);
    }

    // Basit host:port formunda portu kırp.
    // (IPv6 gibi köşeli parantezli formları bu uygulama şu an hedeflemiyor.)
    final colon = s.indexOf(':');
    if (colon > 0) {
      s = s.substring(0, colon);
    }

    return s.trim();
  }

  static String buildApiBaseUrl(String host, {int? port}) {
    final normalized = normalizeHost(host);
    final h = normalized.isEmpty ? defaultApiHost : normalized;
    final p = port ?? defaultApiPort;
    return 'http://$h:$p';
  }

  static bool isLoopbackHost(String host) {
    final h = normalizeHost(host).toLowerCase();
    return h == loopbackHostname || h == loopbackIpv4Host || h == loopbackIpv6Host;
  }

  static bool isLocalDevelopmentHost(String host) {
    final h = normalizeHost(host).toLowerCase();
    return isLoopbackHost(h) || h == defaultEmulatorLanHost;
  }

  static int normalizePort(int? port) {
    if (port == null || port < 1 || port > 65535) {
      return defaultApiPort;
    }
    return port;
  }

  /// Ağ / sunucu hatalarında ikinci satır (LAN kurulumları). Ayrıca [kMsgNetworkRetryHint] ile uyumlu.
  static const String networkRetryHint =
      'Aynı Wi‑Fi üzerinden bağlandığınızdan emin olun; sunucu adresini Ayarlar’dan güncelleyebilirsiniz.';

  /// AppBar / kısa başlık.
  static String mapTitleForHost(String host) {
    final h = normalizeHost(host);
    return '$productName (${h.isEmpty ? defaultApiHost : h}:$defaultApiPort)';
  }

  /// Kalıcı güven bandı — tek satır.
  static const String trustShortLine =
      'Sonuçlar tavsiye niteliğindedir. Resmi deniz bilgisi, hava ve güvenli seyir ile çeliştiğinde her zaman o kaynaklara ve yerel yönetmeliklere uyun.';

  /// "Detay" / tam metin.
  static const String trustFullText =
      '''
$productName, harita/ekran görüntüleri, isteğe bağlı kontrol noktaları, model ve üçüncü taraf hava-çevre veri kaynaklarını bir araya getirerek mera noktaları üretir. Kontrol noktası verilmezse analiz yalnızca fotoğraf üzerindeki görsel yapıya göre yapılır. Bu sonuçlar yalnızca planlama ve fikir edinmek içindir.

• Nihai seyir, balıkçılık ve güvenlik kararlarınızı yalnızca bu uygulamaya dayanarak vermeyin.
• Resmi deniz haritaları, NOTAM, şamandıra ve kıyı emniyet bilgileri sizin asıl referansınızdır.
• Hava ve deniz modelleri; konum, hizalama ve görüntü kalitesine bağlı hatalar içerebilir.
• Üreticiler, geliştiriciler ve veri sağlayıcılar, bu uygulamanın neden olabileceği dolaylı zararlardan sorumlu tutulamaz (yürürlükteki mevzuatın izin verdiği ölçüde).

Kullanmaya devam ederek bu çerçeveyi anladığınız kabul edilir.''';
}
