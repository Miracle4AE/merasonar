import 'package:deniz_app/theme/app_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// flutter_map için yumuşak kamera hareketi — ani jump yerine easeInOutCubic.
class MapCameraAnimator {
  MapCameraAnimator({
    required MapController controller,
    required TickerProvider vsync,
  })  : _controller = controller,
        _vsync = vsync;

  final MapController _controller;
  final TickerProvider _vsync;
  AnimationController? _moveCtrl;

  void dispose() {
    _moveCtrl?.dispose();
  }

  void animateTo(
    LatLng target, {
    double? zoom,
    Duration? duration,
    VoidCallback? onComplete,
  }) {
    _moveCtrl?.dispose();
    final startCenter = _controller.camera.center;
    final startZoom = _controller.camera.zoom;
    final endZoom = zoom ?? startZoom;

    _moveCtrl = AnimationController(
      vsync: _vsync,
      duration: duration ?? AppMotion.cameraMove,
    );
    final curved = CurvedAnimation(
      parent: _moveCtrl!,
      curve: AppMotion.pageCurve,
    );

    void tick() {
      final t = curved.value;
      final lat = _lerp(startCenter.latitude, target.latitude, t);
      final lon = _lerp(startCenter.longitude, target.longitude, t);
      final z = _lerp(startZoom, endZoom, t);
      _controller.move(LatLng(lat, lon), z);
    }

    _moveCtrl!.addListener(tick);
    _moveCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete?.call();
      }
    });
    _moveCtrl!.forward();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
