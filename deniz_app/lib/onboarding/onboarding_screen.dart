import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';
import '../local_storage_service.dart';
import '../services/app_preferences.dart';

/// İlk açılış: değer önerisi, sunucu IP, feragat onayı — tek MaterialApp içinde route ile kapatılabilir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _index = 0;
  final _ipController = TextEditingController();
  final _storage = LocalStorageService();
  bool _ackLegal = false;

  @override
  void dispose() {
    _page.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < 2) {
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      if (!_ackLegal) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(kOnboardingSnackNeedCheckbox),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final ip = AppConfig.normalizeHost(_ipController.text);
      if (ip.isNotEmpty &&
          ip != 'localhost' &&
          ip != '127.0.0.1' &&
          ip != '::1') {
        await _storage.saveServerIp(ip);
      }
      await AppPreferences.setOnboardingComplete();
      await widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1A2A),
        title: const Text(kOnboardingWelcomeTitle),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: on ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: on ? const Color(0xFF32D9FF) : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [_pageIntro(), _pageServer(), _pageLegal()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF114B5F),
                ),
                child:
                    Text(_index < 2 ? kOnboardingNext : kOnboardingEnterApp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageIntro() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConfig.productName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            kOnboardingIntroBody,
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 15),
          ),
          SizedBox(height: 20),
          _OnboardingBullet(icon: Icons.radar, text: kOnboardingBulletScan),
          _OnboardingBullet(
            icon: Icons.tune,
            text: kOnboardingBulletCalib,
          ),
          _OnboardingBullet(icon: Icons.download, text: kOnboardingBulletGpx),
        ],
      ),
    );
  }

  Widget _pageServer() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            kOnboardingServerTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            kOnboardingServerBody,
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: kOnboardingServerIpDecorationLabel(
                AppConfig.defaultApiPort,
              ),
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: kOnboardingServerIpHint,
              hintStyle: const TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF32D9FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            kWrongIpFriendlyHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageLegal() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          kOnboardingLegalHeading,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          AppConfig.trustShortLine,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF0E1A2A),
                content: const SingleChildScrollView(
                  child: Text(
                    AppConfig.trustFullText,
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(kDialogClose),
                  ),
                ],
              ),
            );
          },
          child: const Text(kOnboardingReadFullText),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _ackLegal,
          onChanged: (v) => setState(() => _ackLegal = v ?? false),
          checkColor: const Color(0xFF0B1A2A),
          fillColor: WidgetStateProperty.all(const Color(0xFF32D9FF)),
          title: const Text(
            kOnboardingLegalAck,
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _OnboardingBullet extends StatelessWidget {
  const _OnboardingBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4FC3F7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
