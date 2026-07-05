import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class LiveAreaSafetyCard extends StatelessWidget {
  const LiveAreaSafetyCard({
    super.key,
    this.trustNote,
  });

  final String? trustNote;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.accentAmber, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(kSafetyTrustTitle, style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumStatusBadge(
            label: kLiveSafetyAdviceBadge,
            tone: PremiumStatusTone.warning,
          ),
          const SizedBox(height: AppSpacing.md),
          _line(kLiveSafetyLineProbabilistic),
          _line(kLiveSafetyLineGpsCalibration),
          _line(kLiveSafetyLineOfficialWarnings),
          if (trustNote != null && trustNote!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(trustNote!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(kTrustSecondaryLine, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _line(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppTextStyles.caption),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
