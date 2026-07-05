import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:deniz_app/widgets/premium/settings/premium_performance_mode_tile.dart';
import 'package:flutter/material.dart';

/// Kompakt performans modu seçici — Dashboard V2 üst şerit.
class DashboardV2PerformanceModeButton extends StatelessWidget {
  const DashboardV2PerformanceModeButton({super.key});

  IconData _iconFor(PremiumPerformanceMode mode) {
    return switch (mode) {
      PremiumPerformanceMode.full => Icons.speed_rounded,
      PremiumPerformanceMode.balanced => Icons.tune_rounded,
      PremiumPerformanceMode.batterySaver => Icons.battery_saver_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mode = PremiumPerformanceScope.of(context);

    return PopupMenuButton<PremiumPerformanceMode>(
      key: const Key('btn_performance_mode'),
      tooltip: kPremiumPerformanceModeTitle,
      padding: EdgeInsets.zero,
      icon: Icon(_iconFor(mode), size: 20, color: AppColors.textMuted),
      onSelected: (m) => PremiumPerformanceScope.setMode(context, m),
      itemBuilder: (context) {
        return PremiumPerformanceMode.values.map((m) {
          return PopupMenuItem<PremiumPerformanceMode>(
            value: m,
            child: Row(
              children: [
                Icon(
                  _iconFor(m),
                  size: 18,
                  color: mode == m ? AppColors.accentTeal : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PremiumPerformanceModeTile.labelFor(m),
                    style: TextStyle(
                      fontWeight:
                          mode == m ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (mode == m)
                  Icon(Icons.check, size: 16, color: AppColors.accentTeal),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
