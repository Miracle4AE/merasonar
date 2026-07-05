import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/domain/world_map_hotspot_layout.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_premium_marker.dart';
import 'package:deniz_app/map/widgets/premium/premium_map_marker.dart';
import 'package:deniz_app/services/boat_gps_smoother.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Dünya haritası + chart overlay marker render — algoritma MapScreen ile aynı.
class MapMarkerLayer {
  const MapMarkerLayer({
    required this.recGlow,
    required this.hotspotFocusId,
    required this.geoViz,
    required this.isWorldMapMode,
    required this.boatRenderLatLon,
    required this.liveGpsState,
    required this.boatAnchorLowConfidence,
    required this.isGpsFallbackBoat,
    required this.classificationColor,
    required this.markerLabel,
    required this.markerLabelWithNav,
    required this.displayScorePct,
    required this.recommendationBadgeLabel,
    required this.hotspotTooltipExtended,
    required this.pixelToCanvas,
    required this.onHotspotTap,
    required this.onClusterTap,
  });

  final Animation<double> recGlow;
  final ValueListenable<int?> hotspotFocusId;
  final GeoVisualizationState geoViz;
  final bool isWorldMapMode;
  final LatLon? boatRenderLatLon;
  final ValueListenable<AccuracyAwarePositionState?> liveGpsState;
  final bool boatAnchorLowConfidence;
  final bool isGpsFallbackBoat;
  final Color Function(String classification) classificationColor;
  final String Function(Hotspot hotspot) markerLabel;
  final String Function(Hotspot hotspot) markerLabelWithNav;
  final int Function(double score) displayScorePct;
  final String Function(Hotspot hotspot) recommendationBadgeLabel;
  final String Function(Hotspot hotspot) hotspotTooltipExtended;
  final Offset Function(PixelAnchor anchor, Size canvasSize) pixelToCanvas;
  final void Function(Hotspot hotspot) onHotspotTap;
  final void Function(List<Hotspot> members) onClusterTap;

