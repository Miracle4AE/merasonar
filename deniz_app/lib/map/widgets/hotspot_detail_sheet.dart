import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../domain/geo_visualization_state.dart';
import '../../domain/hotspot_geo_metrics_presentation.dart';
import '../../l10n/app_strings_tr.dart';
import '../../services/ai_assistant_cache.dart';
import '../../services/client_identity_service.dart';
import '../../services/gpx_share.dart';
import '../../utils/layout_breakpoints.dart';
import '../../config/app_config.dart';
import '../../navigation/captain_atlas_launcher.dart';
import '../../utils/premium_haptics.dart';

class HotspotDetailSheet extends StatelessWidget {
  const HotspotDetailSheet({
    super.key,
    required this.hotspot,
    this.geoVisualization,
    this.boatPosition,
    this.apiService,
    this.sessionAnalysis,
    this.aiAssistantCache,
    this.clientIdentityService,
    this.slidePanel = false,
  });

  final Hotspot hotspot;

  /// Harita oturumu geo politikası; null ise yalnızca hotspot [mappingTrust] kullanılır.
  final GeoVisualizationState? geoVisualization;

  /// Tekne konumu biliniyorsa (GPS), distance/bearing hesaplamak için kullanılır.
  final LatLon? boatPosition;

  /// Oturum analizi ve AI servisi — üçü de doluysa "AI ile Açıkla" gösterilir.
  final ApiService? apiService;
  final FishingZoneResponse? sessionAnalysis;
  final AiAssistantCache? aiAssistantCache;
  final ClientIdentityService? clientIdentityService;
  final bool slidePanel;

  bool get _canOpenAi =>
      apiService != null &&
      sessionAnalysis != null &&
      aiAssistantCache != null &&
      clientIdentityService != null;

