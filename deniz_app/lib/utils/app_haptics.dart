import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// Ana etkileşimler için titreşim — desteklenmeyen platformlarda Flutter no-op.
///
/// Üretim güvenliği: hızlı art arda çağrılarda **istifleme yok**; kanal başına
/// minimum aralık (spam / çift tetik / kısa döngüler).
abstract final class AppHaptics {
  AppHaptics._();

  static DateTime? _lastLight;
  static DateTime? _lastMedium;
  static DateTime? _lastWarning;

  static const _lightMinMs = 140;
  static const _mediumMinMs = 200;
  static const _warningMinMs = 220;

  static bool _allow(DateTime? last, int minMs) {
    final now = DateTime.now();
    if (last != null && now.difference(last).inMilliseconds < minMs) {
      return false;
    }
    return true;
  }

  /// Mod düğmeleri (Home Live / Photo). Hızlı çift dokunuşta tek titreşim.
  static void lightTap() {
    if (!_allow(_lastLight, _lightMinMs)) return;
    _lastLight = DateTime.now();
    HapticFeedback.lightImpact();
  }

  /// Analiz / canlı skor tamamlandı (orta).
  static void analysisComplete() {
    if (!_allow(_lastMedium, _mediumMinMs)) return;
    _lastMedium = DateTime.now();
    HapticFeedback.mediumImpact();
  }

  /// Sunucu / izin / API hataları. Art arda hata patlamasında tek uyarı hissi.
  static void warning() {
    if (!_allow(_lastWarning, _warningMinMs)) return;
    _lastWarning = DateTime.now();
    HapticFeedback.selectionClick();
  }

  /// Test veya özel senaryolarda sayaçları sıfırlamak için (normal akışta kullanılmaz).
  @visibleForTesting
  static void resetDebounceTimersForTest() {
    _lastLight = null;
    _lastMedium = null;
    _lastWarning = null;
  }
}
