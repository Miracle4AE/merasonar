import 'dart:async' show unawaited;

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_forecast_timeline.dart';
import 'package:deniz_app/map/widgets/marine/marine_report_cards.dart';
import 'package:deniz_app/map/widgets/navionics_coordinate_field.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:deniz_app/utils/navionics_coordinate_parser.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:flutter/material.dart';

class MarineCompareScreen extends StatefulWidget {
  const MarineCompareScreen({
    super.key,
    required this.serverIp,
    this.initialLeft,
    this.initialRight,
  });

  final String serverIp;
  final MarineCompareSide? initialLeft;
  final MarineCompareSide? initialRight;

  @override
  State<MarineCompareScreen> createState() => _MarineCompareScreenState();
}

class _MarineCompareScreenState extends State<MarineCompareScreen> {
  final _leftLatCtrl = TextEditingController();
  final _leftLonCtrl = TextEditingController();
  final _rightLatCtrl = TextEditingController();
  final _rightLonCtrl = TextEditingController();
  final _leftLabelCtrl = TextEditingController(text: kMarineComparePointA);
  final _rightLabelCtrl = TextEditingController(text: kMarineComparePointB);

  MarineCompareSide? _leftSpotSide;
  MarineCompareSide? _rightSpotSide;
  MarineCompareResponse? _result;
  bool _busy = false;
  bool _includeAiComment = false;
  String? _error;

  ApiService get _api => ApiService(
        serverBaseUrl: AppConfig.buildApiBaseUrl(widget.serverIp.trim()),
      );

  @override
  void initState() {
    super.initState();
    _applyInitialSide(widget.initialLeft, isLeft: true);
    _applyInitialSide(widget.initialRight, isLeft: false);
  }

  void _applyInitialSide(MarineCompareSide? side, {required bool isLeft}) {
    if (side == null) return;
    if (side.spotId != null) {
      if (isLeft) {
        _leftSpotSide = side;
      } else {
        _rightSpotSide = side;
      }
      if (side.label != null && side.label!.trim().isNotEmpty) {
        (isLeft ? _leftLabelCtrl : _rightLabelCtrl).text = side.label!.trim();
      }
    }
    if (side.lat != null) {
      (isLeft ? _leftLatCtrl : _rightLatCtrl).text =
          side.lat!.toStringAsFixed(5);
    }
    if (side.lon != null) {
      (isLeft ? _leftLonCtrl : _rightLonCtrl).text =
          side.lon!.toStringAsFixed(5);
    }
  }

  @override
  void dispose() {
    _leftLatCtrl.dispose();
    _leftLonCtrl.dispose();
    _rightLatCtrl.dispose();
    _rightLonCtrl.dispose();
    _leftLabelCtrl.dispose();
    _rightLabelCtrl.dispose();
    super.dispose();
  }

  double? _parseCoord(TextEditingController c, {required bool lat}) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final parsed = parseNavionicsCoordinate(raw, isLatitude: lat);
    if (parsed != null) return parsed;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  MarineCompareSide? _buildSide({
    required bool isLeft,
    required TextEditingController latCtrl,
    required TextEditingController lonCtrl,
    required TextEditingController labelCtrl,
    MarineCompareSide? spotSide,
  }) {
    if (spotSide?.spotId != null) {
      return MarineCompareSide(
        spotId: spotSide!.spotId,
        label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
      );
    }
    final lat = _parseCoord(latCtrl, lat: true);
    final lon = _parseCoord(lonCtrl, lat: false);
    if (lat == null || lon == null) return null;
    return MarineCompareSide(
      lat: lat,
      lon: lon,
      label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
    );
  }

