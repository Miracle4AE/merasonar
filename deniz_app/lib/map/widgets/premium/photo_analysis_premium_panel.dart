import 'dart:io';

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class PhotoAnalysisPremiumPanel extends StatelessWidget {
  const PhotoAnalysisPremiumPanel({
    super.key,
    this.chips = const [],
    this.historyNote,
    required this.child,
    this.showHeader = false,
    this.header,
    this.warning,
  });

  final List<Widget> chips;
  final String? historyNote;
  final Widget child;
  final bool showHeader;
  final Widget? header;
  final Widget? warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (warning != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: warning!,
          ),
        ],
        if (showHeader && header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header!,
                if (historyNote != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text(historyNote!, style: AppTextStyles.caption),
                  ),
                ],
              ],
            ),
          )
        else if (chips.isNotEmpty || historyNote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kMapPremiumPhotoTitle, style: AppTextStyles.cardTitle),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: chips,
                    ),
                  ],
                  if (historyNote != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(historyNote!, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class PhotoAnalysisUploadCard extends StatelessWidget {
  const PhotoAnalysisUploadCard({
    super.key,
    required this.message,
    required this.onScan,
    this.onPickFile,
    this.busy = false,
    this.previewPath,
  });

  final String message;
  final VoidCallback? onScan;
  final VoidCallback? onPickFile;
  final bool busy;
  final String? previewPath;

  @override
  Widget build(BuildContext context) {
    final previewFile = previewPath != null && File(previewPath!).existsSync()
        ? File(previewPath!)
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: PremiumCard(
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PremiumStatusBadge(label: kMapTabPhotoAnalysis),
              const SizedBox(height: AppSpacing.md),
              Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: AppColors.accentTeal.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  color: AppColors.surfaceElevated.withValues(alpha: 0.35),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: AppColors.accentTeal.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      kMapPhotoUploadDropHint,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      kMapPhotoUploadFormats,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (previewFile != null) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.card,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(
                      previewFile,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  kMapChartPreviewLabel,
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.1),
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: AppColors.accentAmber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.accentAmber,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        kMapPhotoUploadHint,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentAmber.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumPrimaryButton(
                label: busy ? kMapFabScanning : kMapPremiumPhotoUpload,
                icon: Icons.document_scanner_outlined,
                onPressed: busy ? null : onScan,
                expanded: true,
              ),
              if (onPickFile != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PremiumPrimaryButton(
                  label: kMapChartOverlayCmdAnalyze,
                  icon: Icons.folder_open_outlined,
                  onPressed: busy ? null : onPickFile,
                  expanded: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoAnalysisModeChip extends StatelessWidget {
  const PhotoAnalysisModeChip({
    super.key,
    required this.label,
    this.warning = false,
  });

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return PremiumStatusBadge(
      label: label,
      tone: warning ? PremiumStatusTone.warning : PremiumStatusTone.neutral,
    );
  }
}
