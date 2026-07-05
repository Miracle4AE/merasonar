import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

Color marinePremiumDecisionColor(String? decision) {
  switch (decision) {
    case 'excellent':
      return AppColors.accentGreen;
    case 'good':
      return AppColors.accentTeal;
    case 'borderline':
      return AppColors.accentAmber;
    case 'poor':
      return AppColors.accentAmber;
    case 'unsafe':
      return AppColors.accentRed;
    default:
      return AppColors.textMuted;
  }
}

String marineDecisionLabelTr(String? decision) {
  switch (decision) {
    case 'excellent':
      return kMarineDecisionExcellent;
    case 'good':
      return kMarineDecisionGood;
    case 'borderline':
      return kMarineDecisionBorderline;
    case 'poor':
      return kMarineDecisionPoor;
    case 'unsafe':
      return kMarineDecisionUnsafe;
    default:
      return kMarineNoData;
  }
}

String marineDecisionBadgeLabelTr(String? decision) {
  switch (decision) {
    case 'excellent':
    case 'good':
      return kMarineLastDecisionSuitable;
    case 'borderline':
      return kMarineLastDecisionBorderline;
    case 'poor':
    case 'unsafe':
      return kMarineLastDecisionRisky;
    default:
      return kMarineNoData;
  }
}

String formatMarineDeltaScore(int? delta) {
  if (delta == null) return '—';
  if (delta > 0) return '+$delta';
  return delta.toString();
}