  Future<void> _compare() async {
    final left = _buildSide(
      isLeft: true,
      latCtrl: _leftLatCtrl,
      lonCtrl: _leftLonCtrl,
      labelCtrl: _leftLabelCtrl,
      spotSide: _leftSpotSide,
    );
    final right = _buildSide(
      isLeft: false,
      latCtrl: _rightLatCtrl,
      lonCtrl: _rightLonCtrl,
      labelCtrl: _rightLabelCtrl,
      spotSide: _rightSpotSide,
    );
    if (left == null || right == null) {
      setState(() => _error = 'Her iki taraf için geçerli koordinat veya kayıtlı nokta gerekir.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final resp = await _api.fetchMarineCompare(
        left: left,
        right: right,
        includeAiComment: _includeAiComment,
      );
      if (!mounted) return;
      setState(() => _result = resp);
      unawaited(MarineIntelligenceCache().saveLastCompare(resp));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumHeroCompareIcon(size: 22),
            const SizedBox(width: 8),
            Text(kMarineCompareScreenTitle),
          ],
        ),
        backgroundColor: const Color(0xCC0B1A2A),
      ),
      body: PremiumErrorBoundary(
        sectionTitle: kMarineCompareScreenTitle,
        builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SideInputCard(
            title: kMarineComparePointA,
            latController: _leftLatCtrl,
            lonController: _leftLonCtrl,
            labelController: _leftLabelCtrl,
            spotHint: _leftSpotSide?.spotId != null
                ? 'Kayıtlı nokta: ${_leftSpotSide!.spotId}'
                : null,
          ),
          const SizedBox(height: 12),
          _SideInputCard(
            title: kMarineComparePointB,
            latController: _rightLatCtrl,
            lonController: _rightLonCtrl,
            labelController: _rightLabelCtrl,
            spotHint: _rightSpotSide?.spotId != null
                ? 'Kayıtlı nokta: ${_rightSpotSide!.spotId}'
                : null,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _includeAiComment,
            onChanged: _busy ? null : (v) => setState(() => _includeAiComment = v),
            title: Text(
              kMarineCompareIncludeAiComment,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _compare,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.compare_arrows),
            label: Text(kMarineCompareButton),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ComparisonResultSection(
              result: _result!,
              serverIp: widget.serverIp,
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _SideInputCard extends StatelessWidget {
  const _SideInputCard({
    required this.title,
    required this.latController,
    required this.lonController,
    required this.labelController,
    this.spotHint,
  });

  final String title;
  final TextEditingController latController;
  final TextEditingController lonController;
  final TextEditingController labelController;
  final String? spotHint;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF142434),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF80DEEA),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (spotHint != null) ...[
              const SizedBox(height: 4),
              Text(spotHint!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Etiket',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 8),
            NavionicsCoordinateField(
              label: kLabelLatitude,
              hintText: '36.62123',
              isLatitude: true,
              controller: latController,
            ),
            const SizedBox(height: 8),
            NavionicsCoordinateField(
              label: kLabelLongitude,
              hintText: '29.11234',
              isLatitude: false,
              controller: lonController,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonResultSection extends StatelessWidget {
  const _ComparisonResultSection({
    required this.result,
    required this.serverIp,
  });

  final MarineCompareResponse result;
  final String serverIp;

  @override
  Widget build(BuildContext context) {
    final cmp = result.comparison;
    final winnerTitle = cmp.isTie
        ? kMarineCompareTieTitle
        : kMarineCompareWinnerTitle;
    final winnerName = cmp.isTie
        ? null
        : (cmp.winnerLabel ??
            (cmp.winner == 'left' ? kMarineComparePointA : kMarineComparePointB));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: cmp.isTie ? const Color(0xFF37474F) : const Color(0xFF1B4332),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: winnerTitle,
              value: winnerName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winnerTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (winnerName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      winnerName,
                      style: const TextStyle(color: Color(0xFF80DEEA), fontSize: 18),
                    ),
                  ),
                if (cmp.summaryTr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(cmp.summaryTr, style: const TextStyle(color: Colors.white70)),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _DeltaChip(
                      label: kMarineCompareScoreDelta,
                      value: cmp.scoreDelta,
                    ),
                    _DeltaChip(label: kMarineRiskDeltaLabel, value: cmp.riskDelta),
                    _DeltaChip(
                      label: kMarineConfidenceLabel,
                      value: cmp.confidenceDelta,
                    ),
                  ],
                ),
                if (cmp.decisionDeltaTr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      cmp.decisionDeltaTr,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                if (cmp.riskNoteTr != null && cmp.riskNoteTr!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      cmp.riskNoteTr!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
        if (cmp.mainReasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            kMarineCompareMainReasons,
            style: const TextStyle(
              color: Color(0xFF80DEEA),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final reason in cmp.mainReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white54)),
                  Expanded(
                    child: Text(reason, style: const TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
        ],
        if (result.captainComment != null) ...[
          const SizedBox(height: 16),
          Text(
            kMarineCompareCaptainTitle,
            style: const TextStyle(
              color: Color(0xFF80DEEA),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _CaptainCompareCard(
            comment: result.captainComment!,
            serverIp: serverIp,
          ),
        ],
        const SizedBox(height: 16),
        _SideReportCard(title: kMarineComparePointA, report: result.leftReport),
        const SizedBox(height: 12),
        _SideReportCard(title: kMarineComparePointB, report: result.rightReport),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    return Chip(
      backgroundColor: const Color(0xFF263238),
      label: Text(
        '$label: $sign$value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _CaptainCompareCard extends StatelessWidget {
  const _CaptainCompareCard({
    required this.comment,
    required this.serverIp,
  });

  final MarineAiComment comment;
  final String serverIp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xFF142434),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comment.isFallback)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      kMarineAiCommentFallbackBanner,
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                Text(comment.summaryTr, style: const TextStyle(color: Colors.white)),
                if (comment.bestTimeWindowTr != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$kMarineAiBestTimeLabel: ${comment.bestTimeWindowTr}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (comment.riskNoteTr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    comment.riskNoteTr!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        CaptainAtlasHeroCard(
          title: kMarineCompareCaptainTitle,
          body: comment.summaryTr,
          presence: CaptainAtlasPresence.ready,
          actionLabel: kCaptainAtlasOpenSheet,
          onAsk: () {
            CaptainAtlasLauncher.launch(
              context,
              CaptainAtlasLaunchRequest(
                serverIp: serverIp,
                entryPoint: CaptainAtlasEntryPoint.compare,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SideReportCard extends StatelessWidget {
  const _SideReportCard({required this.title, required this.report});

  final String title;
  final MarineIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF80DEEA),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        MarineReportCards(report: report),
        if (report.decisionTimeline.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            kMarineSectionDecisionTimeline,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          MarineForecastTimeline(items: report.decisionTimeline),
        ],
      ],
    );
  }
}
