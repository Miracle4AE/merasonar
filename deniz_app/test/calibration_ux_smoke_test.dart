import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';



import 'package:deniz_app/api_service.dart';

import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/map/widgets/control_point_picker_sheet.dart';

import 'package:deniz_app/utils/map_world_map_policy.dart';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';



/// Geçerli tek piksel PNG (`Image.file` yüklemesi için).

final Uint8List _kTinyPng = Uint8List.fromList(base64Decode(

  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',

));



List<ImageControlPoint> _samplePoints(int n) {

  const refs = [

    (lat: 36.04, lon: 29.00, px: 0.0, py: 0.0),

    (lat: 36.00, lon: 29.05, px: 390.0, py: 290.0),

    (lat: 36.04, lon: 29.05, px: 390.0, py: 0.0),

  ];

  return List<ImageControlPoint>.generate(

    n.clamp(0, refs.length),

    (i) {

      final r = refs[i];

      return ImageControlPoint(

        pixelX: r.px,

        pixelY: r.py,

        geo: LatLon(lat: r.lat, lon: r.lon),

      );

    },

    growable: false,

  );

}



void main() {

  TestWidgetsFlutterBinding.ensureInitialized();



  group('Kalibrasyon UX (duman)', () {

    late File chartFile;



    setUp(() async {

      final dir = Directory.systemTemp.createTempSync('calib_smoke_');

      chartFile = File('${dir.path}/chart.png');

      await chartFile.writeAsBytes(_kTinyPng);

    });



    tearDown(() {

      try {

        chartFile.parent.deleteSync(recursive: true);

      } catch (_) {}

    });



    Future<void> pumpSheet(

      WidgetTester tester, {

      List<ImageControlPoint> initial = const [],

    }) async {

      await tester.pumpWidget(

        MaterialApp(

          home: Scaffold(

            body: SizedBox(

              height: 900,

              width: 400,

              child: ControlPointPickerSheet(

                chartImageFile: chartFile,

                imageSize: const {'width': 400, 'height': 300},

                initialPoints: initial,

              ),

            ),

          ),

        ),

      );

      await tester.pumpAndSettle();

    }



    testWidgets('1. Haritayı Kalibre Et sheet açılıyor (başlık)', (

      tester,

    ) async {

      await pumpSheet(tester);

      expect(find.text(kCalibSheetTitle), findsOneWidget);

      expect(find.text(kCalibClose), findsOneWidget);

    });



    testWidgets('2. Navionics giriş metni görünür', (tester) async {

      await pumpSheet(tester);

      expect(find.textContaining('Navionics'), findsWidgets);

      expect(find.text(kCalibNavionicsFormatHint), findsOneWidget);

    });



    testWidgets('3. İlerleme 0/3, 1/3, 2/3, 3/3 doğru', (tester) async {

      await pumpSheet(tester, initial: const []);

      expect(find.textContaining(kCalibProgressPoints(0)), findsOneWidget);



      await pumpSheet(tester, initial: _samplePoints(1));

      expect(find.textContaining(kCalibProgressPoints(1)), findsOneWidget);



      await pumpSheet(tester, initial: _samplePoints(2));

      expect(find.textContaining(kCalibProgressPoints(2)), findsOneWidget);



      await pumpSheet(tester, initial: _samplePoints(3));

      expect(find.textContaining(kCalibProgressPoints(3)), findsOneWidget);

    });



    testWidgets('4. 3 noktadan önce analiz düğmesi devre dışı', (

      tester,

    ) async {

      await pumpSheet(tester, initial: _samplePoints(2));

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));

      expect(

        btn.onPressed,

        isNull,

        reason: '2 nokta varken tekrar analiz olmamalı',

      );

    });



    testWidgets('5. 3 noktada Kalibrasyon hazır ve düğme aktif', (

      tester,

    ) async {

      await pumpSheet(tester, initial: _samplePoints(3));

      expect(find.text(kCalibReadyMessage), findsOneWidget);

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));

      expect(btn.onPressed, isNotNull);

      expect(find.text(kCalibRerunAnalysisCta), findsOneWidget);

    });



    testWidgets('6. otomatik biçimlendirme yardım metni görünür', (

      tester,

    ) async {

      await pumpSheet(tester);

      expect(find.textContaining('Sadece rakam'), findsWidgets);

    });



    test('7. analyze isteği: image_geo_bounds JSON içinde control_points', () {

      final bounds = ImageGeoBounds(

        topLeft: LatLon(lat: 36.9, lon: 27.0),

        bottomRight: LatLon(lat: 36.0, lon: 28.0),

        controlPoints: _samplePoints(3),

        coordinateModeHint: 'geo_referenced',

      );

      final encoded = jsonEncode(bounds.toJson());

      expect(encoded.contains('"control_points"'), isTrue);

      expect(encoded.contains('"pixel"'), isTrue);

      expect(encoded.contains('"geo"'), isTrue);

      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['control_points'], isA<List>());

      expect((decoded['control_points'] as List).length, 3);

    });



    test('8. Dünya haritasında hotspotlar yalnızca geo bayrağı ile görünür', () {

      expect(

        shouldHideGeoHotspotsOnWorldMap(

          geoMapDisplayAllowed: false,

          isWorldMap: true,

        ),

        isTrue,

      );

      expect(

        shouldHideGeoHotspotsOnWorldMap(

          geoMapDisplayAllowed: true,

          isWorldMap: true,

        ),

        isFalse,

      );

    });

  });

}


