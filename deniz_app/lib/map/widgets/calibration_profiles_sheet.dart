import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../local_storage_service.dart';

class CalibrationProfilesSheet extends StatefulWidget {
  const CalibrationProfilesSheet({
    super.key,
    required this.storage,
    required this.currentPointCount,
    required this.currentImageWidth,
    required this.currentImageHeight,
    required this.chartLabelHint,
    required this.onApplyProfile,
    required this.onSaveCurrent,
  });

  final LocalStorageService storage;
  final int currentPointCount;
  final int currentImageWidth;
  final int currentImageHeight;
  final String? chartLabelHint;
  final void Function(ChartCalibrationProfile profile) onApplyProfile;
  final Future<void> Function(String name) onSaveCurrent;

  @override
  State<CalibrationProfilesSheet> createState() =>
      _CalibrationProfilesSheetState();
}

class _CalibrationProfilesSheetState extends State<CalibrationProfilesSheet> {
  List<ChartCalibrationProfile> _profiles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.storage.loadCalibrationProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = p;
      _loading = false;
    });
  }

  Future<void> _showNameDialogAndSave() async {
    if (widget.currentPointCount < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydetmek için önce kontrol noktaları belirleyin.'),
        ),
      );
      return;
    }
    if (widget.currentImageWidth < 2 || widget.currentImageHeight < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Görüntü boyutu bilinmiyor. Bir harita ekran görüntüsü analiz edin veya noktaları seçin.',
          ),
        ),
      );
      return;
    }
    final controller = TextEditingController(
      text: widget.chartLabelHint ?? 'Profil',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF122436),
          title: const Text('Profil adı', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Ad',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (name == null || name.isEmpty) return;
    await widget.onSaveCurrent(name);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profil kaydedildi: $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF32D9FF)),
        ),
      );
    }
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kalibrasyon profilleri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showNameDialogAndSave,
                  icon: const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Profili kaydet'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Aynı uygulama/ekran görüntüsü çözünürlüğünde kontrol noktalarını tekrar kullanmak için.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Expanded(
            child: _profiles.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz profil yok. Haritada noktaları seçip “Mevcutu kaydet”e basın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _profiles[i];
                      final w = p.imageWidth;
                      final h = p.imageHeight;
                      final dimMatch = w == widget.currentImageWidth &&
                          h == widget.currentImageHeight;
                      return Card(
                        color: const Color(0xFF122436),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${p.controlPoints.length} nokta · $w×$h px'
                                '${p.chartLabel != null ? ' · ${p.chartLabel}' : ''}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !dimMatch && widget.currentImageWidth > 0
                                    ? 'Şu anki görüntü: ${widget.currentImageWidth}×${widget.currentImageHeight} — noktaları doğrulayın'
                                    : 'Boyut eşleşiyor',
                                style: TextStyle(
                                  color: dimMatch
                                      ? Colors.white38
                                      : Colors.orangeAccent,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onApplyProfile(p);
                                    },
                                    child: const Text('Uygula'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await widget.storage
                                          .deleteCalibrationProfile(p.id);
                                      await _load();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Profil silindi.'),
                                        ),
                                      );
                                    },
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
