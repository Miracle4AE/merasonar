import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/local_storage_service.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/navigation/premium_navigator.dart';
import 'package:deniz_app/screens/marine_compare_screen.dart';
import 'package:deniz_app/screens/marine_intelligence_screen.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/live_area_screen.dart';
import 'package:flutter/material.dart';

/// Captain Atlas premium komuta merkezi — chatbot değil, AI command center.
class CaptainAtlasScreen extends StatefulWidget {
  const CaptainAtlasScreen({super.key, required this.serverIp});

  final String serverIp;

  @override
  State<CaptainAtlasScreen> createState() => _CaptainAtlasScreenState();
}

class _CaptainAtlasScreenState extends State<CaptainAtlasScreen> {
  final _overviewService = DashboardOverviewService();
  final _storage = LocalStorageService();
  final _aiCache = AiAssistantCache();
  final _clientIdentity = ClientIdentityService();

  DashboardOverview _overview = DashboardOverview.empty;
  bool _loading = true;

  static const _quickQuestions = [
    kCaptainAtlasQuickWhere,
    kCaptainAtlasQuickWhen,
    kCaptainAtlasQuickRisk,
    kCaptainAtlasQuickAb,
    kCaptainAtlasQuickWind,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final next = await _overviewService.load();
    if (!mounted) return;
    setState(() {
      _overview = next;
      _loading = false;
    });
  }

  Future<void> _askQuestion(String question) async {
    PremiumHaptics.selection();
    final zone = await _storage.loadLatestFishingZoneResponse();
    if (!mounted) return;
    if (zone == null || zone.hotspots.isEmpty) {
      await CaptainAtlasLauncher.showNoContext(context);
      return;
    }
    await CaptainAtlasLauncher.launch(
      context,
      CaptainAtlasLaunchRequest(
        serverIp: widget.serverIp,
        entryPoint: CaptainAtlasEntryPoint.mapCommandBar,
        analysis: zone,
        initialQuestion: question,
        aiCache: _aiCache,
        clientIdentity: _clientIdentity,
      ),
    );
  }

  Future<void> _openSessionSheet() async {
    PremiumHaptics.medium();
    final zone = await _storage.loadLatestFishingZoneResponse();
    if (!mounted) return;
    await CaptainAtlasLauncher.launch(
      context,
      CaptainAtlasLaunchRequest(
        serverIp: widget.serverIp,
        entryPoint: CaptainAtlasEntryPoint.mapCommandBar,
        analysis: zone,
        aiCache: _aiCache,
        clientIdentity: _clientIdentity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_captain_atlas'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(kCaptainAtlasScreenTitle, style: AppTextStyles.heroTitle),
        backgroundColor: AppColors.backgroundNavy.withValues(alpha: 0.92),
      ),
      body: PremiumErrorBoundary(
        sectionTitle: kCaptainAtlasScreenTitle,
        onRetry: _load,
        builder: (context) => _loading
            ? const PremiumLoadingSkeleton(height: 320)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                  CaptainAtlasHeroCard(
                    title: kCaptainAtlasScreenTitle,
                    body: _overview.captainAtlas.hasData
                        ? _overview.captainAtlas.summaryTr
                        : kPremiumDashCaptainEmpty,
                    presence: CaptainAtlasPresence.ready,
                    actionLabel: kCaptainAtlasOpenSheet,
                    useHeroAvatar: true,
                    onAsk: _openSessionSheet,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(kCaptainAtlasContextSection, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  _ContextGrid(overview: _overview),
                  const SizedBox(height: AppSpacing.lg),
                  Text(kCaptainAtlasQuickQuestions, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final q in _quickQuestions)
                        ActionChip(
                          label: Text(q, style: AppTextStyles.caption),
                          onPressed: () => _askQuestion(q),
                          backgroundColor:
                              AppColors.surfaceElevated.withValues(alpha: 0.55),
                          side: BorderSide(
                            color: AppColors.borderCyan.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PremiumPrimaryButton(
                    label: kCaptainAtlasCtaMarine,
                    icon: Icons.analytics_outlined,
                    onPressed: () {
                      PremiumHaptics.light();
                      PremiumNavigator.push<void>(
                        context,
                        MarineIntelligenceScreen(serverIp: widget.serverIp),
                      );
                    },
                    expanded: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PremiumPrimaryButton(
                    label: kCaptainAtlasCtaLive,
                    icon: Icons.sensors_rounded,
                    onPressed: () {
                      PremiumHaptics.light();
                      PremiumNavigator.push<void>(
                        context,
                        LiveAreaScreen(serverIp: widget.serverIp),
                      );
                    },
                    expanded: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PremiumPrimaryButton(
                    label: kCaptainAtlasCtaCompare,
                    icon: Icons.compare_arrows_rounded,
                    onPressed: () {
                      PremiumHaptics.light();
                      PremiumNavigator.push<void>(
                        context,
                        MarineCompareScreen(serverIp: widget.serverIp),
                      );
                    },
                    expanded: true,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _ContextGrid extends StatelessWidget {
  const _ContextGrid({required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final hasAnyContext = overview.marineReport.hasData ||
        overview.liveScore.hasData ||
        overview.compare.hasData ||
        overview.savedSpots.hasData;

    if (!hasAnyContext) {
      return PremiumEmptyState(
        title: kCaptainAtlasContextSection,
        subtitle: kCaptainAtlasContextEmpty,
        icon: Icons.hub_outlined,
      );
    }

    final cards = <Widget>[
      _ContextTile(
        title: kCaptainAtlasContextReport,
        subtitle: overview.marineReport.hasData
            ? '${overview.marineReport.suitabilityScore ?? '—'} · ${overview.marineReport.advice}'
            : kCaptainAtlasContextEmpty,
        icon: Icons.place_outlined,
      ),
      _ContextTile(
        title: kCaptainAtlasContextLive,
        subtitle: overview.liveScore.hasData
            ? '${overview.liveScore.score} · ${overview.liveScore.rating}'
            : kCaptainAtlasContextEmpty,
        icon: Icons.sensors_rounded,
      ),
      _ContextTile(
        title: kCaptainAtlasContextCompare,
        subtitle: overview.compare.hasData
            ? overview.compare.summaryTr
            : kCaptainAtlasContextEmpty,
        icon: Icons.compare_arrows_rounded,
      ),
      _ContextTile(
        title: kCaptainAtlasContextSpot,
        subtitle: overview.savedSpots.hasData
            ? overview.savedSpots.items.first.name
            : kCaptainAtlasContextEmpty,
        icon: Icons.bookmark_outline_rounded,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.35,
      children: cards,
    );
  }
}

class _ContextTile extends StatelessWidget {
  const _ContextTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentTeal, size: 20),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.cardTitle, maxLines: 1),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
