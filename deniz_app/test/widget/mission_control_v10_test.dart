import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_command_header.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_score_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MissionCommandHeader empty mission', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionCommandHeader(
            overview: DashboardOverview.empty,
            onRefresh: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMissionControlTitle), findsOneWidget);
    expect(find.text(kMissionNoActiveMission), findsOneWidget);
  });

  testWidgets('MissionScoreCard empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionScoreCard(
            report: const DashboardMarineReportSummary(),
            onMarineTap: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMissionScoreEmpty), findsOneWidget);
  });

  testWidgets('MissionQuickActionDock render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionQuickActionDock(
            onMapTap: () {},
            onMarineTap: () {},
            onLiveTap: () {},
            onCompareTap: () {},
            onCaptainTap: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMissionDockMap), findsOneWidget);
    expect(find.text(kMissionDockCompare), findsOneWidget);
  });
}
