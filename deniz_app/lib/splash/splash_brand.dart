import '../config/app_config.dart';

/// Splash sloganı — ürün adı için [AppConfig.productName].
abstract final class SplashBrand {
  static const String slogan = 'Akıllı balıkçılık analiz asistanı';

  static String get appName => AppConfig.productName;
}
