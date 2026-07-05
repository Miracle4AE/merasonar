import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Premium dünya haritası hotspot marker — yalnızca görsel katman.
class PremiumMapMarker extends StatelessWidget {
  const PremiumMapMarker({
    super.key,
    required this.scoreLabel,
    required this.color,
    required this.scoreText,
    required this.focused,
    required this.topTier,
    required this.pulse,
    this.badgeLabel,
    this.approximate = false,
    this.compact = false,
    this.onTap,
  });

  final String scoreLabel;
  final Color color;
  final String scoreText;
  final bool focused;
  final bool topTier;
  final double pulse;
  final String? badgeLabel;
  final bool approximate;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeLabel != null && badgeLabel!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: AppRadius.chip,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentAmber.withValues(alpha: 0.92),
                    const Color(0xFFD4C49A).withValues(alpha: 0.9),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentAmber.withValues(
                      alpha: 0.28 + pulse * 0.15,
                    ),
                    blurRadius: 5 + pulse * 8,
                  ),
                ],
              ),
              child: Text(
                badgeLabel!,
                style: const TextStyle(
                  color: Color(0xFF1A237E),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (focused)
                  Container(
                    width: 62 + pulse * 18,
                    height: 62 + pulse * 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.55 + pulse * 0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35 + pulse * 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                if (topTier)
                  Container(
                    width: 54 + pulse * 22,
                    height: 54 + pulse * 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.22 + pulse * 0.2),
                          blurRadius: 12 + pulse * 16,
                          spreadRadius: 1 + pulse * 5,
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: focused ? (compact ? 44 : 50) : (compact ? 40 : 46),
                  height: focused ? (compact ? 44 : 50) : (compact ? 40 : 46),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: focused ? 0.22 : 0.14),
                    border: Border.all(
                      color: focused
                          ? AppColors.textPrimary.withValues(alpha: 0.92)
                          : (approximate
                              ? AppColors.accentAmber.withValues(alpha: 0.75)
                              : color.withValues(alpha: 0.88)),
                      width: focused ? 2.6 : (topTier ? 2.2 : 1.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: focused ? 10 : 6,
                        offset: const Offset(0, 2),
                      ),
                      if (focused)
                        BoxShadow(
                          color: color.withValues(alpha: 0.35 + pulse * 0.15),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      scoreText,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: topTier ? 13 : 12,
                      ),
                    ),
                  ),
                ),
                if (approximate)
                  const Positioned(
                    top: -4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xCCFF9800),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Text(
                          '≈',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDeep.withValues(alpha: 0.88),
                      borderRadius: AppRadius.chip,
                      border: Border.all(
                        color: AppColors.borderSoft(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      scoreLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class PremiumMapClusterMarker extends StatelessWidget {
  const PremiumMapClusterMarker({
    super.key,
    required this.countLabel,
    required this.approximate,
    this.onTap,
  });

  final String countLabel;
  final bool approximate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceDark.withValues(alpha: 0.88),
              border: Border.all(
                color: approximate
                    ? AppColors.accentAmber.withValues(alpha: 0.75)
                    : AppColors.accentTeal.withValues(alpha: 0.55),
                width: approximate ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.glowTeal(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                countLabel,
                style: AppTextStyles.buttonLabel.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
