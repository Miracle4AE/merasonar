import 'dart:io';
import 'dart:ui' as ui;

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Export dashboard map preview redesign screenshot.
/// Run: flutter test test/widget/dashboard_map_preview_redesign_test.dart --dart-define=DASH_MAP_QA_OUT=...
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export dashboard-map-preview-reference-redesign.png', (tester) async {
    const outEnv = String.fromEnvironment('DASH_MAP_QA_OUT');
    final outDir = outEnv.isNotEmpty
        ? Directory(outEnv)
        : Directory(p.join(Directory.current.path, '..', 'docs', 'screenshots', 'rc1'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    const data = DashboardMapPreviewData(
      centerLat: 37.395,
      centerLon: 27.195,
      centerLabel: '37.3950, 27.1950',
      score: 78,
      updatedAgoLabel: '3 dk',
      hasRealCoordinate: true,
      displayMode: DashboardMapPreviewMode.activeReport,
      selectedMarkerId: 'h3',
      dataSourceLabel: kPremiumDashMapSourceReport,
      depthLegendMinLabel: kPremiumDashMapDepthMin,
      depthLegendMaxLabel: kPremiumDashMapDepthMax,
      waveLabel: '0.6 m',
      currentLabel: '0.28 m/s',
      markers: [
        DashboardMapMarker(
          normalizedX: 0.28,
          normalizedY: 0.62,
          id: 'h1',
          lat: 37.392,
          lon: 27.188,
          score: 48,
          isSelected: false,
          markerType: DashboardMapMarkerType.hotspot,
        ),
        DashboardMapMarker(
          normalizedX: 0.52,
          normalizedY: 0.48,
          id: 'h3',
          lat: 37.395,
          lon: 27.195,
          score: 78,
          isSelected: true,
          isPrimary: true,
          markerType: DashboardMapMarkerType.hotspot,
        ),
        DashboardMapMarker(
          normalizedX: 0.72,
          normalizedY: 0.35,
          id: 'h2',
          lat: 37.398,
          lon: 27.202,
          score: 63,
          markerType: DashboardMapMarkerType.hotspot,
        ),
        DashboardMapMarker(
          normalizedX: 0.38,
          normalizedY: 0.28,
          id: 'h4',
          lat: 37.401,
          lon: 27.191,
          score: 36,
          markerType: DashboardMapMarkerType.hotspot,
        ),
        DashboardMapMarker(
          normalizedX: 0.68,
          normalizedY: 0.68,
          id: 'h5',
          lat: 37.389,
          lon: 27.208,
          score: 91,
          markerType: DashboardMapMarkerType.hotspot,
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(520, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              height: 280,
              child: RepaintBoundary(
                key: const Key('map_preview_export'),
                child: DashboardV2MapCard(data: data, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject(find.byKey(const Key('map_preview_export')))
        as RenderRepaintBoundary;
    final outPath = p.join(outDir.path, 'dashboard-map-preview-reference-redesign.png');
    await tester.binding.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
    });

    expect(File(outPath).existsSync(), isTrue);
  });
}
