import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:flutter/material.dart';

/// Koordinat Deniz Analizi premium responsive gövde.
class MarineIntelligencePremiumLayout extends StatelessWidget {
  const MarineIntelligencePremiumLayout({
    super.key,
    required this.header,
    required this.coordinatePanel,
    required this.savedSpots,
    required this.centerColumn,
    required this.rightColumn,
    this.bottomSection,
    this.refreshAiToggle,
  });

  final Widget header;
  final Widget coordinatePanel;
  final Widget savedSpots;
  final Widget centerColumn;
  final Widget rightColumn;
  final Widget? bottomSection;
  final Widget? refreshAiToggle;

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
          coordinatePanel,
          const SizedBox(height: AppSpacing.gridGap),
          centerColumn,
          const SizedBox(height: AppSpacing.gridGap),
          rightColumn,
          if (bottomSection != null) ...[
            const SizedBox(height: AppSpacing.gridGap),
            bottomSection!,
          ],
          if (refreshAiToggle != null) ...[
            const SizedBox(height: AppSpacing.gridGap),
            refreshAiToggle!,
          ],
          const SizedBox(height: AppSpacing.gridGap),
          savedSpots,
        ],
      );
    }

    if (useDesktopLayout(context)) {
      return ListView(
        padding: padding,
        children: [
          header,
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    coordinatePanel,
                    const SizedBox(height: AppSpacing.gridGap),
                    savedSpots,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 2, child: centerColumn),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(child: rightColumn),
            ],
          ),
          if (bottomSection != null) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            bottomSection!,
          ],
          if (refreshAiToggle != null) ...[
            const SizedBox(height: AppSpacing.gridGap),
            refreshAiToggle!,
          ],
        ],
      );
    }

    // Tablet — 2 kolon
    return ListView(
      padding: padding,
      children: [
        header,
        const SizedBox(height: AppSpacing.sectionGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  coordinatePanel,
                  const SizedBox(height: AppSpacing.gridGap),
                  savedSpots,
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.gridGap),
            Expanded(
              child: Column(
                children: [
                  centerColumn,
                  const SizedBox(height: AppSpacing.gridGap),
                  rightColumn,
                ],
              ),
            ),
          ],
        ),
        if (bottomSection != null) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          bottomSection!,
        ],
        if (refreshAiToggle != null) ...[
          const SizedBox(height: AppSpacing.gridGap),
          refreshAiToggle!,
        ],
      ],
    );
  }
}
