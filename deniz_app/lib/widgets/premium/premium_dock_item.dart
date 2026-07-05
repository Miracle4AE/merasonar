import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Apple Dock tarzı komut çubuğu ikon öğesi.
class PremiumDockItem extends StatefulWidget {
  const PremiumDockItem({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  State<PremiumDockItem> createState() => _PremiumDockItemState();
}

class _PremiumDockItemState extends State<PremiumDockItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: AppMotion.dockBounce,
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null) return;
    PremiumHaptics.selection();
    setState(() => _pressed = true);
    final motionEnabled =
        mounted && PremiumAnimationPolicy.continuousMotionEnabled(context);
    await _bounce.forward(from: 0);
    if (!mounted) return;
    widget.onPressed!();
    setState(() => _pressed = false);
    if (!motionEnabled) return;
    _bounce.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.accent ? AppColors.borderCyan : AppColors.accentTeal;
    final scale = _pressed ? AppMotion.dockIconActiveScale : 1.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.microPress,
        curve: AppMotion.releaseCurve,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: enabled ? 0.14 : 0.06),
                    border: Border.all(
                      color: color.withValues(alpha: enabled ? 0.35 : 0.12),
                    ),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.18),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(widget.icon, size: 20, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
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
