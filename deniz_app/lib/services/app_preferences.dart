import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static const String keyOnboardingV1 = 'onboarding_v1_done';
  static const String _kTrustBarMinimized = 'trust_bar_minimized_v1';
  /// Sunucu sihirbazı (Sunucu bulunamadı) bir daha gösterilmesin kullanıcı onayıyla.
  static const String _kServerWizardDeferred = 'server_wizard_user_deferred_v1';
  /// İlk başarılı /health kutlaması ve Fotoğraf analizi odak kutusu.
  static const String _kFirstConnectionCelebrated = 'first_connection_celebrated_v1';
  static const String _kPhotoGuideHighlightPending = 'photo_guide_highlight_pending_v1';

  static Future<bool> isOnboardingComplete() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(keyOnboardingV1) ?? false;
  }

  static Future<void> setOnboardingComplete() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(keyOnboardingV1, true);
  }

  static Future<bool> isTrustBarMinimized() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kTrustBarMinimized) ?? false;
  }

  static Future<void> setTrustBarMinimized(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kTrustBarMinimized, value);
  }

  /// Kullanıcı "Daha sonra" dediyse ana ekran sihirbazını gösterme.
  static Future<bool> isServerWizardDeferredByUser() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kServerWizardDeferred) ?? false;
  }

  static Future<void> setServerWizardDeferredByUser(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kServerWizardDeferred, value);
  }

  static Future<bool> hasCelebratedFirstConnection() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kFirstConnectionCelebrated) ?? false;
  }

  static Future<void> markFirstConnectionCelebrated() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kFirstConnectionCelebrated, true);
  }

  /// Fotoğraf analizi kartında vurgu — kullanıcı karta bastığında veya buradan temizlenir.
  static Future<bool> isPhotoGuideHighlightPending() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPhotoGuideHighlightPending) ?? false;
  }

  static Future<void> setPhotoGuideHighlightPending(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPhotoGuideHighlightPending, value);
  }

  /// Bağlantı kurulunca sihirbazı gereksiz tutmak için sıfırlanabilir.
  static Future<void> clearDeferredWizardWhenConnected() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kServerWizardDeferred, false);
  }

  /// Geliştirme/test — gerçek ödeme yok; backend premium kotası simülasyonu.
  static const String _kAiPremiumDev = 'ai_premium_dev_v1';

  static Future<bool> getIsPremiumDev() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAiPremiumDev) ?? false;
  }

  static Future<void> setIsPremiumDev(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAiPremiumDev, value);
  }

  static const String _kPerformanceMode = 'premium_performance_mode_v1';

  static Future<PremiumPerformanceMode> getPerformanceMode() async {
    final p = await SharedPreferences.getInstance();
    return PremiumPerformanceModeStorage.fromStorage(p.getString(_kPerformanceMode));
  }

  static Future<void> setPerformanceMode(PremiumPerformanceMode mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPerformanceMode, mode.storageKey);
  }
}
