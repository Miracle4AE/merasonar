import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/world_map_empty_diagnostics_copy.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWorldMapEmptyDiagnosticsCopy', () {
    test('has_current_gps false → GPS kartı', () {
      final d = AnalysisDiagnostics.fromJson({
        'has_current_gps': false,
        'boat_anchor_estimate_reason': 'no_current_gps',
      });
      final c = resolveWorldMapEmptyDiagnosticsCopy(diagnostics: d);
      expect(c.title, kMapWorldMapEmptyGpsTitle);
      expect(c.body, contains(kMapWorldMapEmptyGpsBody));
      expect(c.body, contains(kMapBoatAnchorReasonLineNoGps));
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.gpsRefresh);
      expect(c.primaryLabel, kMapWorldMapEmptyGpsCta);
    });

    test('anchor yok → tekne kartı', () {
      final d = AnalysisDiagnostics.fromJson({
        'has_current_gps': true,
        'has_boat_pixel_anchor_detected': false,
        'has_boat_pixel_anchor_request': false,
        'boat_anchor_estimate_reason': 'no_boat_pixel_anchor',
      });
      final c = resolveWorldMapEmptyDiagnosticsCopy(diagnostics: d);
      expect(c.title, kMapWorldMapEmptyAnchorTitle);
      expect(c.body, contains(kMapWorldMapEmptyAnchorBody));
      expect(c.body, contains(kMapBoatAnchorReasonLineNoAnchor));
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.markBoatAnchor);
    });

    test('ölçek/mapper yok + GPS bilinmiyor + anchor var → kalibrasyon kartı', () {
      final d = AnalysisDiagnostics.fromJson({
        'has_boat_pixel_anchor_detected': true,
        'has_boat_pixel_anchor_request': false,
        'has_bounds_mapper': false,
        'has_bounds_request': false,
        'boat_anchor_estimate_reason': 'no_bounds_mapper',
      });
      final c = resolveWorldMapEmptyDiagnosticsCopy(diagnostics: d);
      expect(c.title, kMapWorldMapEmptyMapperTitle);
      expect(c.body, contains(kMapWorldMapEmptyMapperBody));
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.calibrate);
      expect(c.primaryLabel, kCalibrateMapButton);
    });

    test('ölçek/mapper yok ama GPS + tekne anchor var → kalibrasyon kartı değil', () {
      final d = AnalysisDiagnostics.fromJson({
        'has_current_gps': true,
        'has_boat_pixel_anchor_detected': true,
        'has_boat_pixel_anchor_request': false,
        'has_bounds_mapper': false,
        'has_bounds_request': false,
        'boat_anchor_estimate_reason': 'no_bounds_mapper',
      });
      final c = resolveWorldMapEmptyDiagnosticsCopy(diagnostics: d);
      expect(c.title, kMapImageSpaceWorldEmptyTitle);
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.calibrate);
    });

    test('teşhis yok → genel kart + sunucu uyarısı', () {
      final c = resolveWorldMapEmptyDiagnosticsCopy(
        diagnostics: AnalysisDiagnostics.fromJson(const {}),
        serverWarningTr: 'Sunucudan özel uyarı.',
      );
      expect(c.title, kMapImageSpaceWorldEmptyTitle);
      expect(c.body, contains('Sunucudan özel uyarı.'));
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.calibrate);
    });

    test('boat_anchor_estimated çıktısı resolver’ı zorlamaz (genel)', () {
      final d = AnalysisDiagnostics.fromJson({
        'has_current_gps': true,
        'has_boat_pixel_anchor_detected': true,
        'has_boat_pixel_anchor_request': true,
        'has_bounds_mapper': true,
        'has_bounds_request': false,
        'output_coordinate_mode': 'boat_anchor_estimated',
      });
      final c = resolveWorldMapEmptyDiagnosticsCopy(diagnostics: d);
      expect(c.title, kMapImageSpaceWorldEmptyTitle);
      expect(c.primaryAction, WorldMapEmptyPrimaryAction.calibrate);
    });
  });
}
