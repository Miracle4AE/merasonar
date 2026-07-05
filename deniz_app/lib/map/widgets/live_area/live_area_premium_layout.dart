import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:flutter/material.dart';

/// Canlı Alan premium responsive gövde.
class LiveAreaPremiumLayout extends StatelessWidget {
  const LiveAreaPremiumLayout({
    super.key,
    required this.header,
    required this.scoreCard,
    required this.gpsCard,
    required this.hotspotCard,
    required this.captainCard,
    required this.howToReadCard,
    required this.safetyCard,
  });

  final Widget header;
  final Widget scoreCard;
  final Widget gpsCard;
  final Widget hotspotCard;
  final Widget captainCard;
  final Widget howToReadCard;
  final Widget safetyCard;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final padding = EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.screenPadding,
      AppSpacing.screenPadding,
      AppSpacing.screenPadding + bottomPad,
    );

    if (useMobileLayout(context)) {
      return ListView(
        padding: padding,
        children: [
          header,
          const SizedBox(height: AppSpacing.sectionGap),
          scoreCard,
          const SizedBox(height: AppSpacing.gridGap),
          gpsCard,
          const SizedBox(height: AppSpacing.gridGap),
          hotspotCard,
          const SizedBox(height: AppSpacing.gridGap),
          captainCard,
          const SizedBox(height: AppSpacing.gridGap),
          howToReadCard,
          const SizedBox(height: AppSpacing.gridGap),
          safetyCard,
        ],
      );
    }

    if (useDesktopLayout(context)) {
      return ListView(
        padding: padding,
        children: [
          header,
          const SizedBox(height: AppSpacing.sectionGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      gpsCard,
                      const SizedBox(height: AppSpacing.gridGap),
                      howToReadCard,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.gridGap),
                Expanded(flex: 2, child: scoreCard),
                const SizedBox(width: AppSpacing.gridGap),
                Expanded(
                  child: Column(
                    children: [
                      hotspotCard,
                      const SizedBox(height: AppSpacing.gridGap),
                      captainCard,
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          safetyCard,
        ],
      );
    }

    // Tablet — 2 kolon
    return ListView(
      padding: padding,
      children: [
        header,
        const SizedBox(height: AppSpacing.sectionGap),
        scoreCard,
        const SizedBox(height: AppSpacing.gridGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: gpsCard),
            const SizedBox(width: AppSpacing.gridGap),
            Expanded(child: hotspotCard),
          ],
        ),
        const SizedBox(height: AppSpacing.gridGap),
        captainCard,
        const SizedBox(height: AppSpacing.gridGap),
        howToReadCard,
        const SizedBox(height: AppSpacing.gridGap),
        safetyCard,
      ],
    );
  }
}
