import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

class MapHotspotStrip extends StatelessWidget {
  const MapHotspotStrip({
    super.key,
    required this.hotspots,
    required this.onTap,
    required this.scoreFormatter,
    this.mobile = false,
    this.selectedHotspotId,
  });

  final List<Hotspot> hotspots;
  final ValueChanged<Hotspot> onTap;
  final int Function(double score) scoreFormatter;
  final bool mobile;
  final int? selectedHotspotId;

  @override
  Widget build(BuildContext context) {
    if (hotspots.isEmpty) return const SizedBox.shrink();

    final cardH = mobile ? 62.0 : 64.0;
    final cardW = mobile ? 108.0 : 118.0;

    return PremiumGlassPanel(
      padding: EdgeInsets.fromLTRB(
        mobile ? AppSpacing.sm : AppSpacing.md,
        4,
        mobile ? AppSpacing.sm : AppSpacing.md,
        4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kMapPremiumNearestMeresShort,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 11, height: 1.1),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: cardH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hotspots.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final h = hotspots[i];
                return _HotspotPreviewCard(
                  key: Key('hotspot_strip_item_${h.id}'),
                  hotspot: h,
                  selected: selectedHotspotId == h.id,
                  width: cardW,
                  mobile: mobile,
                  onTap: () => onTap(h),
                  scoreFormatter: scoreFormatter,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HotspotPreviewCard extends StatefulWidget {
  const _HotspotPreviewCard({
    super.key,
    required this.hotspot,
    required this.selected,
    required this.width,
    required this.mobile,
    required this.onTap,
    required this.scoreFormatter,
  });

  final Hotspot hotspot;
  final bool selected;
  final double width;
  final bool mobile;
  final VoidCallback onTap;
  final int Function(double score) scoreFormatter;

  @override
  State<_HotspotPreviewCard> createState() => _HotspotPreviewCardState();
}

class _HotspotPreviewCardState extends State<_HotspotPreviewCard> {
  bool _hovered = false;

  Color _classColor(String c) {
    switch (c.toUpperCase()) {
      case 'A':
        return AppColors.accentRed;
      case 'B':
        return AppColors.accentAmber;
      default:
        return AppColors.accentGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hotspot;
    final color = _classColor(h.classification);
    final active = widget.selected || _hovered;
    final score = widget.scoreFormatter(h.score);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.width,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            color: AppColors.surfaceDark.withValues(alpha: active ? 0.72 : 0.5),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.75)
                  : AppColors.borderSoft(alpha: 0.18),
              width: widget.selected ? 1.6 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 12)]
                : null,
          ),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumHeroHotspotBadge(
                  hotspotId: h.id,
                  label: '${h.classification} · #${h.rankByScoreThenDistance}',
                  color: color,
                  compact: true,
                ),
                Text(
                  '$score% · ${h.distanceM.round()} m · ${h.bearingDeg.round()}°',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentTeal,
                    fontSize: 9.5,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
