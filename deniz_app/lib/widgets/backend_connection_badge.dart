import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';

/// Rozet gösterimleri — arka planda sürekli ağ taraması yapmaz.
enum BackendConnectionTone {
  connected,
  searching,
  offline,
  disconnected,
  manualRequired,
}

/// Sunucu rozetinin metin ve renk görünümü (keşif + tek seferlik sağlık kontrolünden gelir).
@immutable
class BackendConnectionBadgeData {
  const BackendConnectionBadgeData({
    required this.tone,
    required this.label,
  });

  final BackendConnectionTone tone;
  final String label;
}

BackendConnectionBadgeData resolveBackendConnectionBadge({
  required String serverIp,
  required bool discoveryBusy,
  required bool serverHealthChecking,
  required bool manualIpRequiredAndroid,
  required bool? healthOkLast,
}) {
  if (discoveryBusy) {
    return BackendConnectionBadgeData(
      tone: BackendConnectionTone.searching,
      label: kDiscoverSearching,
    );
  }
  if (serverHealthChecking) {
    return BackendConnectionBadgeData(
      tone: BackendConnectionTone.searching,
      label: kServerBadgeVerifying,
    );
  }
  if (manualIpRequiredAndroid) {
    return BackendConnectionBadgeData(
      tone: BackendConnectionTone.manualRequired,
      label: kServerBadgeManualRequired,
    );
  }
  if (healthOkLast == null) {
    return BackendConnectionBadgeData(
      tone: BackendConnectionTone.searching,
      label: kServerBadgeAwaitingProbe,
    );
  }
  if (!healthOkLast) {
    return BackendConnectionBadgeData(
      tone: BackendConnectionTone.offline,
      label: kServerBadgeOfflineMode,
    );
  }
  final h = serverIp.trim();
  return BackendConnectionBadgeData(
    tone: BackendConnectionTone.connected,
    label: kServerBadgeConnected(h, AppConfig.defaultApiPort),
  );
}

class BackendConnectionBadge extends StatelessWidget {
  const BackendConnectionBadge({
    super.key,
    required this.data,
    this.onTap,
    this.tooltip = kServerBadgeTooltip,
  });

  final BackendConnectionBadgeData data;
  final VoidCallback? onTap;
  final String tooltip;

  Color get _pillColor {
    switch (data.tone) {
      case BackendConnectionTone.connected:
        return const Color(0xFF1E8E52);
      case BackendConnectionTone.searching:
        return const Color(0xFFC9A632);
      case BackendConnectionTone.offline:
        return const Color(0xFF455A64);
      case BackendConnectionTone.disconnected:
        return const Color(0xFFB54A43);
      case BackendConnectionTone.manualRequired:
        return const Color(0xFF5C6470);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = Colors.white.withValues(alpha: 0.95);
    Widget core = Material(
      color: _pillColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  data.label,
                  maxLines: data.tone == BackendConnectionTone.offline ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08,
                    color: fg,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip.isNotEmpty) {
      core = Tooltip(message: tooltip, child: core);
    }
    return core;
  }
}
