import 'dart:io';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../l10n/app_strings_tr.dart';
import '../../utils/geo_control_point_layout.dart';
import '../../utils/navionics_coordinate_parser.dart';
import 'navionics_coordinate_field.dart';
import 'premium/calibration_premium_header.dart';

class _PointEntry {
  _PointEntry({
    required this.latController,
    required this.lonController,
    this.savedPixelX,
    this.savedPixelY,
  });

  final TextEditingController latController;
  final TextEditingController lonController;
  double? savedPixelX;
  double? savedPixelY;
  String? latError;
  String? lonError;

  void dispose() {
    latController.dispose();
    lonController.dispose();
  }
}

class ControlPointPickerSheet extends StatefulWidget {
  const ControlPointPickerSheet({
    super.key,
    required this.chartImageFile,
    required this.imageSize,
    this.initialPoints = const <ImageControlPoint>[],
  });

  final File chartImageFile;
  final Map<String, int> imageSize;
  final List<ImageControlPoint> initialPoints;

  @override
  State<ControlPointPickerSheet> createState() =>
      _ControlPointPickerSheetState();
}

class _ControlPointPickerSheetState extends State<ControlPointPickerSheet> {
  final List<_PointEntry> _entries = [];
  List<ImageControlPoint> _resolvedPoints = const [];
  String? _layoutSpanError;
  int? _activePickIndex;

