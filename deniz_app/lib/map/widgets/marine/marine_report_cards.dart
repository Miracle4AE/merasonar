// Deprecated after UI-4. Kept for backward-compatible widget tests / legacy entry points.
import 'package:deniz_app/domain/marine_consensus_value.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:deniz_app/map/widgets/marine/marine_confidence_gauge.dart';
import 'package:deniz_app/map/widgets/marine/marine_forecast_timeline.dart';
import 'package:deniz_app/map/widgets/marine/provider_comparison_panel.dart';
import 'package:flutter/material.dart';

export 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart'
    show marineDecisionLabelTr, marineDecisionBadgeLabelTr;

class MarineReportCards extends StatelessWidget {
  const MarineReportCards({
    super.key,
    required this.report,
  });

  final MarineIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryHeader(report: report),
        const SizedBox(height: 12),
        if (report.decision != null) ...[
          _DecisionCard(decision: report.decision!),
          const SizedBox(height: 12),
        ],
        if (report.decisionTimeline.isNotEmpty) ...[
          MarineForecastTimeline(items: report.decisionTimeline),
          const SizedBox(height: 12),
        ],
        if (report.scenario != null && report.scenario!.items.isNotEmpty) ...[
          _ScenarioCard(scenario: report.scenario!),
          const SizedBox(height: 12),
        ],
        if (report.aiComment != null) ...[
          _AiCommentCard(comment: report.aiComment!),
          const SizedBox(height: 12),
        ],
        _SectionCard(
          title: kMarineSectionWeather,
          child: _MetricRow('Sıcaklık', report.weather.temperatureC),
          children: [
            _MetricRow('His', report.weather.apparentTemperatureC),
            _MetricRow('Yağış %', report.weather.precipitationProbabilityPct),
            _MetricRow('Nem %', report.weather.relativeHumidityPct),
          ],
        ),
        _SectionCard(
          title: kMarineSectionWind,
          child: _MetricRow('Hız km/h', report.wind.speedKmh),
          children: [
            _MetricRow('Yön', report.wind.directionDeg,
                suffix: report.wind.directionText),
            _MetricRow('Ani rüzgar km/h', report.wind.gustKmh),
          ],
        ),
        _SectionCard(
          title: kMarineSectionSea,
          child: _MetricRow('Dalga m', report.marine.waveHeightM),
          children: [
            _MetricRow('Periyot s', report.marine.wavePeriodS),
            _MetricRow('Su sıc. °C', report.marine.seaSurfaceTemperatureC),
          ],
        ),
        _SectionCard(
          title: kMarineSectionSwell,
          child: _MetricRow('Swell m', report.marine.swellHeightM),
          children: [
            _MetricRow('Periyot s', report.marine.swellPeriodS),
          ],
        ),
        _SectionCard(
          title: kMarineSectionAstronomy,
          child: Text(
            report.astronomy.moonPhase ?? kMarineNoData,
            style: _valueStyle,
          ),
          children: [
            if (report.astronomy.sunrise != null)
              Text('Gün doğumu: ${report.astronomy.sunrise}', style: _subStyle),
            if (report.astronomy.sunset != null)
              Text('Gün batımı: ${report.astronomy.sunset}', style: _subStyle),
            if (report.astronomy.moonIlluminationPct != null)
              Text(
                'Ay aydınlanması: %${report.astronomy.moonIlluminationPct!.toStringAsFixed(0)}',
                style: _subStyle,
              ),
          ],
        ),
        _SectionCard(
          title: kMarineSectionScore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$kMarineSuitabilityLabel: ${report.fishingScore.suitabilityScore}/100',
                style: _valueStyle,
              ),
              Text(
                '$kMarineRiskLabel: ${report.fishingScore.riskScore}/100',
                style: _subStyle,
              ),
              if (report.fishingScore.generalAdviceTr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(report.fishingScore.generalAdviceTr, style: _subStyle),
              ],
              const SizedBox(height: 8),
              MarineConfidenceGauge(confidence: report.fishingScore.confidence),
            ],
          ),
        ),
        if (report.providerComparison != null &&
            report.providerComparison!.providers.isNotEmpty)
          ProviderComparisonPanel(comparison: report.providerComparison!),
        if (report.explainability != null)
          _SectionCard(
            title: kMarineSectionExplain,
            child: _ExplainBlock(explain: report.explainability!),
          ),
        if (report.tide != null ||
            report.fishActivity != null ||
            report.marineRisk != null)
          _SectionCard(
            title: kMarinePlaceholderFuture,
            child: Text(kMarinePlaceholderFuture, style: _subStyle),
          ),
      ],
    );
  }

  static const _valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _subStyle = TextStyle(color: Colors.white70, height: 1.35);
}

Color marineDecisionColor(String? decision) {
  switch (decision) {
    case 'excellent':
      return Colors.greenAccent;
    case 'good':
      return const Color(0xFF81C784);
    case 'borderline':
      return Colors.amber;
    case 'poor':
      return Colors.orangeAccent;
    case 'unsafe':
      return Colors.redAccent;
    default:
      return Colors.white54;
  }
}

String formatDeltaScore(int? delta) {
  if (delta == null) return '—';
  if (delta > 0) return '+$delta';
  return delta.toString();
}

