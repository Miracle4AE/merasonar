import 'package:deniz_app/navigation/premium_hero_tags.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class PremiumHeroGoScore extends StatelessWidget {
  const PremiumHeroGoScore({
    super.key,
    required this.score,
    this.color,
    this.fontSize = 48,
  });

  final int score;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Go Score',
      value: '$score',
      child: Hero(
        tag: PremiumHeroTags.goScore,
        flightShuttleBuilder: (ctx, anim, dir, from, to) {
          return ScaleTransition(
            scale: anim.drive(Tween<double>(begin: 0.85, end: 1)),
            child: to.widget,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Text(
            '$score',
            style: AppTextStyles.metricNumber.copyWith(
              color: color ?? AppColors.textPrimary,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumHeroCaptainAvatar extends StatelessWidget {
  const PremiumHeroCaptainAvatar({
    super.key,
    this.size = 52,
    this.useHero = true,
  });

  final double size;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final avatar = _CaptainAvatarVisual(size: size);
    if (!useHero) return avatar;
    return Hero(
      tag: PremiumHeroTags.captainAvatar,
      child: Material(
        color: Colors.transparent,
        child: avatar,
      ),
    );
  }
}

class _CaptainAvatarVisual extends StatelessWidget {
  const _CaptainAvatarVisual({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.borderCyan.withValues(alpha: 0.85),
            AppColors.accentTeal.withValues(alpha: 0.55),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2.5),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundNavy,
        ),
        child: Icon(
          Icons.sailing_rounded,
          color: AppColors.accentTeal,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class PremiumHeroHotspotBadge extends StatelessWidget {
  const PremiumHeroHotspotBadge({
    super.key,
    required this.hotspotId,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final int hotspotId;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: PremiumHeroTags.hotspot(hotspotId),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 8 : 10),
            color: color.withValues(alpha: 0.18),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Text(
            label,
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: compact ? 11 : 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumHeroCompareIcon extends StatelessWidget {
  const PremiumHeroCompareIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: PremiumHeroTags.compare,
      child: Material(
        color: Colors.transparent,
        child: Icon(Icons.compare_arrows_rounded, color: AppColors.accentTeal, size: size),
      ),
    );
  }
}

class PremiumHeroSavedSpotIcon extends StatelessWidget {
  const PremiumHeroSavedSpotIcon({
    super.key,
    required this.spotId,
    required this.favorite,
  });

  final String spotId;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: PremiumHeroTags.savedSpot(spotId),
      child: Material(
        color: Colors.transparent,
        child: Icon(
          favorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          color: favorite ? AppColors.accentAmber : AppColors.accentTeal,
          size: 22,
        ),
      ),
    );
  }
}
