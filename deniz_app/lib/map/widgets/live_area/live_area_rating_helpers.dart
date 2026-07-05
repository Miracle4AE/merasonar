import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

Color liveAreaRatingColor(String rating) {
  switch (rating.trim().toLowerCase()) {
    case 'excellent':
      return AppColors.accentGreen;
    case 'good':
      return AppColors.accentTeal;
    case 'fair':
      return AppColors.accentAmber;
    case 'low':
      return AppColors.accentRed;
    default:
      return AppColors.accentRed;
  }
}

String liveAreaGpsTrustLabel(double? accuracyM) {
  if (accuracyM == null || !accuracyM.isFinite) {
    return kLiveGpsTrustUnknown;
  }
  if (accuracyM <= 15) return kLiveGpsTrustReliable;
  if (accuracyM <= 50) return kLiveGpsTrustMedium;
  return kLiveGpsTrustLow;
}

Color liveAreaGpsTrustColor(double? accuracyM) {
  if (accuracyM == null || !accuracyM.isFinite) {
    return AppColors.textMuted;
  }
  if (accuracyM <= 15) return AppColors.accentGreen;
  if (accuracyM <= 50) return AppColors.accentAmber;
  return AppColors.accentRed;
}
