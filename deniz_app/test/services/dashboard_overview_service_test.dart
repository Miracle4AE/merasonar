import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mapHealthStatus maps connection states', () {
    expect(
      DashboardOverviewService.mapHealthStatus(
        healthOk: true,
        healthChecking: false,
      ),
      DashboardConnectionStatus.connected,
    );
    expect(
      DashboardOverviewService.mapHealthStatus(
        healthOk: false,
        healthChecking: false,
      ),
      DashboardConnectionStatus.disconnected,
    );
    expect(
      DashboardOverviewService.mapHealthStatus(
        healthOk: null,
        healthChecking: true,
      ),
      DashboardConnectionStatus.checking,
    );
  });

  test('load returns empty overview without cache', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = DashboardOverviewService();
    final overview = await svc.load(
      connectionStatus: DashboardConnectionStatus.unknown,
    );
    expect(overview.liveScore.hasData, isFalse);
    expect(overview.savedSpots.hasData, isFalse);
    expect(overview.compare.hasData, isFalse);
    expect(overview.captainAtlas.hasData, isFalse);
    expect(overview.mapPreview.hasData, isFalse);
  });

  test('formatRelativeTime handles recent timestamps', () {
    final now = DateTime.now().toUtc().toIso8601String();
    expect(
      DashboardOverviewService.formatRelativeTime(now),
      isNotEmpty,
    );
  });
}
