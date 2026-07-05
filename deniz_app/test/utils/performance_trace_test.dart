import 'package:deniz_app/utils/performance_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measureAsync completes in debug', () async {
    final result = await PerformanceTrace.measureAsync('test_trace', () async {
      return 42;
    });
    expect(result, 42);
  });

  test('startTrace and endTrace do not throw', () {
    PerformanceTrace.startTrace('manual');
    PerformanceTrace.endTrace();
  });
}
