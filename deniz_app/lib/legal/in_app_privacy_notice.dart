import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';

/// Kısa, uygulama içi gizlilik özeti (kart / diyalog).
class InAppPrivacyNotice {
  InAppPrivacyNotice._();

  static const String dialogTitle = kPrivacyDialogTitle;

  /// Port ve ürün adı sabit dizilerde güvenle kullanılır.
  static String bodyTextBlock() =>
      '${AppConfig.productName}: Fotoğraf analizinde seçtiğiniz harita görselleri, '
      'yapılandırdığınız adres üzerinden ağ ile sunucunuza gönderilir '
      '(tipik olarak yerel ağda '
      'http://${AppConfig.defaultLanHostExample}:${AppConfig.defaultApiPort} — '
      'HTTPS siz özellikle eklemezseniz HTTPS değildir).\n\n'
      'Konum yalnızca Canlı Alan’da kullanılır: GPS koordinatlarınız, önbellekteki analizdeki '
      'hotspot verileriyle birlikte sunucunuza gider; olasılık temelli skor üretilir — '
      'balığı otomatik tespit iddiası yoktur.\n\n'
      '$kUxFishDetectNoDetect\n\n'
      'Canlı özellikleri konum iznini kapatıp veya Fotoğraf analizinde sunucu adresini '
      'değiştirerek sınırlayabilir veya kapatabilirsiniz.';
}
