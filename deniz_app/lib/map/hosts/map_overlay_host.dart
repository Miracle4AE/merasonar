import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/map/widgets/hotspot_detail_sheet.dart';
import 'package:deniz_app/map/widgets/premium/map_hotspot_detail_panel.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:flutter/material.dart';

/// Hotspot detay yan paneli — chart mobilde gizlenir (bottom sheet kullanılır).
class MapHotspotDetailOverlayHost extends StatelessWidget {
  const MapHotspotDetailOverlayHost({
    super.key,
    required this.hotspot,
    required this.isChartOverlay,
    required this.mobileLayout,
    required this.geoViz,
    required this.boatPosition,
    required this.apiService,
    required this.sessionAnalysis,
    required this.aiCache,
    required this.clientIdentity,
    required this.captainSummary,
    required this.onClose,
    required this.onGo,
    required this.onCompare,
    required this.onSave,
  });

  final Hotspot? hotspot;
  final bool isChartOverlay;
  final bool mobileLayout;
  final GeoVisualizationState geoViz;
  final dynamic boatPosition;
  final ApiService apiService;
  final FishingZoneResponse? sessionAnalysis;
  final AiAssistantCache aiCache;
  final ClientIdentityService clientIdentity;
  final String? captainSummary;
  final VoidCallback onClose;
  final VoidCallback onGo;
  final VoidCallback onCompare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final h = hotspot;
    if (h == null) return const SizedBox.shrink();
    if (isChartOverlay && mobileLayout) return const SizedBox.shrink();

    return RepaintBoundary(
      child: PremiumErrorBoundary(
        sectionTitle: kNearbyHotspotTitle,
        builder: (context) => MapHotspotDetailPanel(
        key: const Key('map_hotspot_detail_panel'),
        hotspot: h,
        onClose: onClose,
        captainSummary: captainSummary,
        onGo: onGo,
        onCompare: onCompare,
        onSave: onSave,
        detailSheet: HotspotDetailSheet(
          hotspot: h,
          geoVisualization: geoViz,
          boatPosition: boatPosition,
          apiService: apiService,
          sessionAnalysis: sessionAnalysis,
          aiAssistantCache: aiCache,
          clientIdentityService: clientIdentity,
          slidePanel: true,
        ),
      ),
      ),
    );
  }
}
