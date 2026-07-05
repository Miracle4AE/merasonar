import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:flutter/material.dart';

/// Async bölüm güvenli sarmalayıcı — yükleme / hata / içerik.
class SafeAsyncSection extends StatelessWidget {
  const SafeAsyncSection({
    super.key,
    required this.child,
    this.loading = false,
    this.error,
    this.onRetry,
    this.loadingHeight = 120,
    this.errorTitle = kPremiumSectionErrorTitle,
  });

  final Widget child;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final double loadingHeight;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return PremiumLoadingSkeleton(height: loadingHeight);
    }
    if (error != null && error!.trim().isNotEmpty) {
      return PremiumErrorFallback(
        title: errorTitle,
        message: error,
        onRetry: onRetry,
      );
    }
    return child;
  }
}
