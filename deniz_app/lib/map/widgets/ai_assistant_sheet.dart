import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_conversation_entry.dart';
import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/ai_assistant_loading.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/ai_assistant_sheet_controller.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/map/widgets/captain/ai_assistant_dock_input.dart';
import 'package:deniz_app/map/widgets/captain/ai_assistant_premium_header.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_toast.dart';
import 'package:deniz_app/widgets/premium/navigation/captain_atlas_cinematic_opening.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_bottom_sheet.dart';
import 'package:deniz_app/widgets/premium/settings/settings_ui_widgets.dart';
import 'package:flutter/material.dart';

/// AI Fishing Assistant sonuç paneli — draggable bottom sheet içeriği.
class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    super.key,
    required this.apiService,
    required this.analysis,
    required this.cache,
    required this.clientIdentityService,
    this.request = const AiAssistantRequest(),
    this.forceRefresh = false,
    this.initialQuestion,
  });

  final ApiService apiService;
  final FishingZoneResponse analysis;
  final AiAssistantCache cache;
  final ClientIdentityService clientIdentityService;
  final AiAssistantRequest request;
  final bool forceRefresh;
  final String? initialQuestion;

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  late final AiAssistantSheetController _controller;
  final _questionController = TextEditingController();
  bool _cancelled = false;

  String get _sheetTitle {
    switch (widget.request.scope) {
      case AiAssistantScope.liveContext:
        return kAiAssistantLiveTitle;
      case AiAssistantScope.hotspotDetail:
        return kAiAssistantHotspotTitle;
      default:
        return kAiAssistantTitle;
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsScope.maybeOf(context)?.settings;
    final forceRefresh = widget.forceRefresh ||
        settings?.forceRefreshAi == true ||
        settings?.alwaysTryLiveAi == true;
    _controller = AiAssistantSheetController(
      apiService: widget.apiService,
      analysis: widget.analysis,
      cache: widget.cache,
      request: widget.request,
      clientIdentityService: widget.clientIdentityService,
      forceRefreshOnOpen: forceRefresh,
      allowStaleFallback: settings?.useSafeFallbackSummary ?? true,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _controller.loadInitial();
    if (!mounted || _cancelled) return;
    final preset = widget.initialQuestion?.trim();
    if (preset != null && preset.isNotEmpty) {
      _questionController.text = preset;
      await _submitQuestion();
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _controller.refresh();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _submitQuestion() async {
    final ok = await _controller.submitQuestion(_questionController.text);
    if (!mounted) return;
    if (ok) {
      _questionController.clear();
    } else {
      context.showPremiumError(kAiAssistantErrorGeneric);
    }
    setState(() {});
  }

  void _cancel() {
    _cancelled = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return CaptainAtlasCinematicOpening(
          title: _sheetTitle,
          loading: _controller.phase == AiSheetPhase.loading,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0A1A2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              AiAssistantPremiumHeader(
                title: _sheetTitle,
                phase: _controller.phase,
                assistantName:
                    _controller.response?.assistantName ?? kCaptainAtlasChip,
                onRefresh: _refresh,
                onCancel: _cancel,
                refreshing: _controller.refreshing,
              ),
              Expanded(
                child: PremiumErrorBoundary(
                  sectionTitle: _sheetTitle,
                  onRetry: _refresh,
                  builder: (context) => SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildBody(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AiAssistantDockInput(
                  controller: _questionController,
                  loading: _controller.questionLoading,
                  onSubmit: _submitQuestion,
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_controller.phase) {
      case AiSheetPhase.loading:
        return AiAssistantLoading(onCancel: _cancel);
      case AiSheetPhase.error:
        return _ErrorBody(
          message: _controller.errorMessage ?? kAiAssistantErrorGeneric,
          onRetry: () async {
            if (!mounted) return;
            setState(() => _controller.phase = AiSheetPhase.loading);
            await _controller.loadInitial(forceRefresh: true);
            if (!mounted || _cancelled) return;
            setState(() {});
          },
        );
      case AiSheetPhase.ready:
        final data = _controller.response;
        if (data == null) {
          return AiAssistantLoading(onCancel: _cancel);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_controller.cacheOnlyMode)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _BannerChip(text: kAiAssistantCacheOnlyBanner),
              ),
            if (_controller.refreshErrorBanner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BannerChip(
                  text: _controller.refreshErrorBanner ?? kAiAssistantRefreshFailed,
                ),
              ),
            _AiAssistantContent(response: data),
            if (_controller.conversationHistory.entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ConversationHistorySection(
                entries: _controller.conversationHistory.entries,
              ),
            ],
          ],
        );
    }
  }
}

class _ConversationHistorySection extends StatelessWidget {
  const _ConversationHistorySection({required this.entries});

  final List<AiAssistantConversationEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: kAiAssistantSectionHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryEntryCard(entry: entry),
            ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatefulWidget {
  const _HistoryEntryCard({required this.entry});

  final AiAssistantConversationEntry entry;

  @override
  State<_HistoryEntryCard> createState() => _HistoryEntryCardState();
}

class _HistoryEntryCardState extends State<_HistoryEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final answer = entry.answerSummary.isNotEmpty
        ? entry.answerSummary
        : kAiAssistantErrorGeneric;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1824),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.question,
                  style: const TextStyle(
                    color: Color(0xFFB2EBF2),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (entry.cacheHit)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: _BadgeChip(label: kAiAssistantCacheBadge),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: _AiAssistantContent.bodyStyle,
          ),
          if (answer.length > 120)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Daha az' : 'Devamını gör'),
            ),
        ],
      ),
    );
  }
}

