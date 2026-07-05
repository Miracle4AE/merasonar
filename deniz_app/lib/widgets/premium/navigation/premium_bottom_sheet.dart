import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

/// Premium glass bottom sheet çerçevesi.
Future<T?> showPremiumBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: PremiumGlassPanel(
          padding: EdgeInsets.zero,
          blur: 22,
          elevation: 1.2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: builder(ctx),
        ),
      );
    },
  );
}

/// Sağdan kayan cinematic panel — hotspot detay overlay.
class CinematicSlidePanel extends StatefulWidget {
  const CinematicSlidePanel({
    super.key,
    required this.width,
    required this.child,
    required this.onDismiss,
  });

  final double width;
  final Widget child;
  final VoidCallback onDismiss;

  @override
  State<CinematicSlidePanel> createState() => _CinematicSlidePanelState();
}

class _CinematicSlidePanelState extends State<CinematicSlidePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _scrim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.panelSlide,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.pageCurve));
    _scrim = CurvedAnimation(parent: _ctrl, curve: AppMotion.pageCurve);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          FadeTransition(
            opacity: _scrim,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: widget.width,
            child: SlideTransition(
              position: _slide,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
