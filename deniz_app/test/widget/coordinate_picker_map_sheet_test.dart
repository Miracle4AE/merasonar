import 'dart:io';
import 'dart:ui' as ui;

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/coordinate_picker_map_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('coordinate picker starts without marker when no initial point', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoordinatePickerMapSheet(
            fallbackCenter: LatLng(36.8, 28.2),
            enableTiles: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('coordinate_picker_map')), findsOneWidget);
    expect(find.byKey(const Key('selected_coordinate_marker')), findsNothing);
    expect(find.text(kMarineMapPickerSelectPrompt), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('btn_use_selected_coordinate')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('initial coordinate renders marker and enables use button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoordinatePickerMapSheet(
            initialPoint: LatLng(37.35259, 27.17072),
            fallbackCenter: LatLng(36.8, 28.2),
            enableTiles: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('selected_coordinate_marker')), findsOneWidget);
    expect(find.textContaining('37.352590'), findsOneWidget);
    expect(find.textContaining('27.170720'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('btn_use_selected_coordinate')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('clear selection removes marker and disables use button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoordinatePickerMapSheet(
            initialPoint: LatLng(37.35259, 27.17072),
            fallbackCenter: LatLng(36.8, 28.2),
            enableTiles: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('btn_clear_selected_coordinate')));
    await tester.pump();

    expect(find.byKey(const Key('selected_coordinate_marker')), findsNothing);
    expect(find.text(kMarineMapPickerSelectPrompt), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('btn_use_selected_coordinate')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('use button returns selected lat lon', (tester) async {
    LatLng? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await showModalBottomSheet<LatLng>(
                    context: context,
                    builder: (_) => const CoordinatePickerMapSheet(
                      initialPoint: LatLng(37.35259, 27.17072),
                      fallbackCenter: LatLng(36.8, 28.2),
                      enableTiles: false,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_use_selected_coordinate')));
    await tester.pumpAndSettle();

    expect(returned, isNotNull);
    expect(returned!.latitude, closeTo(37.35259, 0.000001));
    expect(returned!.longitude, closeTo(27.17072, 0.000001));
  });

  testWidgets('tap map sets selected marker when FlutterMap handles tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoordinatePickerMapSheet(
            fallbackCenter: LatLng(36.8, 28.2),
            enableTiles: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final mapRect = tester.getRect(find.byKey(const Key('coordinate_picker_map')));
    await tester.tapAt(mapRect.center);
    await tester.pump();

    expect(find.byKey(const Key('selected_coordinate_marker')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('btn_use_selected_coordinate')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('export coordinate-picker-selected-marker.png', (tester) async {
    const outEnv = String.fromEnvironment('COORD_PICKER_QA_OUT');
    final outDir = outEnv.isNotEmpty
        ? Directory(outEnv)
        : Directory(
            p.join(Directory.current.path, '..', 'docs', 'screenshots', 'rc1'),
          );
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    await tester.binding.setSurfaceSize(const Size(520, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF07111C),
          body: Center(
            child: RepaintBoundary(
              key: Key('coordinate_picker_export'),
              child: SizedBox(
                width: 480,
                height: 560,
                child: CoordinatePickerMapSheet(
                  initialPoint: LatLng(37.35259, 27.17072),
                  fallbackCenter: LatLng(36.8, 28.2),
                  enableTiles: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject(
      find.byKey(const Key('coordinate_picker_export')),
    ) as RenderRepaintBoundary;
    final outPath = p.join(outDir.path, 'coordinate-picker-selected-marker.png');
    await tester.binding.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
    });

    expect(File(outPath).existsSync(), isTrue);
  });
}