class _AiAssistantContent extends StatelessWidget {
  const _AiAssistantContent({required this.response});

  final AiAssistantResponse response;

  static const bodyStyle = TextStyle(
    color: Color(0xE6FFFFFF),
    height: 1.38,
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (settingsShowStatusChips(context))
          AiAssistantStatusChips(
            isFallback: response.isFallback,
            fallbackReason: response.fallbackReason,
            cacheHit: response.cacheHit,
            model: response.model,
            remainingQuota: response.remainingAiRequests,
            isPremium: response.isPremiumFeature == true,
          ),
        if (settingsShowStatusChips(context) &&
            (response.isFallback ||
                response.cacheHit ||
                (response.model != null && response.model!.trim().isNotEmpty) ||
                response.remainingAiRequests != null ||
                response.isPremiumFeature == true))
          const SizedBox(height: 12),
        _SectionCard(
          title: kAiAssistantSectionSummary,
          child: Text(
            response.summaryTr.isNotEmpty
                ? response.summaryTr
                : kAiAssistantErrorGeneric,
            style: bodyStyle,
          ),
        ),
        if (response.recommendedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionActions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final action in response.recommendedActions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PriorityDot(priority: action.priority),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.titleTr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (action.detailTr.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(action.detailTr, style: bodyStyle),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (response.hotspotInsights.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionHotspots,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final insight in response.hotspotInsights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.headlineTr,
                          style: const TextStyle(
                            color: Color(0xFFB2EBF2),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (insight.detailTr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(insight.detailTr, style: bodyStyle),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (response.conditionsCommentTr.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionConditions,
            child: Text(response.conditionsCommentTr, style: bodyStyle),
          ),
        ],
        if (response.speciesCommentTr.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionSpecies,
            child: Text(response.speciesCommentTr, style: bodyStyle),
          ),
        ],
        if (response.limitationsTr.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionLimitations,
            child: _BulletList(items: response.limitationsTr),
          ),
        ],
        if (response.safetyRemindersTr.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: kAiAssistantSectionSafety,
            child: _BulletList(items: response.safetyRemindersTr),
          ),
        ],
        const SizedBox(height: 14),
        _TrustNote(text: response.trustNoteTr),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 32),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: Colors.white70, height: 1.35)),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text(kRetry),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102232),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFB2EBF2),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final body = text.trim().isNotEmpty ? text.trim() : kAiAssistantTrustTitle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            kAiAssistantTrustTitle,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFFFE0B2), fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF32D9FF);
    final bg = fg.withValues(alpha: 0.12);
    final border = fg.withValues(alpha: 0.35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF114B5F),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF32D9FF).withValues(alpha: 0.5)),
      ),
      child: Text(
        '$priority',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> showAiAssistantSheet({
  required BuildContext context,
  required ApiService apiService,
  required FishingZoneResponse analysis,
  required AiAssistantCache cache,
  required ClientIdentityService clientIdentityService,
  AiAssistantRequest request = const AiAssistantRequest(),
  bool forceRefresh = false,
  String? initialQuestion,
}) {
  return showPremiumBottomSheet<void>(
    context: context,
    builder: (_) => AiAssistantSheet(
      apiService: apiService,
      analysis: analysis,
      cache: cache,
      clientIdentityService: clientIdentityService,
      request: request,
      forceRefresh: forceRefresh,
      initialQuestion: initialQuestion,
    ),
  );
}

Future<void> showHotspotAiAssistantSheet({
  required BuildContext context,
  required ApiService apiService,
  required FishingZoneResponse analysis,
  required AiAssistantCache cache,
  required ClientIdentityService clientIdentityService,
  required int hotspotId,
  bool forceRefresh = false,
  String? initialQuestion,
}) {
  return showAiAssistantSheet(
    context: context,
    apiService: apiService,
    analysis: analysis,
    cache: cache,
    clientIdentityService: clientIdentityService,
    forceRefresh: forceRefresh,
    initialQuestion: initialQuestion,
    request: AiAssistantRequest(
      scope: AiAssistantScope.hotspotDetail,
      focusHotspotId: hotspotId,
    ),
  );
}

Future<void> showLiveAiAssistantSheet({
  required BuildContext context,
  required ApiService apiService,
  required FishingZoneResponse analysis,
  required AiAssistantCache cache,
  required ClientIdentityService clientIdentityService,
  required Map<String, dynamic> liveContext,
  bool forceRefresh = false,
  String? initialQuestion,
}) {
  return showAiAssistantSheet(
    context: context,
    apiService: apiService,
    analysis: analysis,
    cache: cache,
    clientIdentityService: clientIdentityService,
    forceRefresh: forceRefresh,
    initialQuestion: initialQuestion,
    request: AiAssistantRequest(
      scope: AiAssistantScope.liveContext,
      liveContext: liveContext,
    ),
  );
}
