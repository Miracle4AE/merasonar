import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';

class ProviderComparisonPanel extends StatelessWidget {
  const ProviderComparisonPanel({super.key, required this.comparison});

  final MarineProviderComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: const Color(0xFF142434),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kMarineSectionProviders,
                style: const TextStyle(
                  color: Color(0xFF80DEEA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sağlıklı: ${comparison.healthyCount}/${comparison.providerCount}',
                style: const TextStyle(color: Colors.white70),
              ),
              for (final p in comparison.providers)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${p.name} · ${p.status} · güven %${(p.confidence * 100).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