  @override
  Widget build(BuildContext context) {
    if (slidePanel) {
      return _buildSlidePanelBody(context);
    }
    final mobile = useMobileLayout(context);
    final badgeColor = _classificationColor(hotspot.classification);
    final geoMetrics = HotspotGeoMetricsPresentation.fromHotspot(
      hotspot,
      geoVisualization: geoVisualization,
      boatPosition: boatPosition,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: mobile ? 0.55 : 0.78,
      minChildSize: mobile ? 0.35 : 0.48,
      maxChildSize: mobile ? 0.92 : 0.96,
      builder: (context, scrollController) {
        return Material(
          color: const Color(0xFF0A1A2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mera Detayı',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        '${hotspot.classification} Sınıfı',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _maritimePositionSection(geoMetrics),
                const SizedBox(height: 12),
                if (hotspot.reasoningText.isNotEmpty) ...[
                  _adviceCard(
                    title: 'Balıkçılık özeti',
                    child: Text(
                      hotspot.reasoningText,
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        height: 1.38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (hotspot.fishPrediction.isNotEmpty) ...[
                  _adviceCard(
                    title: 'Tür tahmini',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 8),
                          child: Text(
                            '🐟',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            hotspot.fishPrediction,
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (hotspot.recommendationRank < 999999 &&
                    hotspot.recommendationRank >= 1) ...[
                  _visitPriorityBanner(),
                  const SizedBox(height: 12),
                ],
                if (_canOpenAi) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        PremiumHaptics.light();
                        CaptainAtlasLauncher.launch(
                          context,
                          CaptainAtlasLaunchRequest(
                            serverIp: AppConfig.normalizeHost(
                              apiService!.serverBaseUrl,
                            ),
                            entryPoint: CaptainAtlasEntryPoint.hotspotDetail,
                            analysis: sessionAnalysis!,
                            hotspotId: hotspot.id,
                            apiService: apiService,
                            aiCache: aiAssistantCache,
                            clientIdentity: clientIdentityService,
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text(kAiAssistantHotspotButtonLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF114B5F),
                        foregroundColor: const Color(0xFF32D9FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      GpxShare.shareHotspots(
                        context,
                        hotspots: [hotspot],
                        shareText: kHotspotGpxShareCaption(hotspot.classification),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Bu noktayı GPX olarak paylaş'),
                  ),
                ),
                const SizedBox(height: 12),
                _metricRow('Skor', hotspot.score.toStringAsFixed(3)),
                _metricRow('Özellik Türü', _translateFeature(hotspot.featureType)),
                _metricRow('Güven Durumu', _trustStateLabel(hotspot.trustState)),
                _metricRow('Hizalama', _mappingTrustLabel(hotspot.mappingTrust)),
                _metricRow(
                  'Görünüm',
                  hotspot.isRenderable
                      ? 'Gösterilebilir'
                      : 'Şüpheli (gizlenmeli)',
                ),
                _metricRow('Genel Sıra', '${hotspot.rankByScoreThenDistance}'),
                _metricRow('Yakınlık Sırası', '${hotspot.rankByProximity}'),
                const SizedBox(height: 10),
                _sourceCard(),
                const SizedBox(height: 12),
                const Text(
                  'Neden Seçildi?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (hotspot.reasoning.isEmpty)
                  const Text(
                    'Bu nokta için seçim gerekçesi şu anda oluşturulmadı.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hotspot.reasoning
                        .map(
                          (r) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              _translateReason(r),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 14),
                const Text(
                  'Meteoroloji & Akıntı',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _marineWeatherCard(),
                const SizedBox(height: 10),
                _depthCard(),
                const SizedBox(height: 10),
                _biodiversityCard(),
                const SizedBox(height: 10),
                _regionalSpeciesContextCard(),
                const SizedBox(height: 10),
                _speciesMatchCard(context),
                const SizedBox(height: 10),
                ExpansionTile(
                  collapsedIconColor: Colors.white70,
                  iconColor: Colors.white,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text(
                    'Teknik Ölçümler',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    if (hotspot.supportingMetrics.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Teknik metrik bulunmuyor.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ...hotspot.supportingMetrics.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _metricRow(
                            _metricLabel(e.key),
                            _formatMetricValue(e.value),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Av Tavsiyesi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _adviceCard(
                  title: 'Olası Türler',
                  child: hotspot.fishingAdvice.speciesPredictions.isEmpty
                      ? const Text(
                          'Bu nokta için tür tahmini şu anda üretilemedi.',
                          style: TextStyle(color: Colors.white70),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: hotspot.fishingAdvice.speciesPredictions
                              .map(
                                (p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• ${p.species} · Olasılık: ${localizeFishPredictionProbability(p.probability)}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                _adviceCard(
                  title: 'Yem Önerisi',
                  child: _bulletList(hotspot.fishingAdvice.bait),
                ),
                _adviceCard(
                  title: 'En Uygun Av Saatleri',
                  child: _bulletList(hotspot.fishingAdvice.bestTimes),
                ),
                _adviceCard(
                  title: 'Takım Önerisi',
                  child: _bulletList(hotspot.fishingAdvice.tackle),
                ),
                _adviceCard(
                  title: 'Neden Bu Türler?',
                  child: _bulletList(hotspot.fishingAdvice.selectionReasons),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildSlidePanelBody(BuildContext context) {
    final badgeColor = _classificationColor(hotspot.classification);
    final geoMetrics = HotspotGeoMetricsPresentation.fromHotspot(
      hotspot,
      geoVisualization: geoVisualization,
      boatPosition: boatPosition,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _detailSectionWidgets(context, geoMetrics, badgeColor),
      ),
    );
  }

  List<Widget> _detailSectionWidgets(
    BuildContext context,
    HotspotGeoMetricsPresentation geoMetrics,
    Color badgeColor,
  ) {
    return [
      _maritimePositionSection(geoMetrics),
      const SizedBox(height: 12),
      if (hotspot.reasoningText.isNotEmpty) ...[
        _adviceCard(
          title: 'Balıkçılık özeti',
          child: Text(
            hotspot.reasoningText,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              height: 1.38,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (hotspot.fishPrediction.isNotEmpty) ...[
        _adviceCard(
          title: 'Tür tahmini',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text(
                  '🐟',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: Text(
                  hotspot.fishPrediction,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    height: 1.38,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (hotspot.recommendationRank < 999999 && hotspot.recommendationRank >= 1) ...[
        _visitPriorityBanner(),
        const SizedBox(height: 12),
      ],
      if (_canOpenAi) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () {
              PremiumHaptics.light();
              CaptainAtlasLauncher.launch(
                context,
                CaptainAtlasLaunchRequest(
                  serverIp: AppConfig.normalizeHost(apiService!.serverBaseUrl),
                  entryPoint: CaptainAtlasEntryPoint.hotspotDetail,
                  analysis: sessionAnalysis!,
                  hotspotId: hotspot.id,
                  apiService: apiService,
                  aiCache: aiAssistantCache,
                  clientIdentity: clientIdentityService,
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text(kAiAssistantHotspotButtonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF114B5F),
              foregroundColor: const Color(0xFF32D9FF),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () {
            GpxShare.shareHotspots(
              context,
              hotspots: [hotspot],
              shareText: kHotspotGpxShareCaption(hotspot.classification),
            );
          },
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text('Bu noktayı GPX olarak paylaş'),
        ),
      ),
      const SizedBox(height: 12),
      _metricRow('Skor', hotspot.score.toStringAsFixed(3)),
      _metricRow('Özellik Türü', _translateFeature(hotspot.featureType)),
      _metricRow('Güven Durumu', _trustStateLabel(hotspot.trustState)),
      _metricRow('Hizalama', _mappingTrustLabel(hotspot.mappingTrust)),
      _metricRow(
        'Görünüm',
        hotspot.isRenderable ? 'Gösterilebilir' : 'Şüpheli (gizlenmeli)',
      ),
      _metricRow('Genel Sıra', '${hotspot.rankByScoreThenDistance}'),
      _metricRow('Yakınlık Sırası', '${hotspot.rankByProximity}'),
      const SizedBox(height: 10),
      _sourceCard(),
      const SizedBox(height: 12),
      const Text(
        'Neden Seçildi?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (hotspot.reasoning.isEmpty)
        const Text(
          'Bu nokta için seçim gerekçesi şu anda oluşturulmadı.',
          style: TextStyle(color: Colors.white70),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hotspot.reasoning
              .map(
                (r) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _translateReason(r),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      const SizedBox(height: 14),
      const Text(
        'Meteoroloji & Akıntı',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      _marineWeatherCard(),
      const SizedBox(height: 10),
      _depthCard(),
      const SizedBox(height: 10),
      _biodiversityCard(),
      const SizedBox(height: 10),
      _regionalSpeciesContextCard(),
      const SizedBox(height: 10),
      _speciesMatchCard(context),
      const SizedBox(height: 10),
      ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          'Teknik Ölçümler',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          if (hotspot.supportingMetrics.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Teknik metrik bulunmuyor.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            ...hotspot.supportingMetrics.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _metricRow(
                  _metricLabel(e.key),
                  _formatMetricValue(e.value),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'Av Tavsiyesi',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      _adviceCard(
        title: 'Olası Türler',
        child: hotspot.fishingAdvice.speciesPredictions.isEmpty
            ? const Text(
                'Bu nokta için tür tahmini şu anda üretilemedi.',
                style: TextStyle(color: Colors.white70),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: hotspot.fishingAdvice.speciesPredictions
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${p.species} · Olasılık: ${localizeFishPredictionProbability(p.probability)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
      _adviceCard(
        title: 'Yem Önerisi',
        child: _bulletList(hotspot.fishingAdvice.bait),
      ),
      _adviceCard(
        title: 'En Uygun Av Saatleri',
        child: _bulletList(hotspot.fishingAdvice.bestTimes),
      ),
      _adviceCard(
        title: 'Takım Önerisi',
        child: _bulletList(hotspot.fishingAdvice.tackle),
      ),
      _adviceCard(
        title: 'Neden Bu Türler?',
        child: _bulletList(hotspot.fishingAdvice.selectionReasons),
      ),
    ];
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metricLabel(String raw) {
    const trMap = {
      'slope': 'Eğim',
      'contour_density': 'Kontur Sıkılığı',
      'local_relief': 'Yerel Kabartı',
      'dropoff_proximity': 'Kırığa Yakınlık',
      'basin_likelihood': 'Çanak Olasılığı',
      'ridge_likelihood': 'Sırt Olasılığı',
      'transition_band': 'Geçiş Bandı',
      'ridge_tip': 'Sırt Ucu Sinyali',
      'saddle': 'Boyun/Geçit Sinyali',
      'structure_intersection': 'Yapı Kesişimi',
      'breakline_edge': 'Kırık Başlangıcı',
      'isolated_peak': 'İzole Tepe',
      'pocket': 'Küçük Çukur',
      'raw_score': 'Ham Algoritma Skoru',
      'structure_stack_bonus': 'Çoklu Yapı Bonusu',
      'flat_penalty': 'Düzlük Cezası',
      'invalid_region_penalty': 'Geçersiz Bölge Cezası',
      'structure_score': 'Yapı Skoru',
    };
    return trMap[raw.toLowerCase()] ?? raw;
  }

  String _translateFeature(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('drop')) return 'Derinlik Kırığı (Yamaç)';
    if (normalized.contains('ridge')) return 'Sırt / Çıkıntı';
    if (normalized.contains('basin')) return 'Çanak / Çukur';
    if (normalized.contains('shelf')) return 'Sığlık Geçişi';
    return raw;
  }

  String _translateReason(String raw) {
    const map = {
      'High contour density': 'Yüksek kontur sıkılığı (Keskin eğim)',
      'Near strong depth transition': 'Güçlü derinlik geçişine yakın',
      'Located on likely drop-off edge': 'Muhtemel derinlik kırığı kenarında',
      'Low-relief basin transition': 'Hafif çanak/çukur geçişi',
      'Ridge-like structure with feeding potential':
          'Beslenme potansiyeli yüksek sırt yapısı',
      'Transition-band suitability': 'Geçiş bandı uygunluğu',
      'Ridge tip (sırt ucu)': 'Sırt Ucu (Pusu Noktası)',
      'Saddle (geçit/boyun)': 'Boyun / Geçit (Balık Yolu)',
      'Structure intersection (kesişim)': 'Yapı Kesişimi (Kritik Nokta)',
      'Breakline edge (kırık başlangıcı)': 'Derinlik Kırığı Başlangıcı',
      'Isolated peak (izole tepe)': 'İzole Tepe (Tek Yükselti)',
      'Pocket (küçük çukur)': 'Küçük Çukur (Gizlenme Alanı)',
      'Structure stack bonus': 'Çoklu Yapı Bonusu (Güçlü Sinyal)',
      'Moderate multi-factor bathymetric signal':
          'Orta düzey çoklu batimetrik sinyal',
    };
    return map[raw] ?? raw;
  }

  String _formatMetricValue(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(3);
    }
    return value?.toString() ?? '-';
  }

  Widget _adviceCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x221F2A38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _visitPriorityBanner() {
    return _adviceCard(
      title: 'Ziyaret önceliği (olasılıksal)',
      child: Text(
        'Bu analiz kutusunda önerilen sıra: #${hotspot.recommendationRank} '
        '(birleşik skor ${hotspot.finalFishingScore}/100). '
        'Yalnızca olası görüş sırası ipucudur; başarı, balık varlığı veya av sonucu için garanti değildir.',
        style: const TextStyle(
          color: Color(0xE6FFFFFF),
          height: 1.38,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Konum bilgisi üst bölümde sabit; güven durumuna göre gerçek veya yer tutucu değer.
  Widget _maritimePositionSection(HotspotGeoMetricsPresentation p) {
    final showBoatEstimated =
        geoVisualization?.coordinateMode == kCoordinateModeBoatAnchorEstimated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132635),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A4A62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.explore_rounded,
                size: 20,
                color: p.isNumericContext
                    ? const Color(0xFF69F0AE)
                    : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kHotspotGeoMaritimeSectionTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (showBoatEstimated) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '$kHotspotGeoBoatAnchorEstimatedLabel — '
                '$kHotspotGeoBoatAnchorEstimatedDebugNote',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _metricRow('Enlem', p.latitudeText),
          _metricRow('Boylam', p.longitudeText),
          _metricRow('Mesafe', p.distanceText),
          _metricRow('Kerteriz', p.bearingText),
        ],
      ),
    );
  }

  Widget _sourceCard() {
    final seaState = hotspot.seaState;
    final depth = hotspot.confirmedDepth;
    final species = hotspot.likelySpecies;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Veri kaynağı',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sourceChip(
                'Hava',
                _sourceLabel(source: seaState.source, fallback: seaState.fallback),
                seaState.fallback,
              ),
              _sourceChip(
                'Derinlik',
                _sourceLabel(source: depth.source, fallback: depth.fallback),
                depth.fallback,
              ),
              _sourceChip(
                'Tür gözlemi',
                _sourceLabel(source: species.source, fallback: species.fallback),
                species.fallback,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marineWeatherCard() {
    final seaState = hotspot.seaState;
    final src = seaState.source.trim().toLowerCase();
    final reason = (seaState.reason ?? '').trim().toLowerCase();
    if (src == 'requires_gps_or_server' ||
        reason == 'image_space_no_boat_gps' ||
        reason == 'marine_client_unavailable') {
      return _adviceCard(
        title: 'Meteoroloji / deniz durumu',
        child: Text(
          reason == 'marine_client_unavailable'
              ? '$kEnrichWeatherBoatGpsFailed\n$kEnrichWeatherServerHint'
              : kEnrichWeatherBoatGpsFailed,
          style: const TextStyle(color: Color(0xE6FFFFFF), height: 1.38),
        ),
      );
    }
    final rows = <Widget>[
      if (seaState.marineAtBoatPosition)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            kEnrichWeatherBoatScopeNote,
            style: TextStyle(
              color: Color(0xFFB2EBF2),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      _metricRow(
        'Kaynak',
        _sourceLabel(source: seaState.source, fallback: seaState.fallback),
      ),
      if (seaState.windSpeedKnots != null || seaState.windDirectionDeg != null)
        _metricRow(
          'Rüzgar',
          _formatSpeedDirection(
            speed: seaState.windSpeedKnots,
            directionDeg: seaState.windDirectionDeg,
          ),
        ),
      if (seaState.currentSpeedKnots != null ||
          seaState.currentDirectionDeg != null)
        _metricRow(
          'Akıntı',
          _formatSpeedDirection(
            speed: seaState.currentSpeedKnots,
            directionDeg: seaState.currentDirectionDeg,
          ),
        ),
      if (seaState.oceanCurrentVelocityMps != null)
        _metricRow(
          'Akıntı hızı',
          '${seaState.oceanCurrentVelocityMps!.toStringAsFixed(2)} m/s',
        ),
      if (seaState.pressureHpa != null)
        _metricRow('Basınç', '${seaState.pressureHpa!.toStringAsFixed(0)} hPa'),
      if (seaState.waveHeightM != null)
        _metricRow('Dalga', '${seaState.waveHeightM!.toStringAsFixed(1)} m'),
      if (seaState.waterTemperatureC != null)
        _metricRow(
          'Su sıcaklığı',
          '${seaState.waterTemperatureC!.toStringAsFixed(1)} °C',
        ),
    ];

    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x143FA7D6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x553FA7D6)),
        ),
        child: const Text(
          'Canlı meteoroloji verisi alınamadı.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x2232B5FF), Color(0x2216E0A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: rows,
      ),
    );
  }

  Widget _depthCard() {
    final depth = hotspot.confirmedDepth;
    if (depth.source.trim().toLowerCase() == 'calibration_required') {
      return _adviceCard(
        title: 'Teyit derinliği',
        child: const Text(
          kEnrichDepthRequiresCalib,
          style: TextStyle(color: Color(0xE6FFFFFF), height: 1.38),
        ),
      );
    }
    if (depth.depthM == null && (depth.reason ?? '').trim().isEmpty) {
      return _adviceCard(
        title: 'Teyit derinliği',
        child: const Text(
          'Bu nokta için teyit derinliği şu anda üretilemedi.',
          style: TextStyle(color: Colors.white70, height: 1.38),
        ),
      );
    }
    return _adviceCard(
      title: 'Teyit derinliği',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricRow(
            'Kaynak',
            _sourceLabel(source: depth.source, fallback: depth.fallback),
          ),
          _metricRow(
            'Derinlik',
            depth.depthM == null ? 'Mevcut değil' : '${depth.depthM!.toStringAsFixed(1)} m',
          ),
          if (depth.rawElevationM != null)
            _metricRow(
              'Ham yükseklik',
              '${depth.rawElevationM!.toStringAsFixed(1)} m',
            ),
          if (depth.dataset != null) _metricRow('Veri kümesi', depth.dataset!),
          if (depth.reason != null) _metricRow('Not', depth.reason!),
        ],
      ),
    );
  }

  /// OBIS/GBIF özeti; kullanıcıya çerçeveli gösterilir (ham İngilizce doğrudan tek başına değil).
  Widget _regionalSpeciesContextCard() {
    final raw = hotspot.regionalSpeciesContext;
    if (raw != null && raw.trim().isNotEmpty) {
      return _adviceCard(
        title: 'Bölgesel tür bağlamı',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              kRegionalSpeciesContextFraming,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              kRegionalSpeciesContextSourceNote,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              raw.trim(),
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                height: 1.38,
              ),
            ),
          ],
        ),
      );
    }
    if (hotspot.mappingTrust == 'image_space') {
      return _adviceCard(
        title: 'Bölgesel tür bağlamı',
        child: const Text(
          kHotspotRegionalSpeciesRequiresCalib,
          style: TextStyle(
            color: Color(0xE6FFFFFF),
            height: 1.38,
          ),
        ),
      );
    }
    return _adviceCard(
      title: 'Bölgesel tür bağlamı',
      child: const Text(
        'Bu nokta için bölgesel tür özeti şu anda üretilemedi.',
        style: TextStyle(color: Colors.white70, height: 1.38),
      ),
    );
  }

  Widget _speciesMatchCard(BuildContext context) {
    final items = hotspot.speciesMatch;
    if (items.isEmpty) {
      return _adviceCard(
        title: 'Yapı × bölgesel tür uyumu',
        child: const Text(
          'Bu nokta için yapı × bölgesel tür uyumu sinyali üretilemedi.',
          style: TextStyle(color: Colors.white70, height: 1.38),
        ),
      );
    }

    Color confColor(String c) {
      final x = c.toLowerCase().trim();
      if (x == 'high' || x == 'yüksek') return const Color(0xFF81C784);
      if (x == 'medium' || x == 'orta') return const Color(0xFFFFB74D);
      if (x == 'low' || x == 'düşük') return Colors.white70;
      return Colors.white70;
    }

    return _adviceCard(
      title: 'Yapı × bölgesel tür uyumu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yerel batimetri ile bölgesel veri listeleri birlikte değerlendirilir; '
            'kesin sonuç iddiası yoktur.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizeSpeciesGroupSlug(m.species),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: confColor(m.confidence).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: confColor(m.confidence).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          localizeUiConfidenceWord(m.confidence),
                          style: TextStyle(
                            color: confColor(m.confidence),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.reason,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      height: 1.38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _biodiversityCard() {
    final biodiversity = hotspot.likelySpecies;
    if (biodiversity.source.trim().toLowerCase() == 'calibration_required' ||
        (biodiversity.reason ?? '').trim().toLowerCase() == 'image_space') {
      return _adviceCard(
        title: 'Biyoçeşitlilik sinyali',
        child: const Text(
          kEnrichBiodiversityRequiresCalib,
          style: TextStyle(color: Color(0xE6FFFFFF), height: 1.38),
        ),
      );
    }

    final source = biodiversity.source.trim().toLowerCase();
    final confidence = (biodiversity.confidence ?? '').trim().toLowerCase();
    final isApprox =
        source == 'rule_based_fallback' || confidence == 'approximate';
    final hasVerifiedCounts =
        biodiversity.topSpecies.any((e) => e.occurrenceCount > 0);
    return _adviceCard(
      title: 'Biyoçeşitlilik sinyali',
      child:
          biodiversity.topSpecies.isEmpty
              ? Text(
                biodiversity.fallback
                    ? 'Bu nokta için harici tür verisi şu anda alınamadı.'
                    : 'Bu nokta için tür gözlem kaydı bulunamadı.',
                style: const TextStyle(color: Colors.white70),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isApprox)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFC107),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x66FFC107)),
                      ),
                      child: const Text(
                        'Yaklaşık sinyal',
                        style: TextStyle(
                          color: Color(0xFFFFF3CD),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (isApprox) const SizedBox(height: 8),
                  _metricRow(
                    'Kaynak',
                    _sourceLabel(
                      source: biodiversity.source,
                      fallback: biodiversity.fallback,
                    ),
                  ),
                  if (!isApprox)
                    _metricRow(
                      'Kayıt sayısı',
                      '${biodiversity.totalRecordsConsidered}',
                    ),
                  if (isApprox && !hasVerifiedCounts)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(
                        'Dış tür kaydı doğrulanmadı; yapı ve av tavsiyesine göre yaklaşık tür sinyali gösterilir.',
                        style: TextStyle(color: Colors.white70, height: 1.38),
                      ),
                    ),
                  const SizedBox(height: 6),
                  ...biodiversity.topSpecies.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        entry.occurrenceCount > 0
                            ? '• ${entry.species} (${entry.occurrenceCount})'
                            : '• ${entry.species}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _bulletList(List<String> values) {
    if (values.isEmpty) {
      return const Text(
        'Bu bölüm için öneri şu anda üretilemedi.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $e', style: const TextStyle(color: Colors.white)),
            ),
          )
          .toList(growable: false),
    );
  }

  String _trustStateLabel(String raw) {
    switch (raw) {
      case 'trusted':
        return 'Güvenilir';
      case 'suspicious_low_water_confidence':
        return 'Şüpheli (düşük su güveni)';
      case 'suspicious_near_land':
        return 'Şüpheli (kara yakınında)';
      case 'suspicious_coastline_collision':
        return 'Şüpheli (kıyı çakışması)';
      default:
        return 'Şüpheli / belirsiz';
    }
  }

  String _mappingTrustLabel(String raw) {
    switch (raw) {
      case 'chart_aligned':
        return 'Ekran görüntüsü hizalaması';
      case 'image_space':
        return 'Yalnızca görüntü uzayı';
      case 'approximate_world_fallback':
      default:
        return 'Yaklaşık dünya haritası hizalaması';
    }
  }

  Widget _sourceChip(String label, String value, bool fallback) {
    final borderColor =
        fallback ? const Color(0xFFFFB300) : const Color(0xFF32D9FF);
    final fillColor =
        fallback ? const Color(0x33FFB300) : const Color(0x3332D9FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  String _sourceLabel({required String source, required bool fallback}) {
    final trimmed = source.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') {
      return fallback ? 'tahmini veri' : kEnrichWeatherServerHint;
    }
    final normalized = localizeSeaDataSource(trimmed);
    return fallback ? '$normalized (tahmini)' : normalized;
  }

  Color _classificationColor(String c) {
    switch (c.toUpperCase()) {
      case 'A':
        return const Color(0xFFFF5252);
      case 'B':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF66BB6A);
    }
  }

  String _formatSpeedDirection({
    required double? speed,
    required double? directionDeg,
  }) {
    final speedPart = speed == null ? '-' : '${speed.toStringAsFixed(1)} kn';
    final directionPart = directionDeg == null
        ? ''
        : ' (${directionDeg.toStringAsFixed(0)}° ${_directionLabel(directionDeg)})';
    return '$speedPart$directionPart';
  }

  String _directionLabel(double degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return 'K';
    if (normalized < 67.5) return 'KD';
    if (normalized < 112.5) return 'D';
    if (normalized < 157.5) return 'GD';
    if (normalized < 202.5) return 'G';
    if (normalized < 247.5) return 'GB';
    if (normalized < 292.5) return 'B';
    return 'KB';
  }
}
