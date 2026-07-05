import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug performans ölçümü — release'de no-op.
class PerformanceTrace {
  PerformanceTrace._(this.name) {
    if (kReleaseMode) return;
    developer.Timeline.startSync(name);
    _started = DateTime.now();
  }

  final String name;
  DateTime? _started;

  static PerformanceTrace? _current;

  static void startTrace(String name) {
    if (kReleaseMode) return;
    endTrace();
    _current = PerformanceTrace._(name);
  }

  static void endTrace() {
    if (kReleaseMode) return;
    _current?._finish();
    _current = null;
  }

  void _finish() {
    if (kReleaseMode || _started == null) return;
    developer.Timeline.finishSync();
    final ms = DateTime.now().difference(_started!).inMilliseconds;
    debugPrint('[PerfTrace] $name ${ms}ms');
    _started = null;
  }

  static Future<T> measureAsync<T>(
    String name,
    Future<T> Function() fn,
  ) async {
    if (kReleaseMode) return fn();
    startTrace(name);
    try {
      return await fn();
    } finally {
      endTrace();
    }
  }
}
