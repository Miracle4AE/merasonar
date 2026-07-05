import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_live_glow.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

enum CaptainAtlasPresence {
  ready,
  thinking,
  responding,
}

/// Captain Atlas — uygulamanın yıldız kartı.
class CaptainAtlasHeroCard extends StatefulWidget {
  const CaptainAtlasHeroCard({
    super.key,
    required this.title,
    required this.body,
    this.presence = CaptainAtlasPresence.ready,
    this.onAsk,
    this.actionLabel,
    this.actionKey,
    this.loading = false,
    this.enabled = true,
    this.badges = const [],
    this.useHeroAvatar = false,
    this.compactSidebar = false,
  });

  final String title;
  final String body;
  final CaptainAtlasPresence presence;
  final VoidCallback? onAsk;
  final String? actionLabel;
  final Key? actionKey;
  final bool loading;
  final bool enabled;
  final List<Widget> badges;
  /// Sidebar → Captain Atlas geçişi için tek Hero kaynağı; diğer kartlarda false.
  final bool useHeroAvatar;
  /// Dar sidebar (172px) için kompakt düzen — başlık kırılmasını önler.
  final bool compactSidebar;

  @override
  State<CaptainAtlasHeroCard> createState() => _CaptainAtlasHeroCardState();
}

class _CaptainAtlasHeroCardState extends State<CaptainAtlasHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing;

  @override
  void initState() {
    super.initState();
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTyping();
  }

  @override
  void didUpdateWidget(covariant CaptainAtlasHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTyping();
  }

  void _syncTyping() {
    final disableMotion = !PremiumAnimationPolicy.continuousMotionEnabled(context);
    final active = !disableMotion &&
        (widget.presence == CaptainAtlasPresence.thinking || widget.loading);
    if (active) {
      _typing.repeat();
    } else {
      _typing.stop();
      _typing.value = 0;
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  String get _statusLabel {
    if (widget.loading || widget.presence == CaptainAtlasPresence.thinking) {
      return kPremiumCaptainThinking;
    }
    if (widget.presence == CaptainAtlasPresence.responding) {
      return kPremiumCaptainResponding;
    }
    return kPremiumCaptainReady;
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = !PremiumAnimationPolicy.continuousMotionEnabled(context);
    final mini = widget.compactSidebar;

    return PremiumLiveGlow(
      enabled: widget.enabled && !disableMotion,
      color: AppColors.borderCyan,
      intensity: mini ? 0.55 : 0.9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(mini ? 12 : 16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceElevated.withValues(alpha: 0.95),
              const Color(0xFF0A2840).withValues(alpha: 0.92),
              AppColors.backgroundNavy.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: AppColors.borderCyan.withValues(alpha: mini ? 0.22 : 0.35),
          ),
        ),
        padding: EdgeInsets.all(mini ? AppSpacing.sm : AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarRing(
                  presence: widget.presence,
                  loading: widget.loading,
                  useHero: widget.useHeroAvatar,
                  size: mini ? 36 : 52,
                ),
                SizedBox(width: mini ? AppSpacing.sm : AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: (mini
                                ? AppTextStyles.cardTitle
                                : AppTextStyles.heroTitle)
                            .copyWith(fontSize: mini ? 11.5 : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: mini ? 10 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.badges.isNotEmpty && !mini) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: widget.badges,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: mini ? AppSpacing.sm : AppSpacing.md),
            AnimatedSwitcher(
              duration: AppMotion.hover,
              child: widget.loading || widget.presence == CaptainAtlasPresence.thinking
                  ? _TypingDots(key: ValueKey(widget.presence), animation: _typing)
                  : Text(
                      widget.body,
                      key: ValueKey(widget.body),
                      style: AppTextStyles.bodyPremium.copyWith(
                        fontSize: mini ? 11 : null,
                        height: 1.3,
                      ),
                      maxLines: mini ? 2 : 6,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (widget.actionLabel != null && widget.onAsk != null) ...[
              SizedBox(height: mini ? AppSpacing.sm : AppSpacing.md),
              if (mini)
                TextButton.icon(
                  key: widget.actionKey,
                  onPressed: (!widget.enabled || widget.loading)
                      ? null
                      : () {
                          PremiumHaptics.medium();
                          widget.onAsk?.call();
                        },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: Text(
                    widget.actionLabel!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentTeal,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: widget.actionKey,
                    onPressed: (!widget.enabled || widget.loading)
                        ? null
                        : () {
                            PremiumHaptics.medium();
                            widget.onAsk?.call();
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(widget.actionLabel!),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentTeal.withValues(alpha: 0.22),
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({
    required this.presence,
    required this.loading,
    required this.useHero,
    this.size = 52,
  });

  final CaptainAtlasPresence presence;
  final bool loading;
  final bool useHero;
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = loading || presence != CaptainAtlasPresence.ready;
    return PremiumLiveGlow(
      enabled: true,
      intensity: active ? 1.0 : 0.55,
      color: AppColors.borderCyan,
      child: PremiumHeroCaptainAvatar(size: size, useHero: useHero),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          children: List.generate(3, (i) {
            final phase = ((animation.value * 3) + i) % 3;
            final alpha = phase < 1 ? 0.35 + phase * 0.55 : 0.35;
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTeal.withValues(alpha: alpha),
              ),
            );
          }),
        );
      },
    );
  }
}
