import 'package:deniz_app/l10n/app_strings_tr.dart';

/// Offline / önbellek metinleri — tutarlı kullanıcı mesajları.
abstract final class PremiumOfflineCopy {
  static String connectionBanner({required bool offline}) {
    if (offline) return kPremiumNoConnection;
    return '';
  }

  static String cacheBanner({required bool cacheHit, bool offline = false}) {
    if (offline) return kPremiumLastSavedData;
    if (cacheHit) return kPremiumCacheFromLocal;
    return '';
  }

  static String emptyData() => kPremiumNoDataLabel;

  static String offlineReassurance() => kOfflineStateReassurance;
}
