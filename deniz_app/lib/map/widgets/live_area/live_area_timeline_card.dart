import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

class LiveAreaTimelineCard extends StatelessWidget {
  const LiveAreaTimelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kLiveHowToReadTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          _bullet(kUxFishDetectNoDetect),
          _bullet(kUxLiveGuidanceBasis),
          _bullet(kUxCalibratedRequired),
        ],
      ),
    );
  }

  Widget _bullet(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppTextStyles.caption),
          Expanded(child: Text(line, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
