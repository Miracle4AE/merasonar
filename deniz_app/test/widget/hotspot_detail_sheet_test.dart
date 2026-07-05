import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/hotspot_detail_sheet.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Hotspot _hotspot({required String mappingTrust}) {
  return Hotspot.fromJson({
    'id': 1,
    'feature_type': 'drop_off',
    'rank_by_proximity': 1,
    'rank': 1,
    'rank_overall': 1,
    'rank_by_score_then_distance': 1,
    'latitude': 37.352,
    'longitude': 27.203,
    'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
    'distance_m': 125.4,
    'bearing_deg': 88.2,
    'score': 0.85,
    'classification': 'A',
    'reasoning': <String>[],
    'supporting_metrics': <String, dynamic>{},
    'sea_state': <String, dynamic>{},
    'pixel_centroid': {'x': 100.0, 'y': 200.0},
    'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
    'trust_state': 'trusted',
    'trust_score': 0.9,
    'mapping_trust': mappingTrust,
    'is_renderable': true,
    'fishing_advice': <String, dynamic>{
      'species_predictions': <dynamic>[],
      'bait': <dynamic>[],
      'best_times': <dynamic>[],
      'tackle': <dynamic>[],
      'selection_reasons': <dynamic>[],
    },
    'confirmed_depth': <String, dynamic>{},
    'likely_species': <String, dynamic>{
      'source': 'none',
      'fallback': true,
      'total_records_considered': 0,
      'top_species': <dynamic>[],
    },
  });
}

GeoVisualizationState _viz({
  required String coordinateMode,
  required CalibrationReliability reliability,
}) {
  return GeoVisualizationState(
    coordinateMode: coordinateMode,
    reliability: reliability,
    calibrationQuality: 0.85,
    transformConfidence: 0.85,
  );
}

/// DraggableScrollableSheet için yeterli kısıt (smoke).
Widget _pumpSheet({
  required Hotspot hotspot,
  GeoVisualizationState? geoVisualization,
  LatLon? boatPosition,
  ApiService? apiService,
  FishingZoneResponse? sessionAnalysis,
  AiAssistantCache? aiAssistantCache,
  ClientIdentityService? clientIdentityService,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            HotspotDetailSheet(
              hotspot: hotspot,
              geoVisualization: geoVisualization,
              boatPosition: boatPosition,
              apiService: apiService,
              sessionAnalysis: sessionAnalysis,
              aiAssistantCache: aiAssistantCache,
              clientIdentityService: clientIdentityService,
            ),
          ],
        ),
      ),
    ),
  );
}

FishingZoneResponse _sessionAnalysis() {
  return FishingZoneResponse.fromJson({
    'boat': {
      'raw_gps': {'lat': 37.352, 'lon': 27.203},
      'smoothed_gps': {'lat': 37.352, 'lon': 27.203},
    },
    'ranked_hotspots': [
      {
        'id': 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': 1,
        'latitude': 37.352,
        'longitude': 27.203,
        'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
        'score': 0.85,
        'classification': 'A',
        'reasoning': [],
        'supporting_metrics': {},
        'sea_state': {},
        'pixel_centroid': {'x': 100, 'y': 200},
        'hotspot_pixel_anchor': {'x': 100, 'y': 200},
        'trust_state': 'trusted',
        'trust_score': 0.9,
        'mapping_trust': 'chart_aligned',
        'is_renderable': true,
      },
    ],
    'coordinate_mode': 'geo_referenced',
    'session_advice': 'Test oturum',
  });
}

