import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:flutter/material.dart';

enum PremiumToastType { success, error, info, offline }

/// Premium floating toast — SnackBar yerine.
abstract final class PremiumToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    PremiumToastType type = PremiumToastType.info,
    Duration? duration,
  }) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _PremiumToastHost(
        message: message,
        type: type,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _hapticFor(type);

    Future<void>.delayed(duration ?? AppMotion.toastVisible, () {
      if (entry.mounted) {
        entry.remove();
        if (_current == entry) _current = null;
      }
    });
  }

  static void _hapticFor(PremiumToastType type) {
    switch (type) {
      case PremiumToastType.success:
        PremiumHaptics.success();
      case PremiumToastType.error:
        PremiumHaptics.error();
      case PremiumToastType.offline:
        PremiumHaptics.warning();
      case PremiumToastType.info:
        PremiumHaptics.light();
    }
  }

  static void success(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: PremiumToastType.success, duration: duration);
  }

  static void error(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: PremiumToastType.error, duration: duration);
  }

  static void info(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: PremiumToastType.info, duration: duration);
  }

  static void offline(BuildContext context, String message, {Duration? duration}) {
    show(context, message, type: PremiumToastType.offline, duration: duration);
  }
}

class _PremiumToastHost extends StatefulWidget {
  const _PremiumToastHost({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final PremiumToastType type;
  final VoidCallback onDismiss;

  @override
  State<_PremiumToastHost> createState() => _PremiumToastHostState();
}

class _PremiumToastHostState extends State<_PremiumToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.releaseCurve));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case PremiumToastType.success:
        return Icons.check_circle_rounded;
      case PremiumToastType.error:
        return Icons.error_outline_rounded;
      case PremiumToastType.offline:
        return Icons.cloud_off_rounded;
      case PremiumToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get _accent {
    switch (widget.type) {
      case PremiumToastType.success:
        return AppColors.accentGreen;
      case PremiumToastType.error:
        return AppColors.accentRed;
      case PremiumToastType.offline:
        return AppColors.accentAmber;
      case PremiumToastType.info:
        return AppColors.accentTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: PremiumGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                blur: 18,
                borderRadius: AppRadius.panel,
                child: Row(
                  children: [
                    Icon(_icon, color: _accent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTextStyles.bodyPremium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await _ctrl.reverse();
                        widget.onDismiss();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SnackBar → PremiumToast kolay geçiş.
extension PremiumToastContext on BuildContext {
  void showPremiumToast(
    String message, {
    PremiumToastType type = PremiumToastType.info,
    Duration? duration,
  }) {
    PremiumToast.show(this, message, type: type, duration: duration);
  }

  void showPremiumSuccess(String message, {Duration? duration}) {
    PremiumToast.success(this, message, duration: duration);
  }

  void showPremiumError(String message, {Duration? duration}) {
    PremiumToast.error(this, message, duration: duration);
  }

  void showPremiumOffline(String message, {Duration? duration}) {
    PremiumToast.offline(this, message, duration: duration);
  }
}
