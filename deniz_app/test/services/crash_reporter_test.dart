import 'package:deniz_app/services/crash_reporter.dart';
import 'package:deniz_app/utils/log_sanitize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoopCrashReporter does not throw', () {
    const reporter = NoopCrashReporter();
    reporter.recordError(Exception('x'), StackTrace.current);
    reporter.recordFlutterError(
      FlutterErrorDetails(exception: Exception('y')),
    );
    reporter.setUserId('user-123');
    reporter.setContext('session', {'a': 1});
  });

  test('DebugLogCrashReporter sanitizes user id', () {
    final reporter = DebugLogCrashReporter();
    reporter.setUserId('abcdefghijklmnop');
    expect(reporter.debugUserId, isNot(contains('abcdefghijklmnop')));
    expect(reporter.debugUserId, contains('…'));
  });

  test('sanitizeLogMessage redacts OpenAI keys', () {
    final token = List.filled(24, 'a').join();
    final raw = 'OPENAI_API_KEY=sk-proj-$token';
    final out = sanitizeLogMessage(raw);
    expect(out, isNot(contains(token)));
    expect(out, anyOf(contains('[redacted]'), contains('[openai-key-redacted]')));
  });

  test('installCrashReporting sets instance', () {
    installCrashReporting(reporter: NoopCrashReporter());
    expect(CrashReporter.instance, isA<NoopCrashReporter>());
  });

  test('maskApiKey truncates long values', () {
    expect(maskApiKey('short'), '[redacted]');
    expect(maskApiKey('1234567890'), contains('…'));
  });
}
