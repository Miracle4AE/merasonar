import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Chart overlay hotspot marker — kompakt premium görsel katman.
class ChartOverlayPremiumMarker extends StatelessWidget {
  const ChartOverlayPremiumMarker({
    super.key,
    required this.scoreText,
    required this.scoreLabel,
    required this.color,
    required this.focused,
    required this.topTier,
    required this.pulse,
    this.badgeLabel,
    this.compact = false,
    this.onTap,
  });

  final String scoreText;
  final String scoreLabel;
  final Color color;
  final bool focused;
  final bool topTier;
  final double pulse;
  final String? badgeLabel;
  final bool compact;
  final VoidCallback? onTap;

  double get _coreSize => compact ? (focused ? 34.0 : 30.0) : (focused ? 40.0 : 36.0);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeLabel != null && badgeLabel!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 5 : 7,
                vertical: compact ? 2 : 3,
              ),
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
                      alpha: 0.22 + pulse * 0.12,
                    ),
                    blurRadius: 4 + pulse * 6,
                  ),
                ],
              ),
              child: Text(
                badgeLabel!,
                style: TextStyle(
                  color: const Color(0xFF1A237E),
                  fontSize: compact ? 8 : 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (topTier)
                  Container(
                    width: _coreSize + 14 + pulse * (compact ? 10 : 16),
                    height: _coreSize + 14 + pulse * (compact ? 10 : 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2 + pulse * 0.18),
                          blurRadius: 8 + pulse * 12,
                          spreadRadius: 0.5 + pulse * 3,
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: _coreSize,
                  height: _coreSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.backgroundDeep.withValues(alpha: 0.82),
                    border: Border.all(
                      color: focused
                          ? AppColors.textPrimary.withValues(alpha: 0.92)
                          : color,
                      width: focused ? 2.4 : (topTier ? 2 : 1.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35 + pulse * 0.15),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      scoreText,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 10 : 11,
                      ),
                    ),
                  ),
                ),
                if (!compact)
                  Positioned(
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDeep.withValues(alpha: 0.9),
                        borderRadius: AppRadius.chip,
                        border: Border.all(
                          color: AppColors.borderSoft(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        scoreLabel,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