void main() {
  group('HotspotDetailSheet smoke', () {
    testWidgets('geo güvenilir: Konum satırları ve sayılar görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpSheet(
          hotspot: _hotspot(mappingTrust: 'chart_aligned'),
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kHotspotGeoMaritimeSectionTitle), findsOneWidget);
      expect(find.text('Enlem'), findsWidgets);
      expect(find.text('Boylam'), findsWidgets);
      expect(find.text('Mesafe'), findsWidgets);
      expect(find.text('Kerteriz'), findsWidgets);

      expect(find.textContaining("37°21.120' N"), findsWidgets);
      expect(find.textContaining("027°12.180' E"), findsWidgets);
      expect(find.textContaining('125.4'), findsWidgets);
      expect(find.textContaining('88.2'), findsWidgets);
    });

    testWidgets(
      'image_space / unsafe: dört satır + yer tutucular',
      (tester) async {
        await tester.pumpWidget(
          _pumpSheet(
            hotspot: _hotspot(mappingTrust: 'image_space'),
            geoVisualization: _viz(
              coordinateMode: kCoordinateModeImageSpace,
              reliability: CalibrationReliability.unsafe,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(kHotspotGeoMaritimeSectionTitle), findsOneWidget);
        expect(find.text('Enlem'), findsWidgets);
        expect(find.text('Boylam'), findsWidgets);
        expect(find.text('Mesafe'), findsWidgets);
        expect(find.text('Kerteriz'), findsWidgets);

        expect(find.text(kHotspotGeoPlaceholderDash), findsWidgets);
        expect(find.text(kHotspotGeoDistanceUnavailable), findsOneWidget);
        expect(find.text(kHotspotGeoBearingUnavailable), findsOneWidget);
      },
    );

    testWidgets('boat_anchor_estimated: sayılar + yaklaşık etiket görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpSheet(
          hotspot: _hotspot(mappingTrust: 'boat_anchor_estimated'),
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeBoatAnchorEstimated,
            reliability: CalibrationReliability.approximate,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kHotspotGeoMaritimeSectionTitle), findsOneWidget);
      expect(find.textContaining(kHotspotGeoBoatAnchorEstimatedLabel), findsOneWidget);
      expect(find.textContaining('Bu koordinatlar kontrol noktasıyla doğrulanmış değildir.'), findsOneWidget);

      expect(find.textContaining("37°21.120' N"), findsWidgets);
      expect(find.textContaining("027°12.180' E"), findsWidgets);
      expect(find.textContaining('125.4'), findsWidgets);
      expect(find.textContaining('88.2'), findsWidgets);
    });

    testWidgets('veri yoksa profesyonel açıklamalar görünür', (tester) async {
      final h = Hotspot.fromJson({
        'id': 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': 1,
        'latitude': 37.0,
        'longitude': 27.0,
        'geo_coordinate': {'lat': 37.0, 'lon': 27.0},
        'distance_m': 0.0,
        'bearing_deg': 0.0,
        'score': 0.85,
        'classification': 'A',
        'reasoning': <String>[],
        'supporting_metrics': <String, dynamic>{},
        'sea_state': <String, dynamic>{},
        'pixel_centroid': {'x': 100.0, 'y': 200.0},
        'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
        'trust_state': 'trusted',
        'trust_score': 0.9,
        'mapping_trust': 'chart_aligned',
        'is_renderable': true,
        'fishing_advice': <String, dynamic>{
          'species_predictions': <dynamic>[],
          'bait': <dynamic>[],
          'best_times': <dynamic>[],
          'tackle': <dynamic>[],
          'selection_reasons': <dynamic>[],
        },
        // confirmed_depth / likely_species intentionally missing/empty
        'confirmed_depth': <String, dynamic>{},
        'likely_species': <String, dynamic>{},
      });

      await tester.pumpWidget(
        _pumpSheet(
          hotspot: h,
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bu bölüm için öneri şu anda üretilemedi.'),
        findsWidgets,
      );
      expect(
        find.text('Bu nokta için tür tahmini şu anda üretilemedi.'),
        findsOneWidget,
      );
      expect(
        find.text('Bu nokta için teyit derinliği şu anda üretilemedi.'),
        findsOneWidget,
      );
      expect(
        find.text('Bu nokta için bölgesel tür özeti şu anda üretilemedi.'),
        findsOneWidget,
      );
      expect(
        find.text('Bu nokta için yapı × bölgesel tür uyumu sinyali üretilemedi.'),
        findsOneWidget,
      );
    });

    testWidgets('Konum kartı GPX düğmesinden önce (dikey sıra)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpSheet(
          hotspot: _hotspot(mappingTrust: 'chart_aligned'),
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.good,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final maritimeDy =
          tester.getTopLeft(find.text(kHotspotGeoMaritimeSectionTitle)).dy;
      final gpxDy = tester
          .getTopLeft(find.text('Bu noktayı GPX olarak paylaş'))
          .dy;
      expect(maritimeDy < gpxDy, isTrue);
    });

    testWidgets('biodiversity fallback occurrence_count=0: sayı görünmez + yaklaşık açıklama', (
      tester,
    ) async {
      final h = Hotspot.fromJson({
        'id': 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': 1,
        'latitude': 37.0,
        'longitude': 27.0,
        'geo_coordinate': {'lat': 37.0, 'lon': 27.0},
        'distance_m': 125.4,
        'bearing_deg': 88.2,
        'score': 0.85,
        'classification': 'A',
        'reasoning': <String>[],
        'supporting_metrics': <String, dynamic>{},
        'sea_state': <String, dynamic>{},
        'pixel_centroid': {'x': 100.0, 'y': 200.0},
        'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
        'trust_state': 'trusted',
        'trust_score': 0.9,
        'mapping_trust': 'chart_aligned',
        'is_renderable': true,
        'fishing_advice': <String, dynamic>{
          'species_predictions': <dynamic>[],
          'bait': <dynamic>[],
          'best_times': <dynamic>[],
          'tackle': <dynamic>[],
          'selection_reasons': <dynamic>[],
        },
        'confirmed_depth': <String, dynamic>{},
        'likely_species': <String, dynamic>{
          'source': 'rule_based_fallback',
          'confidence': 'approximate',
          'fallback': true,
          'total_records_considered': 0,
          'top_species': [
            {'species': 'Levrek', 'occurrence_count': 0},
          ],
        },
      });

      await tester.pumpWidget(
        _pumpSheet(
          hotspot: h,
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yaklaşık sinyal'), findsOneWidget);
      expect(
        find.textContaining('Dış tür kaydı doğrulanmadı'),
        findsOneWidget,
      );
      // Count should not be shown when occurrence_count==0.
      expect(find.textContaining('(0)'), findsNothing);
      expect(find.textContaining('• Levrek'), findsOneWidget);
    });

    testWidgets('biodiversity enrichment occurrence_count>0: sayı görünür', (
      tester,
    ) async {
      final h = Hotspot.fromJson({
        'id': 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': 1,
        'latitude': 37.0,
        'longitude': 27.0,
        'geo_coordinate': {'lat': 37.0, 'lon': 27.0},
        'distance_m': 125.4,
        'bearing_deg': 88.2,
        'score': 0.85,
        'classification': 'A',
        'reasoning': <String>[],
        'supporting_metrics': <String, dynamic>{},
        'sea_state': <String, dynamic>{},
        'pixel_centroid': {'x': 100.0, 'y': 200.0},
        'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
        'trust_state': 'trusted',
        'trust_score': 0.9,
        'mapping_trust': 'chart_aligned',
        'is_renderable': true,
        'fishing_advice': <String, dynamic>{
          'species_predictions': <dynamic>[],
          'bait': <dynamic>[],
          'best_times': <dynamic>[],
          'tackle': <dynamic>[],
          'selection_reasons': <dynamic>[],
        },
        'confirmed_depth': <String, dynamic>{},
        'likely_species': <String, dynamic>{
          'source': 'OBIS',
          'fallback': false,
          'total_records_considered': 12,
          'top_species': [
            {'species': 'Mercan', 'occurrence_count': 3},
          ],
        },
      });

      await tester.pumpWidget(
        _pumpSheet(
          hotspot: h,
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yaklaşık sinyal'), findsNothing);
      expect(find.textContaining('(3)'), findsOneWidget);
    });

    testWidgets('AI ile Açıkla butonu oturum analizi varken görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pumpSheet(
          hotspot: _hotspot(mappingTrust: 'chart_aligned'),
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: MockClient((_) async => http.Response('', 500)),
          ),
          sessionAnalysis: _sessionAnalysis(),
          aiAssistantCache: AiAssistantCache(),
          clientIdentityService: ClientIdentityService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kAiAssistantHotspotButtonLabel), findsOneWidget);
    });

    testWidgets('AI butonu oturum analizi yokken gizli', (tester) async {
      await tester.pumpWidget(
        _pumpSheet(
          hotspot: _hotspot(mappingTrust: 'chart_aligned'),
          geoVisualization: _viz(
            coordinateMode: kCoordinateModeGeoReferenced,
            reliability: CalibrationReliability.excellent,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(kAiAssistantHotspotButtonLabel), findsNothing);
    });
  });
}
