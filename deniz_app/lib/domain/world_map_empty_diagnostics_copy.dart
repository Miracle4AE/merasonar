import '../api_service.dart';
import '../l10n/app_strings_tr.dart';

/// Dünya haritası boş overlay — sunucu boat-anchor teşhis alanlarına göre metin/aksiyon.
enum WorldMapEmptyPrimaryAction {
  gpsRefresh,
  markBoatAnchor,
  calibrate,
}

class WorldMapEmptyDiagnosticsCopy {
  const WorldMapEmptyDiagnosticsCopy({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final WorldMapEmptyPrimaryAction primaryAction;
}

String? _userLineForEstimateReason(String? code) {
  switch ((code ?? '').trim()) {
    case 'no_current_gps':
      return kMapBoatAnchorReasonLineNoGps;
    case 'no_boat_pixel_anchor':
      return kMapBoatAnchorReasonLineNoAnchor;
    case 'no_bounds_mapper':
    case 'invalid_bounds':
      return kMapBoatAnchorReasonLineNoScale;
    case 'pending_mapper':
      return kMapBoatAnchorReasonLinePending;
    default:
      return null;
  }
}

String _appendReasonIfFresh(String body, String? reasonLine) {
  final extra = reasonLine?.trim();
  if (extra == null || extra.isEmpty) return body;
  if (body.contains(extra)) return body;
  return '$body\n\n$extra';
}

/// [serverWarningTr] yalnızca genel (fallback) kartında kullanılır; ham teşhis kodu gösterilmez.
WorldMapEmptyDiagnosticsCopy resolveWorldMapEmptyDiagnosticsCopy({
  required AnalysisDiagnostics? diagnostics,
  String? serverWarningTr,
}) {
  final d = diagnostics;
  final reasonLine = _userLineForEstimateReason(d?.boatAnchorEstimateReason);

  if (d != null && d.hasCurrentGps == false) {
    return WorldMapEmptyDiagnosticsCopy(
      title: kMapWorldMapEmptyGpsTitle,
      body: _appendReasonIfFresh(kMapWorldMapEmptyGpsBody, reasonLine),
      primaryLabel: kMapWorldMapEmptyGpsCta,
      primaryAction: WorldMapEmptyPrimaryAction.gpsRefresh,
    );
  }

  if (d != null &&
      d.hasBoatPixelAnchorDetected == false &&
      d.hasBoatPixelAnchorRequest == false) {
    return WorldMapEmptyDiagnosticsCopy(
      title: kMapWorldMapEmptyAnchorTitle,
      body: _appendReasonIfFresh(kMapWorldMapEmptyAnchorBody, reasonLine),
      primaryLabel: kMapWorldMapEmptyAnchorCta,
      primaryAction: WorldMapEmptyPrimaryAction.markBoatAnchor,
    );
  }

  if (d != null &&
      d.hasBoundsMapper == false &&
      d.hasBoundsRequest == false) {
    final hasAnchorSignal =
        d.hasBoatPixelAnchorDetected == true || d.hasBoatPixelAnchorRequest == true;
    // GPS + tekne anchor varken eksik bounds artık sunucuda heuristic ile kapatılır;
    // kalibrasyon kartını tek tık akışında gösterme.
    if (!(d.hasCurrentGps == true && hasAnchorSignal)) {
      return WorldMapEmptyDiagnosticsCopy(
        title: kMapWorldMapEmptyMapperTitle,
        body: _appendReasonIfFresh(kMapWorldMapEmptyMapperBody, reasonLine),
        primaryLabel: kMapWorldMapEmptyMapperCta,
        primaryAction: WorldMapEmptyPrimaryAction.calibrate,
      );
    }
  }

  final sw = serverWarningTr?.trim();
  var body =
      (sw != null && sw.isNotEmpty) ? sw : kMapImageSpaceWorldEmptyBody;
  body = _appendReasonIfFresh(body, reasonLine);

  return WorldMapEmptyDiagnosticsCopy(
    title: kMapImageSpaceWorldEmptyTitle,
    body: body,
    primaryLabel: kCalibrateMapButton,
    primaryAction: WorldMapEmptyPrimaryAction.calibrate,
  );
}
