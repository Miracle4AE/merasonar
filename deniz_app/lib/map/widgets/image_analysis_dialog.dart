import 'dart:io';

import 'package:flutter/material.dart';

import '../../api_service.dart';

class ImageAnalysisDialog extends StatelessWidget {
  const ImageAnalysisDialog({
    super.key,
    required this.chartImageFile,
    required this.imageSize,
    required this.hotspots,
  });

  final File chartImageFile;
  final Map<String, int> imageSize;
  final List<Hotspot> hotspots;

  @override
  Widget build(BuildContext context) {
    final imageWidth = (imageSize['width'] ?? 0).toDouble();
    final imageHeight = (imageSize['height'] ?? 0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Analiz Sonucu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: imageWidth <= 0 || imageHeight <= 0
                  ? const Center(
                      child: Text('Görsel boyutu alınamadı.'),
                    )
                  : InteractiveViewer(
                      minScale: 0.35,
                      maxScale: 6,
                      child: Center(
                        child: SizedBox(
                          width: imageWidth,
                          height: imageHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  chartImageFile,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              ...hotspots.map((hotspot) {
                                final x = hotspot.pixelCentroid['x'] ?? 0;
                                final y = hotspot.pixelCentroid['y'] ?? 0;
                                return Positioned(
                                  left: x - 12,
                                  top: y - 12,
                                  child: GestureDetector(
                                    onTap: () => _showHotspotInfo(context, hotspot),
                                    child: _MarkerBadge(
                                      label: hotspot.classification,
                                      color: _classificationColor(hotspot.classification),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _classificationColor(String classification) {
    switch (classification.toUpperCase()) {
      case 'A':
        return const Color(0xFFE53935);
      case 'B':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF43A047);
    }
  }

  void _showHotspotInfo(BuildContext context, Hotspot hotspot) {
    final reasoningText = hotspot.reasoning.isEmpty
        ? 'Açıklama bulunamadı.'
        : hotspot.reasoning.join('\n');
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sınıf ${hotspot.classification}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('Skor: ${hotspot.score.toStringAsFixed(3)}'),
                const SizedBox(height: 8),
                const Text(
                  'Gerekçe',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(reasoningText),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarkerBadge extends StatelessWidget {
  const _MarkerBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
