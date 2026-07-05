import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AiAssistantDockInput extends StatelessWidget {
  const AiAssistantDockInput({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.sm),
      blur: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: kAiAssistantMaxUserQuestionLength,
              maxLines: 3,
              minLines: 1,
              style: AppTextStyles.bodyPremium.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: kAiAssistantQuestionHint,
                hintStyle: AppTextStyles.caption,
                border: InputBorder.none,
                counterStyle: AppTextStyles.caption,
                isDense: true,
              ),
              onSubmitted: (_) {
                PremiumHaptics.selection();
                onSubmit();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: kAiAssistantQuestionSubmit,
            enabled: !loading,
            child: FilledButton(
              onPressed: loading
                  ? null
                  : () {
                      PremiumHaptics.light();
                      onSubmit();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentTeal.withValues(alpha: 0.22),
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class AiAssistantStatusChips extends StatelessWidget {
  const AiAssistantStatusChips({
    super.key,
    this.isFallback = false,
    this.fallbackReason,
    this.cacheHit = false,
    this.model,
    this.remainingQuota,
    this.isPremium = false,
  });

  final bool isFallback;
  final String? fallbackReason;
  final bool cacheHit;
  final String? model;
  final int? remainingQuota;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (isFallback) chips.add(_Chip(label: kAiAssistantFallbackBanner, accent: true));
    if (kDebugMode && isFallback && fallbackReason != null && fallbackReason!.isNotEmpty) {
      chips.add(_Chip(label: kAiAssistantFallbackReasonDebug(fallbackReason)));
    }
    if (cacheHit) chips.add(_Chip(label: kAiAssistantCacheBadge));
    if (model != null && model!.trim().isNotEmpty) {
      chips.add(_Chip(label: model!.trim()));
    }
    if (remainingQuota != null) {
      chips.add(_Chip(label: kAiAssistantQuotaBadgeFmt(remainingQuota!)));
    }
    if (isPremium) chips.add(_Chip(label: kAiAssistantProBadge, accent: true));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.accentAmber : AppColors.accentTeal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
