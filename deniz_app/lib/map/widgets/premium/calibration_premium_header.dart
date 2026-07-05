import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

enum CalibrationPremiumStep {
  pickPoint,
  enterCoordinate,
  verify,
  apply,
}

class CalibrationPremiumHeader extends StatelessWidget {
  const CalibrationPremiumHeader({
    super.key,
    required this.currentStep,
    required this.validGeoCount,
    required this.manualPixelCount,
    required this.ready,
    this.reliabilityLabel,
    this.reliabilityTone = PremiumStatusTone.neutral,
  });

  final CalibrationPremiumStep currentStep;
  final int validGeoCount;
  final int manualPixelCount;
  final bool ready;
  final String? reliabilityLabel;
  final PremiumStatusTone reliabilityTone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(kCalibSheetTitle, style: AppTextStyles.sectionTitle),
            ),
            if (reliabilityLabel != null)
              PremiumStatusBadge(
                label: reliabilityLabel!,
                tone: reliabilityTone,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(kCalibIntroShort, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.md),
        _StepIndicator(currentStep: currentStep),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${kCalibProgressPoints(validGeoCount)} · $manualPixelCount piksel işaretlendi',
          style: AppTextStyles.caption.copyWith(
            color: ready ? AppColors.accentGreen : AppColors.textSecondary,
            fontWeight: ready ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final CalibrationPremiumStep currentStep;

  static const _steps = [
    (CalibrationPremiumStep.pickPoint, kMapCalibStepPick),
    (CalibrationPremiumStep.enterCoordinate, kMapCalibStepCoordinate),
    (CalibrationPremiumStep.verify, kMapCalibStepVerify),
    (CalibrationPremiumStep.apply, kMapCalibStepApply),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _steps.indexWhere((s) => s.$1 == currentStep).clamp(0, 3);
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= activeIndex
                    ? AppColors.accentTeal.withValues(alpha: 0.6)
                    : AppColors.borderSoft(alpha: 0.15),
              ),
            ),
          _StepDot(
            index: i + 1,
            label: _steps[i].$2,
            active: i == activeIndex,
            done: i < activeIndex,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.accentGreen
        : active
            ? AppColors.accentTeal
            : AppColors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (active || done)
                ? color.withValues(alpha: 0.2)
                : AppColors.surfaceElevated.withValues(alpha: 0.4),
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, size: 14, color: color)
                : Text(
                    '$index',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: active ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

CalibrationPremiumStep resolveCalibrationStep({
  required int validGeoCount,
  required int manualPixelCount,
  required bool ready,
  required int? activePickIndex,
}) {
  if (ready) return CalibrationPremiumStep.apply;
  if (activePickIndex != null) return CalibrationPremiumStep.pickPoint;
  if (validGeoCount >= 1 && manualPixelCount < validGeoCount) {
    return CalibrationPremiumStep.verify;
  }
  if (validGeoCount > 0) return CalibrationPremiumStep.enterCoordinate;
  return CalibrationPremiumStep.pickPoint;
}

String? calibrationReliabilityLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  switch (raw.trim().toLowerCase()) {
    case 'excellent':
    case 'good':
      return kMapCalibReliabilityGood;
    case 'approximate':
    case 'fair':
      return kMapCalibReliabilityMedium;
    case 'unsafe':
    case 'poor':
      return kMapCalibReliabilityLow;
    default:
      return raw;
  }
}

PremiumStatusTone calibrationReliabilityTone(String? raw) {
  if (raw == null) return PremiumStatusTone.neutral;
  switch (raw.trim().toLowerCase()) {
    case 'excellent':
    case 'good':
      return PremiumStatusTone.success;
    case 'approximate':
    case 'fair':
      return PremiumStatusTone.warning;
    case 'unsafe':
    case 'poor':
      return PremiumStatusTone.danger;
    default:
      return PremiumStatusTone.neutral;
  }
}
