import 'package:deniz_app/utils/log_sanitize.dart';
import 'package:flutter/foundation.dart';

/// Crash / hata raporlama soyutlaması — ileride Sentry veya Firebase bağlanabilir.
abstract class CrashReporter {
  static CrashReporter instance = NoopCrashReporter();

  void recordError(Object error, StackTrace stack, {String? reason});

  void recordFlutterError(FlutterErrorDetails details);

  void setUserId(String? id);

  void setContext(String key, Map<String, Object?> value);
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();
  @override
  void recordError(Object error, StackTrace stack, {String? reason}) {}

  @override
  void recordFlutterError(FlutterErrorDetails details) {}

  @override
  void setUserId(String? id) {}

  @override
  void setContext(String key, Map<String, Object?> value) {}
}

/// Yalnızca debug modda — secret/PII sanitize edilir, dış servise gönderilmez.
class DebugLogCrashReporter implements CrashReporter {
  String? _userId;
  final Map<String, Map<String, Object?>> _context = {};

  @override
  void recordError(Object error, StackTrace stack, {String? reason}) {
    if (!kDebugMode) return;
    final msg = sanitizeLogMessage(
      reason == null ? error.toString() : '$reason: $error',
    );
    debugPrint('[CrashReporter] $msg');
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    if (!kDebugMode) return;
    final msg = sanitizeLogMessage(details.exceptionAsString());
    debugPrint('[CrashReporter][FlutterError] $msg');
  }

  @override
  void setUserId(String? id) {
    _userId = id == null ? null : maskApiKey(id);
  }

  @override
  void setContext(String key, Map<String, Object?> value) {
    _context[key] = value;
  }

  @visibleForTesting
  String? get debugUserId => _userId;

  @visibleForTesting
  Map<String, Map<String, Object?>> get debugContext => _context;
}

/// Uygulama başlangıcında çağırın. Release'de noop; debug'da sanitize log.
void installCrashReporting({CrashReporter? reporter}) {
  final active = reporter ??
      (kDebugMode ? DebugLogCrashReporter() : NoopCrashReporter());
  CrashReporter.instance = active;

  final priorFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    active.recordFlutterError(details);
    if (priorFlutterHandler != null) {
      priorFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    active.recordError(error, stack, reason: 'platform');
    return true;
  };
}