class _AiCommentCard extends StatelessWidget {
  const _AiCommentCard({required this.comment});

  final MarineAiComment comment;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF142434),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF80DEEA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF80DEEA).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    comment.assistantName.isNotEmpty
                        ? comment.assistantName
                        : kMarineCaptainAtlasChip,
                    style: const TextStyle(
                      color: Color(0xFF80DEEA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kMarineSectionAiComment,
                    style: const TextStyle(
                      color: Color(0xFF80DEEA),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (comment.isFallback) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Text(
                  kMarineAiCommentFallbackBanner,
                  style: const TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ),
            ],
            if (comment.summaryTr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(comment.summaryTr, style: MarineReportCards._valueStyle),
            ],
            if (comment.bestTimeWindowTr != null &&
                comment.bestTimeWindowTr!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '$kMarineAiBestTimeLabel: ${comment.bestTimeWindowTr}',
                style: MarineReportCards._subStyle,
              ),
            ],
            if (comment.riskNoteTr != null && comment.riskNoteTr!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '$kMarineAiRiskLabel: ${comment.riskNoteTr}',
                style: MarineReportCards._subStyle,
              ),
            ],
            if (comment.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(kMarineAiRecommendedActionsLabel, style: MarineReportCards._subStyle),
              for (final action in comment.recommendedActions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.titleTr, style: MarineReportCards._valueStyle),
                      if (action.detailTr.isNotEmpty)
                        Text(action.detailTr, style: MarineReportCards._subStyle),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final MarineScenarioBundle scenario;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF142434),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kMarineSectionScenario,
              style: const TextStyle(
                color: Color(0xFF80DEEA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in scenario.items) _ScenarioRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.item});

  final MarineScenarioItem item;

  @override
  Widget build(BuildContext context) {
    final color = marineDecisionColor(item.decision);
    final label = marineDecisionLabelTr(item.decision);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.titleTr, style: MarineReportCards._valueStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '$kMarineGoScoreDeltaLabel: ${formatDeltaScore(item.deltaGoScore)}',
                style: MarineReportCards._subStyle,
              ),
              Text(
                '$kMarineRiskDeltaLabel: ${formatDeltaScore(item.deltaRiskScore)}',
                style: MarineReportCards._subStyle,
              ),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          if (item.deltaSummaryTr != null && item.deltaSummaryTr!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.deltaSummaryTr!, style: MarineReportCards._subStyle),
            ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision});

  final MarineDecision decision;

  @override
  Widget build(BuildContext context) {
    final label = marineDecisionLabelTr(decision.fishingDecision);
    final color = marineDecisionColor(decision.fishingDecision);
    return Card(
      color: const Color(0xFF1A3348),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kMarineSectionDecision,
              style: const TextStyle(
                color: Color(0xFF80DEEA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${decision.goScore ?? '—'}',
                  style: TextStyle(
                    color: color,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    kMarineGoScoreLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (decision.waitScore != null) ...[
              const SizedBox(height: 6),
              Text(
                '$kMarineWaitScoreLabel: ${decision.waitScore}',
                style: MarineReportCards._subStyle,
              ),
            ],
            if (decision.bestActionTr != null &&
                decision.bestActionTr!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(decision.bestActionTr!, style: MarineReportCards._valueStyle),
            ],
            if (decision.shortSummaryTr != null &&
                decision.shortSummaryTr!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(decision.shortSummaryTr!, style: MarineReportCards._subStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.report});

  final MarineIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A3348),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.coordinate.lat.toStringAsFixed(5)}, ${report.coordinate.lon.toStringAsFixed(5)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Güncelleme: ${report.updatedAt}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (report.cacheHit)
                  _Badge(label: kMarineCacheHitBadge, color: Colors.blueGrey),
                if (report.partialData)
                  _Badge(label: kMarinePartialDataBadge, color: Colors.orange),
                _Badge(
                  label:
                      '$kMarineConfidenceLabel: ${(report.consensusSummary.overallConfidence * 100).toStringAsFixed(0)}%',
                  color: const Color(0xFF4DD0E1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.children = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: const Color(0xFF142434),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF80DEEA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              child,
              ...children.map(
                (w) => Padding(padding: const EdgeInsets.only(top: 4), child: w),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value, {this.suffix});

  final String label;
  final MarineConsensusValue? value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final v = value?.finalValue;
    final text = v != null
        ? '${v.toStringAsFixed(1)}${suffix != null ? ' ($suffix)' : ''}'
        : kMarineNoData;
    return Text('$label: $text', style: MarineReportCards._subStyle);
  }
}

class _ExplainBlock extends StatelessWidget {
  const _ExplainBlock({required this.explain});

  final MarineExplainability explain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (explain.explanationSummaryTr != null)
          Text(explain.explanationSummaryTr!, style: MarineReportCards._valueStyle),
        for (final f in explain.positiveFactors)
          Text('• $f', style: const TextStyle(color: Colors.greenAccent)),
        for (final f in explain.negativeFactors)
          Text('• $f', style: const TextStyle(color: Colors.orangeAccent)),
        for (final f in explain.uncertaintyFactors)
          Text('• $f', style: const TextStyle(color: Colors.amber)),
      ],
    );
  }
}
