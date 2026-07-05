import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CoordinatePickerMapSheet extends StatefulWidget {
  const CoordinatePickerMapSheet({
    super.key,
    this.initialPoint,
    required this.fallbackCenter,
    this.enableTiles = true,
  });

  final LatLng? initialPoint;
  final LatLng fallbackCenter;
  final bool enableTiles;

  @override
  State<CoordinatePickerMapSheet> createState() =>
      _CoordinatePickerMapSheetState();
}

class _CoordinatePickerMapSheetState extends State<CoordinatePickerMapSheet> {
  late LatLng? _selectedPoint = widget.initialPoint;

  LatLng get _center => _selectedPoint ?? widget.fallbackCenter;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height * 0.68,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_outlined,
                    color: AppColors.borderCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      kMarineMapPickerTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_selectedPoint != null)
                    TextButton.icon(
                      key: const Key('btn_clear_selected_coordinate'),
                      onPressed: () => setState(() => _selectedPoint = null),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(kMarineMapPickerClear),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      FlutterMap(
                        key: const Key('coordinate_picker_map'),
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: widget.initialPoint == null ? 8 : 12,
                          onTap: (_, point) {
                            setState(() => _selectedPoint = point);
                          },
                        ),
                        children: [
                          if (widget.enableTiles)
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.deniz.uygulamasi',
                            ),
                          if (_selectedPoint != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedPoint!,
                                  width: 96,
                                  height: 88,
                                  alignment: Alignment.topCenter,
                                  child: const SelectedCoordinateMarker(),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (!widget.enableTiles)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              setState(() => _selectedPoint = _center);
                            },
                          ),
                        ),
                      const Positioned.fill(
                        child: IgnorePointer(child: _MapPickerVignette()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  _SelectedCoordinatePanel(point: _selectedPoint),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('btn_use_selected_coordinate'),
                          onPressed: _selectedPoint == null
                              ? null
                              : () => Navigator.of(context).pop(_selectedPoint),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text(kMarineUseCoordinate),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectedCoordinateMarker extends StatelessWidget {
  const SelectedCoordinateMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('selected_coordinate_marker'),
      width: 96,
      height: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.borderCyan.withValues(alpha: 0.55),
              ),
            ),
            child: const Text(
              kMarineMapPickerSelectedPoint,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.borderCyan.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.borderCyan.withValues(alpha: 0.42),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: AppColors.borderCyan.withValues(alpha: 0.86),
                width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentTeal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCoordinatePanel extends StatelessWidget {
  const _SelectedCoordinatePanel({required this.point});

  final LatLng? point;

  @override
  Widget build(BuildContext context) {
    final label = point == null
        ? kMarineMapPickerSelectPrompt
        : '${point!.latitude.toStringAsFixed(6)}, '
            '${point!.longitude.toStringAsFixed(6)}';

    return Container(
      key: const Key('selected_coordinate_label'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: point == null
              ? AppColors.borderSoft(alpha: 0.24)
              : AppColors.borderCyan.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: [
          Icon(
            point == null
                ? Icons.touch_app_outlined
                : Icons.location_on_outlined,
            color: point == null ? AppColors.textMuted : AppColors.borderCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPickerVignette extends StatelessWidget {
  const _MapPickerVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderCyan.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0.08),
            Colors.transparent,
            AppColors.surfaceDark.withValues(alpha: 0.14),
          ],
        ),
      ),
    );
  }
}
