import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';
import '../utils/android_backend_host_policy.dart';
import '../utils/server_host_hints.dart';
import '../widgets/backend_connection_badge.dart';

/// Sunucu IP düzenleyicisi — rozet, otomatik keşif ve metin alanı.
Future<String?> showMerasonarServerHostDialog(
  BuildContext context, {
  required String initialHost,
  BackendConnectionBadgeData? badgeSnapshot,
  bool autoDiscoverBusy = false,
  Future<void> Function()? onRequestAutoDiscover,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController(text: initialHost.trim());
      return StatefulBuilder(
        builder: (context, setDlg) {
          void onIpChanged(_) => setDlg(() {});

          return AlertDialog(
            title: const Text(kServerDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeSnapshot != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BackendConnectionBadge(
                        data: badgeSnapshot,
                        tooltip: '',
                        onTap: null,
                      ),
                    ),
                  Text(
                    'Arka uç başka bilgisayardaysa, o makinenin yerel ağ adresini buraya yazabilirsiniz.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: onIpChanged,
                    decoration: InputDecoration(
                      labelText:
                          'Sunucu IP (port ${AppConfig.defaultApiPort} sabit)',
                      hintText: 'Örn: ${AppConfig.defaultLanHostExample}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İpucu: Mobil cihazda yerel makine adresi yerine bilgisayarınızın ağ adresini (örn. ${AppConfig.defaultLanHostExample}) bu şekilde girebilirsiniz.',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  if (loopbackWarningForMobile(controller.text) !=
                      null) ...[
                    const SizedBox(height: 8),
                    Text(
                      loopbackWarningForMobile(controller.text)!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed:
                        autoDiscoverBusy || onRequestAutoDiscover == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                unawaited(onRequestAutoDiscover());
                              },
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text(kDiscoverManualButton),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(kServerDialogBtnCancel),
              ),
              FilledButton(
                onPressed: () {
                  final normalized = AppConfig.normalizeHost(controller.text);
                  if (shouldBlockAndroidLoopbackHost(normalized)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(androidLoopbackHostBlockedExplanation()),
                        duration: const Duration(seconds: 6),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, normalized);
                },
                child: const Text(kServerDialogBtnSave),
              ),
            ],
          );
        },
      );
    },
  );
}
