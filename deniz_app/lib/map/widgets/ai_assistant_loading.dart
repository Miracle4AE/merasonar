import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';

/// AI asistan yüklenirken gösterilen basit iskelet.
class AiAssistantLoading extends StatelessWidget {
  const AiAssistantLoading({
    super.key,
    this.onCancel,
  });

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF32D9FF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            kAiAssistantLoading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _SkeletonLine(widthFactor: 0.92),
          const SizedBox(height: 8),
          _SkeletonLine(widthFactor: 0.78),
          const SizedBox(height: 8),
          _SkeletonLine(widthFactor: 0.66),
          if (onCancel != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: onCancel,
              child: const Text(kAiAssistantCancel),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
