import 'dart:io';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../local_storage_service.dart';

/// Geçmiş analizler: favoriler ayrı bölüm, satırda küçük chart önizlemesi + özet.
class AnalysisHistoryBody extends StatelessWidget {
  const AnalysisHistoryBody({
    super.key,
    required this.entries,
    required this.onOpenEntry,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.formatTimestamp,
    required this.subtitleText,
  });

  final List<AnalysisHistoryEntry> entries;
  final void Function(AnalysisHistoryEntry) onOpenEntry;
  final void Function(AnalysisHistoryEntry) onToggleFavorite;
  final void Function(AnalysisHistoryEntry) onDelete;
  final String Function(DateTime) formatTimestamp;
  final String Function(AnalysisHistoryEntry) subtitleText;

  @override
  Widget build(BuildContext context) {
    final fav = entries.where((e) => e.isFavorite).toList(growable: false);
    final rest = entries.where((e) => !e.isFavorite).toList(growable: false);

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Kayıtlı analiz geçmişi henüz yok.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (fav.isNotEmpty) ...[
          _sectionLabel('Favoriler', Icons.star_rounded, Colors.amberAccent),
          ...fav.map(
            (e) => _entryTile(
              context: context,
              entry: e,
            ),
          ),
          if (rest.isNotEmpty) const SizedBox(height: 12),
        ],
        if (rest.isNotEmpty) ...[
          if (fav.isNotEmpty) _sectionLabel('Diğer kayıtlar', Icons.history, Colors.white70),
          ...rest.map(
            (e) => _entryTile(
              context: context,
              entry: e,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile({
    required BuildContext context,
    required AnalysisHistoryEntry entry,
  }) {
    final response = entry.response;
    final classCounts = <String, int>{'A': 0, 'B': 0, 'C': 0};
    for (final h in response.hotspots) {
      final c = h.classification.toUpperCase();
      if (classCounts.containsKey(c)) {
        classCounts[c] = (classCounts[c] ?? 0) + 1;
      }
    }
    final trusted = response.hotspots
        .where((h) => h.trustState == 'trusted')
        .length;

    return Card(
      color: const Color(0xFF122436),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(entry),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.chartImageLabel ??
                                formatTimestamp(entry.savedAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.isFavorite)
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amberAccent,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTimestamp(entry.savedAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _previewStrip(
                      a: classCounts['A']!,
                      b: classCounts['B']!,
                      c: classCounts['C']!,
                      trusted: trusted,
                      total: response.hotspots.length,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText(entry),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      entry.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: entry.isFavorite
                          ? Colors.amberAccent
                          : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Favori',
                    onPressed: () => onToggleFavorite(entry),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.orangeAccent,
                      size: 22,
                    ),
                    tooltip: 'Sil',
                    onPressed: () => onDelete(entry),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(AnalysisHistoryEntry entry) {
    const size = 64.0;
    final path = entry.chartImagePath;
    if (path == null || path.isEmpty) {
      return _thumbPlaceholder(
        label: 'Önizleme yok',
        icon: Icons.image_not_supported_outlined,
      );
    }
    final f = File(path);
    if (!f.existsSync()) {
      return _thumbPlaceholder(
        label: 'Kaynak silindi',
        icon: Icons.link_off_outlined,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        f,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbPlaceholder(
          label: 'Okunamadı',
        ),
      ),
    );
  }

  Widget _thumbPlaceholder({
    String? label,
    IconData icon = Icons.broken_image_outlined,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(
            icon,
            color: Colors.white38,
            size: 28,
          ),
        ),
        if (label != null && label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _previewStrip({
    required int a,
    required int b,
    required int c,
    required int trusted,
    required int total,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _miniChip('A', a, const Color(0xFFFF5252)),
        _miniChip('B', b, const Color(0xFFFFB300)),
        _miniChip('C', c, const Color(0xFF66BB6A)),
        Text(
          total > 0
              ? '$trusted güvenilir / $total toplam'
              : '—',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _miniChip(String label, int count, Color color) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$label:$count',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Alt sayfa: depodan yükler; favori/sil sonrası kendi kendine yeniler.
class AnalysisHistoryModal extends StatefulWidget {
  const AnalysisHistoryModal({
    super.key,
    required this.storage,
    required this.onPickEntry,
  });

  final LocalStorageService storage;
  final void Function(AnalysisHistoryEntry) onPickEntry;

  @override
  State<AnalysisHistoryModal> createState() => _AnalysisHistoryModalState();
}

class _AnalysisHistoryModalState extends State<AnalysisHistoryModal> {
  List<AnalysisHistoryEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final h = await widget.storage.loadAnalysisHistory();
    if (!mounted) return;
    setState(() {
      _entries = h;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF32D9FF),
          ),
        ),
      );
    }
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Analiz geçmişi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: AnalysisHistoryBody(
              entries: _entries,
              onOpenEntry: (e) {
                Navigator.pop(context);
                widget.onPickEntry(e);
              },
              onToggleFavorite: (e) async {
                await widget.storage.toggleAnalysisHistoryFavorite(e.id);
                if (!mounted) return;
                await _reload();
              },
              onDelete: (e) async {
                await widget.storage.deleteAnalysisHistoryEntry(e.id);
                if (!context.mounted) return;
                await _reload();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kayıtlı analiz silindi.')),
                );
              },
              formatTimestamp: _ts,
              subtitleText: _subtitle,
            ),
          ),
        ],
      ),
    );
  }

  String _ts(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _subtitle(AnalysisHistoryEntry entry) {
    final response = entry.response;
    final trustedCount =
        response.hotspots.where((h) => h.trustState == 'trusted').length;
    final topScore =
        response.hotspots.isEmpty
            ? '-'
            : response.hotspots.first.score.toStringAsFixed(2);
    final chartInfo =
        entry.controlPointCount > 0
            ? ' | ${entry.controlPointCount} kontrol noktası'
            : '';
    return '$trustedCount güvenilir mera | toplam ${response.hotspots.length} hotspot | üst skor $topScore$chartInfo';
  }
}
