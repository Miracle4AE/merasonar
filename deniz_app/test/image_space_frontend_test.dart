import 'package:deniz_app/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image_space mapping mode forces chart overlay', () {
    expect(shouldForceChartOverlay('image_space'), isTrue);
    expect(shouldForceChartOverlay('IMAGE_SPACE'), isTrue);
    expect(shouldForceChartOverlay('affine_control_points'), isFalse);
    expect(shouldForceChartOverlay(null), isFalse);
  });

  test('pixel hotspot coordinates map to displayed image coordinates', () {
    final offset = hotspotPixelToDisplayedOffset(
      hotspotX: 500,
      hotspotY: 250,
      imageWidth: 1000,
      imageHeight: 500,
      displayedWidth: 300,
      displayedHeight: 150,
    );
    expect(offset.dx, closeTo(150.0, 1e-6));
    expect(offset.dy, closeTo(75.0, 1e-6));
  });
}

