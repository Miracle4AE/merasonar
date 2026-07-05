import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/app_preferences.dart';

/// Cihaz genişliğinde feragat / güven bandı. Daraltma tercihi [AppPreferences] ile saklanır.
class TrustDisclaimerBar extends StatefulWidget {
  const TrustDisclaimerBar({super.key});

  @override
  State<TrustDisclaimerBar> createState() => _TrustDisclaimerBarState();
}

class _TrustDisclaimerBarState extends State<TrustDisclaimerBar> {
  bool? _minimized;
  static const _bg = Color(0xE5101418);
  static const _border = Color(0x33FFFFFF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await AppPreferences.isTrustBarMinimized();
    if (mounted) setState(() => _minimized = m);
  }

  Future<void> _setMin(bool v) async {
    await AppPreferences.setTrustBarMinimized(v);
    if (mounted) setState(() => _minimized = v);
  }

  void _showFullLegal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2A),
          title: const Text(
            'Feragat ve kullanım',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              AppConfig.trustFullText,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized == null) {
      return const SizedBox(
        height: 4,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 2,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF32D9FF),
            ),
          ),
        ),
      );
    }
    if (_minimized == true) {
      return Material(
        color: _bg,
        child: InkWell(
          onTap: () => _setMin(false),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: Color(0xFF7FD7FF),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tavsiye niteliğindedir — tam feragat için dokunun',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.expand_less_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: _bg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: Color(0xFF4FC3F7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConfig.trustShortLine,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _showFullLegal(context),
                        child: const Text('Tam metin / feragat'),
                      ),
                      TextButton(
                        onPressed: () => _setMin(true),
                        child: const Text('Bandı daralt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
