import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/hotspot_detail_sheet.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_bottom_sheet.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

/// Sağdan kayan hotspot detay paneli — cinematic slide + Hero.
class MapHotspotDetailPanel extends StatelessWidget {
  const MapHotspotDetailPanel({
    super.key,
    required this.hotspot,
    required this.onClose,
    required this.detailSheet,
    this.captainSummary,
    this.onGo,
    this.onCompare,
    this.onSave,
    this.embedded = false,
  });

  final Hotspot hotspot;
  final VoidCallback onClose;
  final HotspotDetailSheet detailSheet;
  final String? captainSummary;
  final VoidCallback? onGo;
  final VoidCallback? onCompare;
  final VoidCallback? onSave;
  final bool embedded;

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
    final mobile = useMobileLayout(context);
    final width = embedded
        ? double.infinity
        : (mobile
            ? MediaQuery.sizeOf(context).width * 0.92
            : 400.0);

    final panel = SizedBox(
      width: embedded ? null : width,
      child: PremiumGlassPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PremiumHeroHotspotBadge(
                          hotspotId: hotspot.id,
                          label:
                              '${hotspot.classification} · #${hotspot.rankByScoreThenDistance}',
                          color: _classColor(hotspot.classification),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: kDialogClose,
                        child: IconButton(
                          key: const Key('btn_close_hotspot_detail'),
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textSecondary,
                          tooltip: kDialogClose,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    kMapPremiumHotspotScoreDepthFmt(
                      (hotspot.score * 100).round(),
                      hotspot.confirmedDepth.depthM?.toStringAsFixed(0) ?? '—',
                      hotspot.distanceM.round(),
                    ),
                    style: AppTextStyles.caption,
                  ),
                  if (captainSummary != null &&
                      captainSummary!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      captainSummary!,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Semantics(
                        button: true,
                        label: kMapPremiumHotspotGo,
                        child: PremiumPrimaryButton(
                          label: kMapPremiumHotspotGo,
                          icon: Icons.navigation_outlined,
                          onPressed: onGo,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: kMarineCompareButton,
                        child: PremiumPrimaryButton(
                          label: kMarineCompareButton,
                          icon: Icons.compare_arrows,
                          onPressed: onCompare,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: kMarineSaveSpot,
                        child: PremiumPrimaryButton(
                          label: kMarineSaveSpot,
                          icon: Icons.bookmark_add_outlined,
                          onPressed: onSave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(child: detailSheet),
          ],
        ),
      ),
    );

    if (embedded) {
      return Material(
        color: AppColors.backgroundDeep,
        child: panel,
      );
    }

    return CinematicSlidePanel(
      width: width,
      onDismiss: onClose,
      child: panel,
    );
  }
}
