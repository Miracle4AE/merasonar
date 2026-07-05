import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

/// Kullanıcı dostu hata kartı — global try/catch yerine bölüm fallback.
class PremiumErrorFallback extends StatelessWidget {
  const PremiumErrorFallback({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.accentAmber),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppTextStyles.cardTitle),
              ),
            ],
          ),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message!, style: AppTextStyles.caption, maxLines: 4),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            PremiumPrimaryButton(
              label: kPremiumDashRefresh,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Build-time hatalarında kullanıcı dostu fallback — hataları yutma.
class PremiumErrorBoundary extends StatefulWidget {
  const PremiumErrorBoundary({
    super.key,
    required this.sectionTitle,
    required this.builder,
    this.onRetry,
  });

  final String sectionTitle;
  final Widget Function(BuildContext context) builder;
  final VoidCallback? onRetry;

  @override
  State<PremiumErrorBoundary> createState() => _PremiumErrorBoundaryState();
}

class _PremiumErrorBoundaryState extends State<PremiumErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return PremiumErrorFallback(
        title: widget.sectionTitle,
        message: _error.toString(),
        onRetry: widget.onRetry == null
            ? null
            : () {
                setState(() => _error = null);
                widget.onRetry!();
              },
      );
    }

    try {
      return widget.builder(context);
    } catch (e) {
      return PremiumErrorFallback(
        title: widget.sectionTitle,
        message: e.toString(),
        onRetry: widget.onRetry,
      );
    }
  }
}
