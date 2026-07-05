import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/ai_assistant_sheet.dart';
import 'package:deniz_app/navigation/premium_navigator.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_dialog.dart';
import 'package:flutter/material.dart';

/// Captain Atlas giriş noktası — tek standart launcher.
enum CaptainAtlasEntryPoint {
  dashboard,
  sidebar,
  liveArea,
  marineIntelligence,
  mapCommandBar,
  chartOverlay,
  compare,
  hotspotDetail,
}

/// Tüm Captain Atlas girişleri için bağlam.
class CaptainAtlasLaunchRequest {
  const CaptainAtlasLaunchRequest({
    required this.serverIp,
    required this.entryPoint,
    this.analysis,
    this.liveContext,
    this.hotspotId,
    this.initialQuestion,
    this.apiService,
    this.aiCache,
    this.clientIdentity,
  });

  final String serverIp;
  final CaptainAtlasEntryPoint entryPoint;
  final FishingZoneResponse? analysis;
  final Map<String, dynamic>? liveContext;
  final int? hotspotId;
  final String? initialQuestion;
  final ApiService? apiService;
  final AiAssistantCache? aiCache;
  final ClientIdentityService? clientIdentity;
}

abstract final class CaptainAtlasLauncher {
  static Future<void> launch(
    BuildContext context,
    CaptainAtlasLaunchRequest request,
  ) async {
    PremiumHaptics.light();

    switch (request.entryPoint) {
      case CaptainAtlasEntryPoint.dashboard:
      case CaptainAtlasEntryPoint.sidebar:
      case CaptainAtlasEntryPoint.marineIntelligence:
      case CaptainAtlasEntryPoint.compare:
        await _openCommandCenter(context, request.serverIp);
        return;
      case CaptainAtlasEntryPoint.liveArea:
        if (!_hasLiveContext(request)) {
          await _showNoContext(context);
          return;
        }
        await _openLiveSheet(context, request);
        return;
      case CaptainAtlasEntryPoint.mapCommandBar:
      case CaptainAtlasEntryPoint.chartOverlay:
        if (!_hasSessionContext(request)) {
          await _showNoContext(context);
          return;
        }
        await _openSessionSheet(context, request);
        return;
      case CaptainAtlasEntryPoint.hotspotDetail:
        if (!_hasHotspotContext(request)) {
          await _showNoContext(context);
          return;
        }
        await _openHotspotSheet(context, request);
        return;
    }
  }

  static Future<void> openCommandCenter(BuildContext context, String serverIp) {
    return _openCommandCenter(context, serverIp);
  }

  static Future<void> showNoContext(BuildContext context) {
    return _showNoContext(context);
  }

  static Future<void> _openCommandCenter(BuildContext context, String serverIp) {
    return PremiumNavigator.push<void>(
      context,
      CaptainAtlasScreen(serverIp: serverIp),
    );
  }

  static bool _hasSessionContext(CaptainAtlasLaunchRequest r) {
    return r.analysis != null && r.analysis!.hotspots.isNotEmpty;
  }

  static bool _hasLiveContext(CaptainAtlasLaunchRequest r) {
    return _hasSessionContext(r) && r.liveContext != null;
  }

  static bool _hasHotspotContext(CaptainAtlasLaunchRequest r) {
    return _hasSessionContext(r) && r.hotspotId != null;
  }

  static Future<void> _showNoContext(BuildContext context) {
    PremiumHaptics.warning();
    return PremiumDialog.showAlert(
      context,
      title: kCaptainAtlasNoContextTitle,
      message: kCaptainAtlasNoContextMessage,
      tone: PremiumDialogTone.info,
    );
  }

  static ApiService _api(CaptainAtlasLaunchRequest r) {
    return r.apiService ??
        ApiService(
          serverBaseUrl: AppConfig.buildApiBaseUrl(r.serverIp.trim()),
        );
  }

  static Future<void> _openSessionSheet(
    BuildContext context,
    CaptainAtlasLaunchRequest request,
  ) {
    final analysis = request.analysis!;
    return showAiAssistantSheet(
      context: context,
      apiService: _api(request),
      analysis: analysis,
      cache: request.aiCache ?? AiAssistantCache(),
      clientIdentityService: request.clientIdentity ?? ClientIdentityService(),
      initialQuestion: request.initialQuestion,
    );
  }

  static Future<void> _openLiveSheet(
    BuildContext context,
    CaptainAtlasLaunchRequest request,
  ) {
    return showLiveAiAssistantSheet(
      context: context,
      apiService: _api(request),
      analysis: request.analysis!,
      cache: request.aiCache ?? AiAssistantCache(),
      clientIdentityService: request.clientIdentity ?? ClientIdentityService(),
      liveContext: request.liveContext!,
      initialQuestion: request.initialQuestion,
    );
  }

  static Future<void> _openHotspotSheet(
    BuildContext context,
    CaptainAtlasLaunchRequest request,
  ) {
    return showHotspotAiAssistantSheet(
      context: context,
      apiService: _api(request),
      analysis: request.analysis!,
      cache: request.aiCache ?? AiAssistantCache(),
      clientIdentityService: request.clientIdentity ?? ClientIdentityService(),
      hotspotId: request.hotspotId!,
      initialQuestion: request.initialQuestion,
    );
  }
}