  int get _validGeoCount {
    var count = 0;
    for (final entry in _entries) {
      final lat = parseNavionicsCoordinate(
        entry.latController.text,
        isLatitude: true,
      );
      final lon = parseNavionicsCoordinate(
        entry.lonController.text,
        isLatitude: false,
      );
      if (lat != null && lon != null) count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _seedEntries();
    _recomputePoints();
  }

  @override
  void didUpdateWidget(covariant ControlPointPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialPoints, widget.initialPoints)) {
      for (final entry in _entries) {
        entry.dispose();
      }
      _entries.clear();
      _seedEntries();
      _recomputePoints();
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _seedEntries() {
    if (widget.initialPoints.isEmpty) {
      for (var i = 0; i < 3; i++) {
        _entries.add(
          _PointEntry(
            latController: TextEditingController(),
            lonController: TextEditingController(),
          ),
        );
      }
      return;
    }

    for (final point in widget.initialPoints.take(kMaxCalibrationControlPoints)) {
      _entries.add(
        _PointEntry(
          latController: TextEditingController(
            text: formatNavionicsCoordinate(point.geo.lat, isLatitude: true),
          ),
          lonController: TextEditingController(
            text: formatNavionicsCoordinate(point.geo.lon, isLatitude: false),
          ),
          savedPixelX: point.pixelX,
          savedPixelY: point.pixelY,
        ),
      );
    }
    while (_entries.length < 3) {
      _entries.add(
        _PointEntry(
          latController: TextEditingController(),
          lonController: TextEditingController(),
        ),
      );
    }
  }

  void _recomputePoints() {
    final geoPoints = <LatLon>[];
    for (final entry in _entries) {
      final latResult = parseNavionicsCoordinateDetailed(
        entry.latController.text,
        isLatitude: true,
      );
      final lonResult = parseNavionicsCoordinateDetailed(
        entry.lonController.text,
        isLatitude: false,
      );
      entry.latError = entry.latController.text.trim().isEmpty
          ? null
          : latResult.error;
      entry.lonError = entry.lonController.text.trim().isEmpty
          ? null
          : lonResult.error;

      if (latResult.degrees != null && lonResult.degrees != null) {
        geoPoints.add(
          LatLon(lat: latResult.degrees!, lon: lonResult.degrees!),
        );
      }
    }

    final width = widget.imageSize['width'] ?? 0;
    final height = widget.imageSize['height'] ?? 0;
    if (geoPoints.length >= 3) {
      _layoutSpanError = layoutControlPointsLayoutError(geoPoints);
      final manual = <({double? pixelX, double? pixelY})>[];
      var gi = 0;
      for (final entry in _entries) {
        final latResult = parseNavionicsCoordinateDetailed(
          entry.latController.text,
          isLatitude: true,
        );
        final lonResult = parseNavionicsCoordinateDetailed(
          entry.lonController.text,
          isLatitude: false,
        );
        if (latResult.degrees == null || lonResult.degrees == null) continue;
        manual.add((pixelX: entry.savedPixelX, pixelY: entry.savedPixelY));
        gi++;
        if (gi >= geoPoints.length) break;
      }
      final resolved = mergeControlPointsWithManualPixels(
        geoPoints: geoPoints,
        manualPixels: manual,
        imageWidth: width,
        imageHeight: height,
      );
      if (resolved.length >= 3) {
        _resolvedPoints = resolved;
        return;
      }
    } else {
      _layoutSpanError = null;
    }

    _resolvedPoints = const [];
  }

  void _beginPickOnChart(int index) {
    setState(() => _activePickIndex = index);
  }

  void _handleChartTap(Offset local, Size viewSize) {
    if (_activePickIndex == null) return;
    final rawWidth = (widget.imageSize['width'] ?? 0).toDouble();
    final rawHeight = (widget.imageSize['height'] ?? 0).toDouble();
    if (rawWidth < 2 || rawHeight < 2 || viewSize.width < 1 || viewSize.height < 1) {
      return;
    }
    final rect = _chartImageDisplayRect(
      viewSize: viewSize,
      imageWidth: rawWidth,
      imageHeight: rawHeight,
    );
    if (!rect.contains(local)) return;
    final nx = ((local.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final ny = ((local.dy - rect.top) / rect.height).clamp(0.0, 1.0);
    final px = nx * (rawWidth - 1);
    final py = ny * (rawHeight - 1);
    final idx = _activePickIndex!;
    setState(() {
      _entries[idx].savedPixelX = px;
      _entries[idx].savedPixelY = py;
      _activePickIndex = null;
      _recomputePoints();
    });
  }

  static Rect _chartImageDisplayRect({
    required Size viewSize,
    required double imageWidth,
    required double imageHeight,
  }) {
    final imageAspect = imageWidth / imageHeight;
    final viewAspect = viewSize.width / viewSize.height;
    if (imageAspect > viewAspect) {
      final h = viewSize.width / imageAspect;
      final top = (viewSize.height - h) / 2;
      return Rect.fromLTWH(0, top, viewSize.width, h);
    }
    final w = viewSize.height * imageAspect;
    final left = (viewSize.width - w) / 2;
    return Rect.fromLTWH(left, 0, w, viewSize.height);
  }

  int get _manualPixelCount {
    var n = 0;
    for (final e in _entries) {
      if (e.savedPixelX != null && e.savedPixelY != null) n++;
    }
    return n;
  }

  void _syncResolvedPoints() {
    setState(_recomputePoints);
  }

  void _clearEntryPixel(int index) {
    setState(() {
      _entries[index].savedPixelX = null;
      _entries[index].savedPixelY = null;
      _recomputePoints();
    });
  }

  void _addEntry() {
    if (_entries.length >= kMaxCalibrationControlPoints) return;
    setState(() {
      _entries.add(
        _PointEntry(
          latController: TextEditingController(),
          lonController: TextEditingController(),
        ),
      );
    });
  }

  void _removeEntry(int index) {
    if (_entries.length <= 3) return;
    setState(() {
      _entries.removeAt(index).dispose();
      _recomputePoints();
    });
  }

  void _clearAll() {
    setState(() {
      for (final entry in _entries) {
        entry.dispose();
      }
      _entries.clear();
      for (var i = 0; i < 3; i++) {
        _entries.add(
          _PointEntry(
            latController: TextEditingController(),
            lonController: TextEditingController(),
          ),
        );
      }
      _resolvedPoints = const [];
      _layoutSpanError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawWidth = (widget.imageSize['width'] ?? 0).toDouble();
    final rawHeight = (widget.imageSize['height'] ?? 0).toDouble();
    final hasSize = rawWidth > 1 && rawHeight > 1;
    final n = _validGeoCount;
    final ready = _resolvedPoints.length >= 3;

    return SafeArea(
      child: Container(
        color: const Color(0xFF071624),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(child: const SizedBox.shrink()),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(kCalibClose),
                      ),
                    ],
                  ),
                  CalibrationPremiumHeader(
                    currentStep: resolveCalibrationStep(
                      validGeoCount: n,
                      manualPixelCount: _manualPixelCount,
                      ready: ready,
                      activePickIndex: _activePickIndex,
                    ),
                    validGeoCount: n,
                    manualPixelCount: _manualPixelCount,
                    ready: ready,
                  ),
                  if (ready) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF66BB6A),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF81C784),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kCalibReadyMessage,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102436),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      kCalibNavionicsFormatHint,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _buildEntryCard(i),
                  ],
                  if (_entries.length < kMaxCalibrationControlPoints)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addEntry,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          _entries.length >= 3
                              ? kCalibAddExtraPoint
                              : kCalibAddPoint,
                        ),
                      ),
                    ),
                  if (hasSize) ...[
                    if (_activePickIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          kCalibPickActiveHint(_activePickIndex! + 1),
                          style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final viewSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return GestureDetector(
                              onTapDown: (d) =>
                                  _handleChartTap(d.localPosition, viewSize),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    widget.chartImageFile,
                                    fit: BoxFit.contain,
                                  ),
                                  if (_resolvedPoints.isNotEmpty)
                                    ...[
                                      for (var i = 0; i < _resolvedPoints.length; i++)
                                        _buildOverlayPoint(
                                          index: i,
                                          point: _resolvedPoints[i],
                                          viewSize: viewSize,
                                          rawWidth: rawWidth,
                                          rawHeight: rawHeight,
                                          manual: i < _entries.length &&
                                              _entries[i].savedPixelX != null,
                                        ),
                                    ],
                                  if (_resolvedPoints.isEmpty)
                                    Container(
                                      color: Colors.black45,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(8),
                                      child: const Text(
                                        kCalibPreviewWaiting,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kCalibPreviewCaption,
                      style: TextStyle(
                        color: _manualPixelCount >= 3
                            ? const Color(0xFF81C784)
                            : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (n < 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        kCalibNeedThreeHint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_layoutSpanError != null && _resolvedPoints.length < 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _layoutSpanError!,
                        style: const TextStyle(
                          color: Color(0xFFFFAB91),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAll,
                    child: const Text(kCalibClear),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: ready
                        ? () => Navigator.pop(context, _resolvedPoints)
                        : null,
                    child: const Text(kCalibRerunAnalysisCta),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(int index) {
    final entry = _entries[index];
    final stepHint = switch (index) {
      0 => kCalibStep1Label,
      1 => kCalibStep2Label,
      2 => kCalibStep3Label,
      _ => kCalibExtraPointLabel(index + 1),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2133),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: const Color(0xFF1E88E5),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepHint,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (_entries.length > 3)
                IconButton(
                  onPressed: () => _removeEntry(index),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.orangeAccent,
                  tooltip: kCalibRemovePoint,
                ),
            ],
          ),
          const SizedBox(height: 8),
          NavionicsCoordinateField(
            controller: entry.latController,
            label: kLabelLatitude,
            hintText: kCalibLatHintExample,
            isLatitude: true,
            errorText: entry.latError,
            onChanged: (_) => _syncResolvedPoints(),
          ),
          const SizedBox(height: 8),
          NavionicsCoordinateField(
            controller: entry.lonController,
            label: kLabelLongitude,
            hintText: kCalibLonHintExample,
            isLatitude: false,
            errorText: entry.lonError,
            onChanged: (_) => _syncResolvedPoints(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _beginPickOnChart(index),
                  icon: Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: _activePickIndex == index
                        ? const Color(0xFFFFB300)
                        : null,
                  ),
                  label: Text(
                    entry.savedPixelX != null
                        ? kCalibPixelMarked
                        : kCalibMarkOnPhoto,
                  ),
                ),
              ),
              if (entry.savedPixelX != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _clearEntryPixel(index),
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  color: Colors.orangeAccent,
                  tooltip: kCalibClearPixel,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayPoint({
    required int index,
    required ImageControlPoint point,
    required Size viewSize,
    required double rawWidth,
    required double rawHeight,
    bool manual = false,
  }) {
    final nx = (point.pixelX / (rawWidth - 1)).clamp(0.0, 1.0);
    final ny = (point.pixelY / (rawHeight - 1)).clamp(0.0, 1.0);
    final rect = _chartImageDisplayRect(
      viewSize: viewSize,
      imageWidth: rawWidth,
      imageHeight: rawHeight,
    );
    final dx = rect.left + nx * rect.width;
    final dy = rect.top + ny * rect.height;
    final color =
        manual ? const Color(0xFF66BB6A) : const Color(0xFF1E88E5);
    return Positioned(
      left: dx - 12,
      top: dy - 12,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.4),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
