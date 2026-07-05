import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Captain Atlas açılış sekansı: avatar büyür → kart → typing → içerik.
class CaptainAtlasCinematicOpening extends StatefulWidget {
  const CaptainAtlasCinematicOpening({
    super.key,
    required this.child,
    this.title = kAiAssistantTitle,
    this.loading = false,
  });

  final Widget child;
  final String title;
  final bool loading;

  @override
  State<CaptainAtlasCinematicOpening> createState() =>
      _CaptainAtlasCinematicOpeningState();
}

class _CaptainAtlasCinematicOpeningState extends State<CaptainAtlasCinematicOpening>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final Animation<double> _avatarScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;
  late final AnimationController _typing;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _avatarScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _seq,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _seq,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _seq,
        curve: const Interval(0.25, 0.75, curve: AppMotion.pageCurve),
      ),
    );
    _typing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _seq.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showContent = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      if (!_seq.isAnimating && _seq.value == 0) _seq.forward();
      if (widget.loading && !_typing.isAnimating) _typing.repeat();
    } else {
      _seq.value = 1;
      _showContent = true;
    }
  }

  @override
  void dispose() {
    _seq.dispose();
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = PremiumAnimationPolicy.continuousMotionEnabled(context);
    if (!motion) return widget.child;

    if (_showContent) return widget.child;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _avatarScale,
          child: const PremiumHeroCaptainAvatar(size: 64),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeTransition(
          opacity: _cardOpacity,
          child: SlideTransition(
            position: _cardSlide,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceElevated.withValues(alpha: 0.9),
                    AppColors.backgroundNavy.withValues(alpha: 0.85),
                  ],
                ),
                border: Border.all(
                  color: AppColors.borderCyan.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(widget.title, style: AppTextStyles.heroTitle),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.loading)
                    _TypingDots(animation: _typing)
                  else
                    Text(
                      kPremiumCaptainReady,
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = ((animation.value * 3) + i) % 3;
            final alpha = phase < 1 ? 0.35 + phase * 0.55 : 0.35;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
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
