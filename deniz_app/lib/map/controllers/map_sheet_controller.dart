import 'package:deniz_app/api_service.dart';

/// Hotspot detay paneli / sheet görünürlük yardımcısı — iş mantığı MapScreen'de kalır.
class MapSheetController {
  Hotspot? panelHotspot;

  bool get isPanelOpen => panelHotspot != null;

  Hotspot? get selectedHotspot => panelHotspot;

  void openPanel(Hotspot hotspot) {
    panelHotspot = hotspot;
  }

  void closePanel() {
    panelHotspot = null;
  }

  /// Chart overlay + mobil: panel yerine bottom sheet kullanılır.
  bool shouldUseInlinePanel({
    required bool isChartOverlay,
    required bool mobileLayout,
  }) {
    if (panelHotspot == null) return false;
    if (isChartOverlay && mobileLayout) return false;
    return true;
  }
}
