import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_live_glow.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

class PremiumEmptyState extends StatefulWidget {
  const PremiumEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<PremiumEmptyState> createState() => _PremiumEmptyStateState();
}

class _PremiumEmptyStateState extends State<PremiumEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _float.stop();
      _float.value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = !PremiumAnimationPolicy.continuousMotionEnabled(context);

    return PremiumCard(
      glow: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PremiumLiveGlow(
            enabled: !disableMotion,
            intensity: 0.6,
            child: disableMotion
                ? Icon(
                    widget.icon,
                    size: 34,
                    color: AppColors.accentTeal.withValues(alpha: 0.85),
                  )
                : AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -3 * _float.value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentTeal.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 34,
                        color: AppColors.accentTeal.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: AppTextStyles.heroTitle.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: AppTextStyles.bodyPremium,
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: 16),
            PremiumPrimaryButton(
              label: widget.actionLabel!,
              onPressed: widget.onAction,
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}