  List<Marker> buildWorldMapMarkers(
    List<WorldMapHotspotPlacement> placements, {
    required bool mobileLayout,
  }) {
    final markers = <Marker>[];
    final boat = boatRenderLatLon;
    final live = liveGpsState.value;
    final gpsReliability = live?.reliability ?? 1.0;
    final lowGps = isWorldMapMode && gpsReliability < 0.48;

    if (boat != null) {
      final emergencyBoat = geoViz.isBoatAnchorEstimated;
      final lowTrust = boatAnchorLowConfidence || isGpsFallbackBoat || lowGps;
      final boatColor = emergencyBoat
          ? const Color(0xFF00E5FF)
          : (lowTrust ? const Color(0xFFE8A958) : const Color(0xFF5DD5E8));
      final borderW = emergencyBoat ? 2.2 : (lowGps ? 2.4 : 2.0);
      markers.add(
        Marker(
          point: LatLng(boat.lat, boat.lon),
          width: 46,
          height: 46,
          child: Semantics(
            label: 'Tekne konumu',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: boatColor.withValues(alpha: emergencyBoat ? 0.28 : 0.20),
                border: Border.all(color: boatColor, width: borderW),
              ),
              child: Icon(
                Icons.directions_boat_filled_rounded,
                color: boatColor,
                size: 28,
              ),
            ),
          ),
        ),
      );
    }

    var emergencySeq = 0;
    for (final placement in placements) {
      switch (placement) {
        case WorldMapHotspotSingle(:final hotspot):
          if (geoViz.isBoatAnchorEstimated) {
            emergencySeq++;
            final lat = hotspot.latitude;
            final lon = hotspot.longitude;
            if (!lat.isFinite || !lon.isFinite) continue;
            if (lat.abs() < 1e-9 && lon.abs() < 1e-9) continue;
            markers.add(
              _buildBoatAnchorEmergencyHotspotMarker(
                hotspot,
                emergencySeq,
                mobileLayout: mobileLayout,
              ),
            );
            continue;
          }
          if (!hotspot.isRenderable) continue;
          final lat = hotspot.latitude;
          final lon = hotspot.longitude;
          if (!lat.isFinite || !lon.isFinite) continue;
          if (lat.abs() < 1e-9 && lon.abs() < 1e-9) continue;
          markers.add(
            _buildSingleWorldHotspotMarker(hotspot, mobileLayout: mobileLayout),
          );
        case WorldMapHotspotCluster(:final center, :final members):
          if (!center.latitude.isFinite ||
              !center.longitude.isFinite ||
              (center.latitude.abs() < 1e-9 && center.longitude.abs() < 1e-9)) {
            continue;
          }
          final approx = geoViz.isBoatAnchorEstimated;
          final clusterTouch = mobileLayout ? 56.0 : 48.0;
          markers.add(
            Marker(
              point: LatLng(center.latitude, center.longitude),
              width: clusterTouch,
              height: clusterTouch,
              child: PremiumMapClusterMarker(
                countLabel: approx ? '≈${members.length}' : '${members.length}',
                approximate: approx,
                onTap: () => onClusterTap(members),
              ),
            ),
          );
      }
    }

    if (kDebugMode && geoViz.isBoatAnchorEstimated) {
      debugPrint(
        '[MapMarkerLayer] final_rendered_leaf_markers=${markers.length} '
        '(includes_boat=${boat != null ? 1 : 0})',
      );
    }

    return markers;
  }

  Marker _buildBoatAnchorEmergencyHotspotMarker(
    Hotspot hotspot,
    int sequence, {
    required bool mobileLayout,
  }) {
    const amber = Color(0xFFFFB300);
    final outer = mobileLayout ? 52.0 : 40.0;
    return Marker(
      point: LatLng(hotspot.latitude, hotspot.longitude),
      width: outer,
      height: outer,
      child: Tooltip(
        message: hotspotTooltipExtended(hotspot),
        child: Semantics(
          label: 'Hotspot $sequence',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onHotspotTap(hotspot),
            child: Container(
              key: Key('map_hotspot_marker_${hotspot.id}'),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: amber.withValues(alpha: 0.92),
                border: Border.all(color: const Color(0xFFFFE082), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$sequence',
                style: const TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildSingleWorldHotspotMarker(
    Hotspot hotspot, {
    required bool mobileLayout,
  }) {
    final color = classificationColor(hotspot.classification);
    final pr = hotspot.recommendationRank;
    final topTier = pr >= 1 && pr <= 3;
    final badge = recommendationBadgeLabel(hotspot);
    final approxMode = geoViz.isBoatAnchorEstimated;
    final touchBoost = mobileLayout ? 1.12 : 1.0;
    final mw = (topTier ? (pr == 1 ? 138.0 : 124.0) : 92.0) * touchBoost;
    final mh = (topTier ? (badge.isNotEmpty ? 108.0 : 88.0) : 76.0) * touchBoost;
    final fadeOpacity =
        topTier ? 1.0 : (0.45 + 0.55 * hotspot.score.clamp(0.0, 1.0));

    return Marker(
      point: LatLng(hotspot.latitude, hotspot.longitude),
      width: mw,
      height: mh,
      child: Tooltip(
        triggerMode: TooltipTriggerMode.longPress,
        message: hotspotTooltipExtended(hotspot),
        child: ValueListenableBuilder<int?>(
          valueListenable: hotspotFocusId,
          builder: (context, focusedId, _) {
            final focused = focusedId != null && focusedId == hotspot.id;
            return RepaintBoundary(
              child: AnimatedOpacity(
                opacity: fadeOpacity,
                duration: const Duration(milliseconds: 220),
                child: AnimatedScale(
                  scale: focused ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: AnimatedBuilder(
                    animation: recGlow,
                    builder: (context, _) {
                      final pulse = Curves.easeInOut.transform(recGlow.value);
                      return Semantics(
                        label: 'Hotspot ${hotspot.classification}',
                        value: '${displayScorePct(hotspot.score)}',
                        button: true,
                        selected: focused,
                        child: PremiumMapMarker(
                          key: Key('map_hotspot_marker_${hotspot.id}'),
                          scoreLabel: markerLabelWithNav(hotspot),
                          color: color,
                          scoreText: '${displayScorePct(hotspot.score)}',
                          focused: focused,
                          topTier: topTier,
                          pulse: pulse,
                          badgeLabel: badge.isEmpty ? null : badge,
                          approximate: approxMode,
                          onTap: () {
                            if (kDebugMode) {
                              debugPrint('Map hotspot tapped: ${hotspot.id}');
                            }
                            onHotspotTap(hotspot);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildChartHotspotMarker(
    Hotspot hotspot,
    Size canvasSize, {
    required bool mobile,
    bool compact = false,
  }) {
    final anchor = hotspot.hotspotPixelAnchor;
    final offset = pixelToCanvas(anchor, canvasSize);
    final color = classificationColor(hotspot.classification);
    final pr = hotspot.recommendationRank;
    final topTier = pr >= 1 && pr <= 3;
    final badge = recommendationBadgeLabel(hotspot);
    final scoreText = '${(hotspot.score * 100).round()}';
    final scoreLabel = compact ? hotspot.classification : markerLabel(hotspot);
    final markerSize = compact ? 30.0 : 36.0;

    return Positioned(
      left: offset.dx - markerSize / 2,
      top: offset.dy - markerSize / 2,
      child: Tooltip(
        triggerMode: TooltipTriggerMode.longPress,
        message: hotspotTooltipExtended(hotspot),
        child: ValueListenableBuilder<int?>(
          valueListenable: hotspotFocusId,
          builder: (context, focusedId, _) {
            final focused = focusedId != null && focusedId == hotspot.id;
            return RepaintBoundary(
              child: AnimatedBuilder(
                animation: recGlow,
                builder: (context, _) {
                  final pulse = Curves.easeInOut.transform(recGlow.value);
                  return AnimatedScale(
                    scale: focused ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Semantics(
                      label: 'Chart hotspot ${hotspot.classification}',
                      value: scoreText,
                      button: true,
                      selected: focused,
                      child: ChartOverlayPremiumMarker(
                        scoreText: scoreText,
                        scoreLabel: scoreLabel,
                        color: color,
                        focused: focused,
                        topTier: topTier,
                        pulse: pulse,
                        badgeLabel: badge.isEmpty ? null : badge,
                        compact: compact,
                        onTap: () => onHotspotTap(hotspot),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildChartBoatMarker(PixelAnchor anchor, Size canvasSize) {
    final offset = pixelToCanvas(anchor, canvasSize);
    final lowTrust = boatAnchorLowConfidence || isGpsFallbackBoat;
    final color = lowTrust ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
    return Positioned(
      left: offset.dx - 17,
      top: offset.dy - 17,
      child: Semantics(
        label: 'Tekne konumu',
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.22),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            Icons.directions_boat_filled_rounded,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }
}
