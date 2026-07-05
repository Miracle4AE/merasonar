// Türkçe arayüz metinleri — ileride i18n için tek giriş noktası.

// —— Genel ağ / sunucu ——
const String kMsgSunucuyaUlasilamiyor = 'Şu an sunucuya bağlanılamıyor';
const String kMsgNetworkRetryHint =
    'Aynı Wi‑Fi üzerinden bağlandığınızdan emin olun; sunucu adresini Ayarlar’dan güncelleyebilirsiniz.';
const String kMsgAnalysisTimeout =
    'Analiz zaman aşımına uğradı. Büyük harita görsellerinde birkaç dakika sürebilir; tekrar deneyin.';
const String kMsgAnalysisCachedWhileServerUp =
    'Kayıtlı görünüm korunuyor. Sunucu bağlı — analizi yeniden çalıştırmayı deneyin.';
String kMsgAnalysisHttpError(int code) =>
    'Analiz isteği tamamlanamadı (HTTP $code). Tekrar deneyin.';

/// `/api/v1/live_fishing_score` 404 veya 8000’de yanlış servis olduğunda.
const String kMsgLiveScoreEndpointMissing =
    'Canlı skor için gerekli API yolu sunucuda yok (404). Genelde sebep: 8000 bağlantı noktasını '
    'MeraSonar API’si yerine başka bir uygulamanın kullanmasıdır. Yerelde `run_api.cmd` ile sunucuyu '
    'yeniden başlatın veya uyumsuz süreci kapatın.';

// —— Canlı alan (Live Area) ——
const String kLiveAreaAppBarTitle = 'Canlı Alan';
const String kLiveAreaSectionHowToRead = 'Bu ekran nasıl okunur';
const String kUxFishDetectNoDetect =
    'Bu uygulama balığı doğrudan tespit etmez.';
const String kUxLiveGuidanceBasis =
    'Canlı öneriler konumunuza ve mevcut analizlere göre oluşturulur.';
const String kUxCalibratedRequired =
    'Mesafeye dayalı hotspot önerileri için harita koordinatlarının kalibre edilmiş olması gerekir.';
const String kTrustAlways =
    'Canlı öneriler olasılık temellidir ve av başarısı garantisi vermez.';
const String kTrustSecondaryLine =
    'Bu bilgiler yol göstericidir; kesin bir av sonucu vaat etmez.';

const String kNearbyModeImageSpace =
    'Bu analiz yalnızca görüntüye dayanır. Canlı yönlendirme için haritayı kalibre edin.';
const String kNearbyModeUnknown =
    'Konum referansı bulunamadı. Canlı öneriler için kalibre analiz çalıştırın.';

const String kCalibrateMapMicroExplanation =
    'Kalibrasyon, haritanızı gerçek dünya koordinatlarına bağlar; canlı yönlendirme ve mesafeye dayalı öneriler açılır.';

const String kSectionCurrentPosition = 'Mevcut konum';
const String kSectionLiveScore = 'Canlı balıkçılık skoru';
const String kSectionNearbyHotspot = 'Yakındaki hotspot (son analiz)';
const String kSectionSafetyTrust = 'Güvenlik / Bilgilendirme';

const String kAutoRefreshLabel = 'Otomatik (10 sn)';
const String kTooltipRefresh = 'Yenile';
const String kCalibrateMapButton = 'Haritayı Kalibre Et';

const String kGpsServiceOff = 'Bu cihazda konum hizmetleri kapalı.';
const String kGpsPermissionDenied = 'Konum izni verilmedi.';
const String kGpsPermissionDeniedForever =
    'Konum izni kalıcı olarak reddedildi. Sistem ayarlarından açın.';
const String kGpsFixFailed = 'Konum alınamadı. Açık alanda tekrar deneyin.';
const String kGpsUnavailable = 'Konum bilgisi yok.';
const String kGpsWaiting = 'Konum bekleniyor…';
const String kGpsAccuracyHighSuffix =
    'Konum belirsizliği yüksek (>50 m). Açık alana geçin, sabit kalın, yenileyin.';
const String kLabelLatitude = 'Enlem';
const String kLabelLongitude = 'Boylam';
const String kLabelGpsAccuracy = 'GPS doğruluğu (tahmini)';
const String kLabelLastUpdate = 'Son güncelleme';

const String kOpenLocationSettings = 'Konum ayarlarını aç';
const String kRequestLocationAgain = 'Konumu tekrar iste';
const String kAppSettings = 'Uygulama ayarları';
const String kOpenAppSettingsLocationDenied =
    'Uygulama ayarları (konum kalıcı kapalı)';
const String kRetry = 'Yeniden dene';

const String kScoreEmpty =
    'Skor yok — yenileyin veya GPS gelene kadar bekleyin.';
const String kNearbyLoadingMatch = 'Son kalibre haritadaki noktalara eşleniyor…';
const String kNearbyNeedsGpsScore =
    'Konum ile hotspot mesafesi için güncel konum ve skor gerekir. Konum gelince yenileyin.';
const String kNearbyNoHotspotAlign =
    'Son analize göre konumunuzla örtüşen hotspot yok. Konum veya kalibre haritayı güncelleyin.';

const String kNearestMarkId = 'En yakın nokta';
const String kDistanceM = 'Mesafe';
const String kRecommendationRank = 'Öncelik sırası';

// —— Ana ekran ——
const String kHomeTaglinePrimary =
    'Denizi daha net okudukça rotanız daha anlamlı hale gelir.';
const String kHomeTaglineSecondary =
    'İki seçenek — şu an size uygun olanı seçin.';
const String kHomeCardLiveTitle = 'Canlı Alan';
const String kHomeCardLiveSubtitle =
    'Kayıtlı harita + GPS — bulunduğunuz yerde skor.';
const String kHomeCardPhotoTitle = 'Fotoğraf analizi';
const String kHomeCardPhotoSubtitle =
    'Harita görüntünüzü açın — hotspot katmanları ve isteğe bağlı kalibrasyon.';
const String kHomeCardMarineTitle = 'Koordinat Deniz Analizi';
const String kHomeCardMarineSubtitle =
    'Bir noktanın rüzgar, dalga, ay ve av uygunluğunu kontrol et';
const String kHomeLanTipAndroid =
    'İpucu: Telefonda bilgisayarınızın yerel IP adresini yazın (localhost yerine).';
const String kHomeFooterServerLabel = 'Sunucu';

const String kDiscoverSearching = 'Sunucu aranıyor…';
const String kDiscoverManualButton = 'Sunucuyu Otomatik Bul';
const String kDiscoverAlternateSnack =
    'Bu ağda başka bir MeraSonar adresi de seçilebilir gibi görünüyor.';
const String kDiscoverUseAlternate = 'Bunu kullan';
const String kDiscoverNotFound =
    'MeraSonar API bulunamadı. Bu bilgisayarda run_api.cmd ile sunucuyu başlatın; 8000 '
    'bağlantı noktasını başka bir uygulama kullanıyorsa kapatın. Aynı Wi‑Fi’deki bilgisayar '
    'IP’sini girebilir veya “Sunucuyu Otomatik Bul” ile yeniden deneyebilirsiniz.';

/// Windows / yerel kullanımda en net yönlendirme (localhost başarısız).
const String kServerNotRunningLocalHint =
    'Sunucu çalışmıyor. BASLA.bat veya run_api.cmd ile API’yi başlatın.';

String discoverFoundLine(String ip, int port) =>
    'Sunucu bulundu: $ip:$port';

String alternateServerHint(String saved, String alternate) =>
    'Kayıtlı adres: $saved. Başka bir sunucu da bulundu: $alternate';

// —— Sunucu bağlantı rozeti ——
const String kServerBadgeOfflineMode =
    'Çevrimdışı mod (son analiz gösteriliyor)';
const String kServerBadgeDisconnected = 'Bağlantı yok';
const String kServerBadgeManualRequired = 'Manuel IP gerekli';
/// Keşif veya tek seferlik /health doğrulaması (aynı UI metni).
const String kServerBadgeVerifying = 'Sunucu aranıyor…';
/// İlk birkaç yüz milisaniye / ilk sağlık yanıtı gelmeden.
const String kServerBadgeAwaitingProbe = 'Bağlantı kontrolü…';
const String kServerBadgeTooltip = 'Sunucu ayarları';

String kServerBadgeConnected(String host, int port) => 'Bağlı: $host:$port';

// —— Çevrimdışı deneyimi ——
const String kOfflineAnalysisNeedsServer =
    'Yeni analiz için sunucu bağlantısı gerekli.';
const String kOfflineMapShowingCachedBadge =
    'Çevrimdışı — son kayıtlı analiz görüntüleniyor';
const String kOfflineMapNeedsServerBanner =
    'Çevrimdışı — kayıtlı haritaya bakabilirsiniz. Yeni analiz için bağlantı gelince buradan devam edebilirsiniz.';
const String kOfflineLiveScoreDisabled =
    'Canlı skor sunucu ile güncellenir; şu an önbellekteki son verilerle ilerleyebilirsiniz.';
const String kOfflineLiveScoreHintNearby =
    'Kalibre haritanızdaki yakın hotspot özeti bu şekilde gösteriliyor.';

/// Onboarding / yerel ağ IP’si önerisi (biçim).
const String kWrongIpFriendlyHint =
    'Genelde bilgisayarınızın yerel ağ adresi gerekir (örn. 192.168.x.x). Böyle deneyebilirsiniz.';

/// IP zaten 192.168 / 10.x / 172.16–31 gibi yerel ağdayken [home_screen] SnackBar’ı — sorun biçim değil, erişim.
const String kServerHealthFailedLanShapeHint =
    'Bu IP ile sunucuya ulaşılamıyor; adres biçimi doğru olsa da bağlantı kurulamadı. Bilgisayarda API '
    'çalışıyor mu (run_api.cmd), Windows güvenlik duvarı 8000 bağlantı noktasına izin veriyor mu ve telefon '
    'ile bilgisayar aynı Wi‑Fi ağında mı kontrol edin.';

/// 8000'de yanlış /health yanıtı (başka uygulama) — özellikle PC’de sık görülür.
const String kHealthPortWrongServiceHint =
    'Bu adresteki 8000 bağlantı noktası MeraSonar API değil. Görev Yöneticisi ile o bağlantıyı '
    'kim kullanıyorsa kapatabilirsiniz; proje klasöründe run_api.cmd ile API\'yi yeniden başlatın '
    '(ayrı konsolda uvicorn çıktısı açılmalıdır). Sonra bağlantıyı yenileyin.';

/// Çevrimdışıyken güven hissi (bir satır).
const String kOfflineStateReassurance =
    'Uygulama çalışmaya devam ediyor. Son veriler gösteriliyor.';

/// İlk başarılı bağlantı kutlaması
const String kFirstConnectionOk =
    'Bağlantı kuruldu ✓ Artık analiz yapabilirsiniz';

// İlk kullanımda sunucu sihirbazı
const String kServerWizardTitle = 'Devam etmek için bir sunucuya bağlanmanız gerekiyor';
const String kServerWizardBody =
    'MeraSonar’a şu an bağlanılamıyor. Aynı Wi‑Fi’de olduğunuzdan emin olabilir veya IP adresini kendiniz girebilirsiniz.';
const String kServerWizardBtnAuto = 'Otomatik bul';
const String kServerWizardBtnIp = 'IP gir';
const String kServerWizardLater = 'Daha sonra';

// Ana ekran — Fotoğraf analizi ilk adım
const String kPhotoGuideCueLine =
    'İlk harita analizi buradan — harita görseli seçerek başlayın.';

/// Localhost seçildiğinde — suçlamadan yönlendirme
const String kLocalhostMobileHintAndroid =
    'Telefonda localhost bu cihaza işaret eder; PC’nizi görmek için yerel adres (örn. 192.168.x.x) girmeyi deneyebilirsiniz.';
const String kLocalhostMobileHintIos =
    'Cihazda localhost Mac veya PC’niz değildir — o makinenin yerel ağ adresini kullanmayı deneyebilirsiniz.';

/// Harita/Fotoğraf durum kartı (nadir bağlantı dışı hatalar)
const String kMapErrorHeadlineUsingCache =
    'Güncelleme yapılamadı — kayıtlı görünüm sürüyor';
const String kMapErrorHeadlineUnexpected =
    'Yanıt tamamlanamadı — tekrar deneyebilirsiniz';

// Ekran bölüm başlıkları — sembolik adlar (Türkçe metin tek kaynak)
const String kLiveHowToReadTitle = kLiveAreaSectionHowToRead;
const String kLiveCurrentPositionTitle = kSectionCurrentPosition;
const String kLiveScoreTitle = kSectionLiveScore;
const String kNearbyHotspotTitle = kSectionNearbyHotspot;
const String kSafetyTrustTitle = kSectionSafetyTrust;

// Harita / Fotoğraf analizi — kalan kullanıcı metinleri
const String kMapPhotosPermBlocked =
    'Fotoğraf izni kalıcı olarak kapalı. Harita seçmek için sistem ayarlarından izin verebilirsiniz.';
const String kSnackActionOpenSettings = 'Ayarlarda aç';
const String kMapPhotosDeniedSnack =
    'Fotoğraf erişimi verilmedi. Harita seçmek için izin vermenizi isteyebiliriz.';
const String kMapNoChartLinkedLiveCalibSnack =
    'Henüz bu cihazda harita dosyası yok. “Alanı Tara” ile fotoğrafı seçebilirsiniz; ardından vurgulu kontrol noktası düğümü ile en az üç noktayı kalibre edebilirsiniz. Canlı Alan mesafeli önerileri için buna ihtiyaç duyar.';
const String kMapSnackRefreshNeedsChart =
    'Önce yenilemek için harita görseli seçmelisiniz.';
const String kMapSnackNoChartPick =
    'Harita görseli seçilmedi.';
const String kMapSnackGalleryError =
    'Galeriye erişilemedi. İzinleri veya-depolama alanını ayarlardan kontrol edebilirsiniz.';
const String kMapTooltipWorldMapApprox =
    'Dünya haritası (yaklaşık)';
const String kMapTooltipWorldMapLimited =
    'Dünya haritası (kalibrasyon olmadan sınırlı)';
const String kMapImageSpaceModeChip =
    'Fotoğraf modu (kalibrasyon yok)';
const String kMapImageSpaceWorldEmptyTitle =
    'Harita boş değil — kalibrasyon gerekli';
const String kMapImageSpaceWorldEmptyBody =
    'Bu analiz yalnızca fotoğrafa dayanıyor.\n'
    'Mera noktalarını dünya haritasında görmek için haritayı kalibre etmelisiniz.';

/// Dünya haritası boş — boat-anchor teşhisine göre (premium, debug alan adı yok).
const String kMapWorldMapEmptyGpsTitle = 'GPS konumu gerekli';
const String kMapWorldMapEmptyGpsBody =
    'Yaklaşık dünya haritası için tekne konumunuzu almamız gerekiyor.';
const String kMapWorldMapEmptyGpsCta = 'GPS’i aç / konumu yenile';

const String kMapWorldMapEmptyAnchorTitle = 'Tekne noktası bulunamadı';
const String kMapWorldMapEmptyAnchorBody =
    'Yaklaşık hizalama için fotoğraftaki tekne veya yıldız işaretinizi net biçimde işaretlemeniz gerekir.';
const String kMapWorldMapEmptyAnchorCta = 'Tekne konumunu işaretle';
const String kMapWorldMapEmptyAnchorSnack =
    'Fotoğraf moduna geçildi. Üst menüden “Haritayı Kalibre Et” ile 1. noktayı tekne/yıldız konumunuza yerleştirin; ardından analizi yenileyin.';

const String kMapWorldMapEmptyMapperTitle = 'Harita ölçeği eksik';
const String kMapWorldMapEmptyMapperBody =
    'Yaklaşık konum için harita sınırı veya önceki bir eşleşme gerekir. En doğru sonuç için üç kontrol noktasıyla kalibre edebilirsiniz.';
const String kMapWorldMapEmptyMapperCta = kCalibrateMapButton;

/// boat_anchor_estimate_reason için kısa kullanıcı satırları (iç kod adı gösterilmez).
const String kMapBoatAnchorReasonLineNoGps =
    'Şu an cihaz konumu alınamıyor; izinleri ve konum hizmetlerini kontrol edin.';
const String kMapBoatAnchorReasonLineNoAnchor =
    'Görüntüde güvenilir bir tekne/yıldız referansı seçilmedi.';
const String kMapBoatAnchorReasonLineNoScale =
    'Harita ile gerçek dünya arasında ölçek bağlantısı kurulamadı.';
const String kMapBoatAnchorReasonLinePending =
    'Konum tahmini için ek bilgi bekleniyor; aşağıdaki adımı deneyebilirsiniz.';
const String kMapWorldMapNeedsGpsOrCalib =
    'Dünya haritası için konum izni veya kalibrasyon gerekir.';
const String kMapTooltipChartOverlayPrimary =
    'Harita görüntüsü (birincil)';
const String kMapTooltipImageSpaceNoWorldMap =
    'Görüntü modundayken dünya haritası kapalıdır';
const String kMapTooltipControlPointsCalibrate =
    'Kontrol noktaları (haritayı kalibre et)';
const String kMapFabScanning = 'Taranıyor…';
const String kMapFabScanArea = 'Alanı Tara';
const String kMapAttribOpenStreetMap =
    'OpenStreetMap katkıcıları';

const String kMapDiagHeadingAlignment = 'Hizalama Doğrulama';
const String kMapDiagMappingTrustState = 'Harita güvenilirlik durumu';
const String kMapDataModePrefix = 'Veri modu:';
const String kMapSessionHintTitle = 'Bu oturum için ipucu';

// —— AI Asistan ——
const String kAiAssistantTitle = 'Captain Atlas ile Yorumla';
const String kAiAssistantLiveTitle = 'Captain Atlas Canlı Değerlendirme';
const String kAiAssistantLiveButtonLabel = 'Captain Atlas Canlı Değerlendirme';
const String kAiAssistantHotspotTitle = 'Captain Atlas Hotspot Yorumu';
const String kAiAssistantRefresh = 'Yenile';
const String kAiAssistantSectionHistory = 'Soru Geçmişi';
const String kAiAssistantCacheOnlyBanner =
    'Bağlantı yok, son AI yorumu gösteriliyor.';
const String kAiAssistantRefreshFailed =
    'Yenileme başarısız. Önceki yorum korunuyor.';
const String kAiAssistantButtonLabel = 'Captain Atlas ile Yorumla';
const String kAiAssistantHotspotButtonLabel = 'Captain Atlas ile Açıkla';
const String kCaptainAtlasChip = 'Captain Atlas';
const String kAiAssistantLoading = 'AI analiz yorumu hazırlanıyor…';
const String kAiAssistantQuestionLoading = 'Sorunuz yanıtlanıyor…';
const String kAiAssistantCancel = 'İptal';
const String kAiAssistantSectionSummary = 'Genel Değerlendirme';
const String kAiAssistantSectionActions = 'Önerilen Adımlar';
const String kAiAssistantSectionHotspots = 'Hotspot Yorumları';
const String kAiAssistantSectionConditions = 'Deniz ve Hava Yorumu';
const String kAiAssistantSectionSpecies = 'Muhtemel Tür Yorumu';
const String kAiAssistantSectionLimitations = 'Limitler';
const String kAiAssistantSectionSafety = 'Güvenlik Hatırlatmaları';
const String kAiAssistantSectionQuestionAnswer = 'Soru Cevabı';
const String kAiAssistantQuestionHint =
    'Örn: Levrek için mantıklı mı? Sabah mı akşam mı?';
const String kAiAssistantQuestionSubmit = 'Sor';
const String kAiAssistantTrustTitle = 'Tavsiye Niteliğindedir';
const String kAiAssistantFallbackBanner =
    'Captain Atlas şu an canlı AI yanıt veremiyor. Güvenli özet gösteriliyor.';

/// Debug/dev için kısa fallback sebebi — production'da yalnızca kDebugMode ile gösterilir.
String kAiAssistantFallbackReasonDebug(String? reason) {
  switch (reason) {
    case 'ai_assistant_disabled':
      return 'Sebep: AI devre dışı';
    case 'missing_api_key':
      return 'Sebep: API anahtarı yapılandırılmadı';
    case 'missing_model':
      return 'Sebep: OpenAI modeli yapılandırılmadı';
    case 'openai_not_configured':
      return 'Sebep: OpenAI yapılandırması eksik';
    case 'openai_auth_failed':
      return 'Sebep: OpenAI kimlik doğrulama hatası';
    case 'openai_rate_limited':
      return 'Sebep: OpenAI hız limiti';
    case 'openai_quota_exceeded':
      return 'Sebep: OpenAI kota aşıldı';
    case 'openai_timeout':
      return 'Sebep: OpenAI zaman aşımı';
    case 'openai_network_error':
      return 'Sebep: OpenAI ağ hatası';
    case 'streaming_not_implemented_in_phase_1':
      return 'Sebep: streaming modu aktif (desteklenmiyor)';
    case 'rate_limit_exceeded':
      return 'Sebep: istek limiti';
    case 'quota_exceeded':
      return 'Sebep: günlük kota';
    case 'upstream_failure':
      return 'Sebep: OpenAI servis hatası';
    default:
      if (reason == null || reason.trim().isEmpty) {
        return 'Sebep: bilinmiyor';
      }
      return 'Sebep: $reason';
  }
}
const String kAiAssistantCacheBadge = 'Önbellekten geldi';
const String kAiAssistantProBadge = 'AI Pro';
String kAiAssistantQuotaBadgeFmt(int remaining) =>
    'Bugünkü AI hakkı: $remaining';
const String kAiAssistantErrorGeneric =
    'AI yorumu alınamadı. Aşağıdaki oturum özetini kullanabilirsiniz.';
const String kMsgAiAssistantUnavailable = 'AI asistan şu an yanıt vermiyor.';
const String kMsgAiAssistantTimeout =
    'AI yorumu zaman aşımına uğradı. Daha sonra tekrar deneyin.';
const String kMsgAiAssistantInvalidResponse = 'AI yanıtı okunamadı.';

const String kMapDiagGeorefErrorShort = 'Coğrafi başvuru sapması (m)';
const String kMapDiagTransformQuality = 'Dönüşüm kalitesi';
const String kMapTabCalibratedMap = 'Kalibre harita';
/// coordinate_mode == boat_anchor_estimated — dünya haritası segmenti.
const String kMapTabApproxBoatAnchorWorld = 'Yaklaşık tekne referanslı harita';
/// image_space — dünya haritası kapalıyken üst sekme etiketi politikası.
const String kMapTabCalibrationRequiredWorld = 'Kalibrasyon gerekli';
const String kMapTabPhotoAnalysis = 'Fotoğraf analizi';
const String kMapNearestMeresPanelTitle = 'En yakın meralar';
const String kMapChartPreviewLabel = 'Kaynak grafik';
const String kMapModeBannerCalibrated =
    'Kalibre dünya haritası aktif — meralar gerçek konuma oturmuş kabul edilir.';
const String kMapTrustHigh = 'yüksek';
const String kMapTrustMedium = 'orta';
const String kMapTrustLow = 'düşük';

/// Alt panel kartı için metin şablonu.
String kMapMeresDockScoreFmt(int scorePct, int distM, int bearingDeg) =>
    'Skor ~$scorePct% · $distM m · Azimut $bearingDeg°';

String kMapTrustFmt(String level) => 'Güven seviyesi: $level';

String kMapClusterSheetTitle(int n) => '$n mera (yakın küme)';
String kMapClusterRowSubtitle(int scorePct) => 'Skor ~$scorePct% · ayrıntı için dokunun';

const String kMapGpsPillReliable = 'GPS güvenilir';
const String kMapGpsPillApprox = 'GPS yaklaşık';
const String kMapGpsPillWeak = 'GPS zayıf';

// —— Premium Map (UI-5) ——
const String kMapPremiumBrandTitle = 'MeraSonar';
const String kMapPremiumMapHeaderTitle = 'MeraSonar Map';
const String kMapPremiumBackHome = 'Genel Bakış';
const String kMapPremiumFiltersTitle = 'Filtreler';
const String kMapPremiumNearestMeresShort = 'Yakındaki Meralar';
const String kMapPremiumLegendTitleShort = 'Lejant';
const String kMapPremiumLegendBoatShort = 'Tekne';
const String kMapPremiumLegendA = 'A — Vurgun';
const String kMapPremiumLegendB = 'B — Güçlü';
const String kMapPremiumLegendC = 'C — Geçiş';
const String kMapPremiumExperienceMap = 'Harita';
const String kMapPremiumExperiencePhoto = 'Foto Analiz';
const String kMapPremiumExperienceMapHint = 'Yaklaşık tekne referansı';
const String kMapPremiumExperiencePhotoHint = 'Kaynak grafik';
const String kMapPremiumApproxLocationShort =
    'Yaklaşık konum — kontrol noktasıyla doğrulanmadı.';
const String kMapPremiumDataSource = 'Veri Kaynağı';
const String kMapPremiumLiveApi = 'Canlı API';
const String kMapPremiumProviderHealthy = 'Sağlayıcı sağlıklı';
const String kMapPremiumProviderOffline = 'Sağlayıcı offline';
const String kMapPremiumControlsTitle = 'Harita Kontrolleri';
const String kMapPremiumGpsReliability = 'GPS Güvenilirliği';
const String kMapPremiumCategory = 'Kategori';
const String kMapPremiumMinScore = 'Minimum Skor';
const String kMapPremiumDensity = 'Yoğunluk';
const String kMapPremiumDensityLayer = 'Yoğunluk katmanı';
const String kMapPremiumConnections = 'Bağlantılar';
const String kMapPremiumConnectionLines = 'Hotspot bağlantı çizgileri';
const String kMapPremiumLegendToggle = 'Lejandı göster';
const String kMapPremiumSortLabel = 'Sıralama vurgusu';
const String kMapPremiumLegendTitle = 'Harita Lejandı';
const String kMapPremiumLegendBoat = 'Tekne konumu';
const String kMapPremiumLegendScoreHint = 'Skor 0–1 arası yapısal uygunluğu gösterir.';
const String kMapPremiumOn = 'Açık';
const String kMapPremiumOff = 'Kapalı';
const String kMapPremiumCommandScan = 'Alan Tara';
const String kMapPremiumCommandLive = 'Canlı Analiz';
const String kMapPremiumCommandCoord = 'Koordinat';
const String kMapPremiumCommandCompare = 'Karşılaştır';
const String kMapPremiumCommandCaptain = 'Captain Atlas';
const String kMapPremiumHotspotGo = 'Git';
const String kMapPremiumPhotoTitle = 'Fotoğraf Analizi';
const String kMapPremiumPhotoUpload = 'Görsel Yükle ve Analiz Et';
const String kMapPremiumDownloadTooltip = 'GPX indir';
const String kMapPremiumSettingsTooltip = 'Ayarlar';
const String kMapPremiumNotificationsTooltip = 'Bildirimler';
const String kMapPremiumProfileTooltip = 'Profil';
const String kMapPremiumCenterBoatTooltip = 'Tekneye odaklan';
String kMapPremiumHotspotScoreDepthFmt(int scorePct, String depthM, int distM) =>
    'Skor $scorePct · Derinlik ${depthM}m · Mesafe ${distM}m';

// —— Premium Chart Overlay (UI-6) ——
const String kMapChartOverlayHotspotCountFmtPrefix = 'Hotspot';
String kMapChartOverlayHotspotCountFmt(int count) => '$count mera';
const String kMapChartOverlayCmdAnalyze = 'Analiz Et';
const String kMapChartOverlayCmdCalibrate = 'Kalibre Et';
const String kMapChartOverlayCmdWorldMap = 'Dünya Haritası';
const String kMapChartOverlayCmdGpx = 'GPX';
const String kMapChartOverlayMiniLegendTitle = 'Lejand';
const String kMapImageSpaceWarningTitle = 'Fotoğraf üzerinde tahmin';
const String kMapImageSpaceWarningBody =
    'Bu sonuç fotoğraf üzerinde tahmindir. Gerçek koordinat için kalibrasyon gerekir.';
const String kMapPhotoUploadHint =
    'Navionics veya Garmin ekran görüntüsü önerilir.';
const String kMapPhotoUploadFormats = 'Desteklenen: JPG, PNG, WEBP';
const String kMapPhotoUploadDropHint = 'Harita görüntüsünü buraya bırakın veya seçin';
const String kMapPhotoLoadingReadImage = 'Harita görüntüsü okunuyor…';
const String kMapPhotoLoadingBathymetry = 'Batimetrik yapı çıkarılıyor…';
const String kMapPhotoLoadingRankHotspots = 'Hotspotlar sıralanıyor…';
const String kMapPhotoLoadingFinalize = 'Sonuç hazırlanıyor…';
const String kMapChartDebugOverlayTitle = 'Analiz katmanı';
const String kMapChartDebugOverlayToggle = 'Debug overlay göster';
const String kMapChartDebugOverlayOpacity = 'Opaklık';
const String kMapChartDebugOverlayLegendTitle = 'Lejand';
const String kMapChartDebugLegendHot = 'Sıcak alan';
const String kMapChartDebugLegendContour = 'Kontur yoğunluğu';
const String kMapChartDebugLegendDropOff = 'Drop-off';
const String kMapChartDebugLegendWeak = 'Zayıf aday';
const String kMapCalibStepPick = 'Nokta seç';
const String kMapCalibStepCoordinate = 'Koordinat gir';
const String kMapCalibStepVerify = 'Doğrula';
const String kMapCalibStepApply = 'Uygula';
const String kMapCalibReliabilityGood = 'Kalibrasyon: İyi';
const String kMapCalibReliabilityMedium = 'Kalibrasyon: Orta';
const String kMapCalibReliabilityLow = 'Kalibrasyon: Düşük';
const String kMapChartOverlayModeImageSpace = 'image_space';
const String kMapChartOverlayModeGeoReferenced = 'geo_referenced';

const String kMapHotspotFocusOffScreen = 'Seçili mera görünür alan dışında';
const String kMapGpsWeakHint =
    'Konum doğruluğu düşük; tekne işareti yaklaşık gösteriliyor.';

/// Dünya haritası — konum akışı (premium ton, debug değil).
const String kMapGpsServiceDisabledPremium =
    'Konum hizmetleri kapalı. Seyir görünümü için sistem ayarlarından açın.';
const String kMapGpsPermissionDeniedPremium =
    'Konum izni verilmedi. Yaklaşık tekne konumu için izin gerekiyor.';
const String kMapGpsPermissionForeverPremium =
    'Konum izni kalıcı olarak kapalı. Ayarlardan uygulama izinlerini güncelleyebilirsiniz.';
const String kMapGpsStreamDegradedPremium =
    'Canlı konum akışı kesildi. Harita son bilinen konumla sınırlı kalabilir; biraz sonra yeniden dene.';

const String kMapApproximateRibbon = kMapPremiumApproxLocationShort;

/// Harita ekranı: sunucu IP kaydedildi bildirimi.
String kMapSnackServerUpdated(String host, int port) =>
    'Sunucu adresi güncellendi: $host:$port';

/// Sunucuya kayıtlı profil yüklendi.
String kMapHistoryLoadedSaved(String timestamp) =>
    'Kayıtlı analiz yüklendi: $timestamp';

/// Profil görüntüsü uyumsuz.
String kMapProfileDimensionMismatchSnack(int pw, int ph, int cw, int ch) =>
    'Profil $pw×${ph}px; şu anki görüntü $cw×${ch}px. Noktaları ekranda doğrulamayı sürdürebilirsiniz.';
const String kMapSnackCalibProfileApplied = 'Kalibrasyon profili uygulandı.';

/// Kontrol noktası / kalibrasyon (sade dil).
const String kCalibSheetTitle = 'Haritayı Kalibre Et';
const String kCalibIntroShort =
    'Navionics’te koordinatı okuyun, buraya yazın; ardından aynı noktayı '
    'fotoğraf önizlemesinde işaretleyin. Bu eşleme meraların doğru yere düşmesini sağlar.';
const String kCalibNavionicsFormatHint =
    'Sadece rakamları yazın; °, \' ve N/E otomatik eklenir. '
    'Her nokta için «Fotoğrafta işaretle» ile ekran görüntüsündeki tam yerini seçin '
    '(üst çubuk / kenar boşlukları dahil).';
const String kCalibLatHintExample = '3724252';
const String kCalibLonHintExample = '02713632';
const String kCalibInsertDegreeTooltip = 'Derece (°) ekle';
const String kCalibInsertMinuteTooltip = 'Dakika (\') ekle';
const String kCalibStep1Label = '1. Ekran görüntüsü: sol üst köşe';
const String kCalibStep2Label = '2. Ekran görüntüsü: sağ alt köşe';
const String kCalibStep3Label = '3. Haritada ara referans noktası';
const String kCalibStep1Short = '1. Sol üst köşe koordinatını gir';
const String kCalibStep2Short = '2. Sağ alt köşe koordinatını gir';
const String kCalibStep3Short = '3. Ara referans koordinatını gir';
const String kCalibReadyMessage = 'Kalibrasyon hazır ✓';
const String kCalibRerunAnalysisCta = 'Analizi Tekrar Çalıştır';
const String kCalibIncompleteExitSnack =
    'Kalibrasyon tamamlanmadı. Dünya haritasında mera noktaları gösterilemez.';
const String kCalibClose = 'Kapat';
const String kCalibDialogTitle = 'Koordinat gir';
const String kCalibDialogPointHint =
    'Navionics’teki enlem ve boylamı aynı biçimde yazın.';
const String kCalibClear = 'Temizle';
const String kCalibNeedThreeHint =
    'En az 3 Navionics koordinat çifti gerekli.';
const String kCalibNoPointsYet =
    'Navionics koordinatlarını aşağıdaki alanlara yazın.';
const String kCalibAddPoint = 'Ekle';
const String kCalibAddExtraPoint = 'Ek nokta ekle';
const String kCalibRemovePoint = 'Noktayı kaldır';
const String kCalibPreviewWaiting =
    '3 geçerli koordinat girildiğinde önizleme güncellenir.';
const String kCalibPreviewCaption =
    'Yeşil = elle işaretlendi. En az 3 noktayı fotoğrafta işaretlemeniz önerilir.';
const String kCalibMarkOnPhoto = 'Fotoğrafta işaretle';
const String kCalibPixelMarked = 'Fotoğrafta işaretli ✓';
const String kCalibClearPixel = 'Piksel işaretini sil';
String kCalibPickActiveHint(int n) =>
    'Nokta $n: fotoğrafta ilgili yere dokunun';
const String kCalibListItemTitle = 'Nokta';

String kCalibExtraPointLabel(int n) => '$n. ek referans noktası';

String kCalibProgressPoints(int n) =>
    n >= 3 ? '$n nokta eklendi (en az 3 gerekli)' : '$n / 3 nokta eklendi';

/// Hotspot detay — güvenilmeyen veya image-space koordinat gösterimi
const String kHotspotGeoPlaceholderDash = '—';
const String kHotspotGeoDistanceUnavailable = 'Hesaplanamıyor';
const String kHotspotGeoBearingUnavailable = 'Kullanılamıyor';
const String kHotspotGeoMaritimeSectionTitle = 'Konum ve kerteriz';
const String kHotspotGeoBoatAnchorEstimatedLabel =
    'Yaklaşık tekne referanslı konum';
const String kHotspotGeoBoatAnchorEstimatedDebugNote =
    'Bu koordinatlar kontrol noktasıyla doğrulanmış değildir.';

const String kMapChartOverlayNeedsScreenshotAnalysis =
    'Harita görüntüsü katmanını görmek için önce bir ekran görüntüsü analizi çalıştırılmalıdır.';
const String kMapChartOverlayJsonButImageMissingTitle =
    'Önceki analiz bulundu ancak harita dosyası bulunamadı.';
const String kMapChartOverlayJsonButImageMissingHint =
    'Aynı haritayı yeniden yükleyerek analiz görünümünü geri getirebilirsiniz.';
const String kMapChartReloadCta = 'Haritayı Yeniden Yükle';
const String kMapChartNewAnalysisCta = 'Yeni Analiz Başlat';
const String kMapChartFromHistoryNote =
    'Bu harita önceki bir analizden yüklendi';

String kMapHotspotTooltipRankLine(int pr) =>
    'Sezgisel öncelik sırası $pr (ziyaret sırası ipucu — olasılıksal; av garantisi vermez).';

const String kMapBadgeRecommendedSpot1 = 'Önerilen nokta 1';
const String kMapBadgeSuggestedPriority2 = 'Öncelik önerisi 2';
const String kMapBadgeSuggestedPriority3 = 'Öncelik önerisi 3';

const String kMapSnackNoControlPointsAnalysis =
    'Kontrol noktası girilmedi. Fotoğraf koordinatsız modda analiz edilecek.';

const String kMapBoatAnchorEstimatedRibbon = kMapPremiumApproxLocationShort;

/// boat_anchor_estimated + sunucu geo sayısı 0 iken (ürün uyarısı).
const String kMapApproxHotspotLatLonEmpty =
    'Yaklaşık koordinatlar üretilemedi: hotspot lat/lon boş';

/// boat_anchor_estimated: görünür işaret 0 iken (viewport/zoom sonrası) amber bilgi.
const String kMapBoatAnchorApproximateOffscreenHint =
    'Yaklaşık meralar üretildi ancak harita görünümünün dışında olabilir. Görünüme sığdırılıyor.';

const String kMapBoatAnchorEstimatedWorldMapNote =
    'Bu noktalar kontrol noktasıyla doğrulanmadı (yaklaşık tekne referanslı).';

/// GPX
const String kGpxShareDefaultCaption = 'MeraSonar mera noktaları (GPX)';
const String kGpxEmptyDefault = 'Dışa aktarılacak nokta yok.';
const String kGpxNoCoordsValid = 'Geçerli koordinata sahip nokta görünmüyor.';
const String kGpxShareFailedSnack =
    'GPX oluşturulamadı veya paylaşılamadı. Biraz sonra tekrar deneyebilirsiniz.';
const String kGpxEmptyWithFilterHint =
    'Dışa aktarılacak nokta yok. Filtreleri veya skor eşiğini kontrol edebilirsiniz.';

/// Onboarding
const String kOnboardingWelcomeTitle = 'Hoş geldiniz';
const String kOnboardingSnackNeedCheckbox =
    'Devam etmek için onay kutusunu işaretleyebilirsiniz.';
const String kOnboardingNext = 'İleri';
const String kOnboardingEnterApp = 'Uygulamaya gir';
const String kOnboardingIntroBody =
    'Harita veya ekran görüntüsünüz analiz için sunucuya gönderilir; mera önerileri üretilir ve görüntü üzerinde gösterilir. Gerçek konum için kontrol noktalarını kullanırsınız. Sonuçlar yol göstericidir; resmi deniz kurallarının yerine geçmez.';
const String kOnboardingBulletScan = 'Görünümden yararlı tarama';
const String kOnboardingBulletCalib = 'Kontrol noktaları ve kalibrasyon kayıtları';
const String kOnboardingBulletGpx = 'GPX olarak dışa aktarma';

const String kOnboardingServerTitle = 'Analiz sunucusu';
const String kOnboardingServerBody =
    'Telefondan test ederken arka uç bilgisayardaysa aşağıya bilgisayarın yerel ağ IP adresini girin. Aynı cihazda çalışan API için 127.0.0.1 yeterlidir; boş bırakırsanız cihaz IP’si otomatik denenecektir.';

const String kOnboardingLegalHeading = 'Feragat';
const String kOnboardingReadFullText = 'Tam metni oku';
const String kOnboardingLegalAck =
    'Bu uygulamanın tavsiye niteliğinde sonuç ürettiğini, resmi kaynaklara uymam gerektiğini anladım.';

String kOnboardingServerIpDecorationLabel(int port) =>
    'Sunucu IP (port $port sabit)';
const String kOnboardingServerIpHint = 'Örn. 192.168.1.20';

// Sunucu IP diyaloğu
const String kServerDialogTitle = 'Sunucu adresi';
const String kServerDialogBtnCancel = 'İptal';
const String kServerDialogBtnSave = 'Kaydet';

// —— Gizlilik ——
const String kPrivacyDialogTitle = 'Gizlilik';
const String kDialogClose = 'Kapat';

/// Sunucunun İngilizce derece etiketini kartta Türkçe gösterir.
String localizeLiveRatingLabel(String rating) {
  switch (rating.trim().toLowerCase()) {
    case 'excellent':
      return 'Mükemmel';
    case 'good':
      return 'İyi';
    case 'fair':
    case 'medium':
      return 'Orta';
    case 'low':
      return 'Düşük';
    default:
      final t = rating.trim();
      if (t.isEmpty) return '—';
      return 'Derece: $t';
  }
}

/// Arka uçtan gelen [mapping_trust_state] değerini Türkçe özetler.
String localizeMappingTrustState(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'chart_georeferenced_precise':
      return 'Harita coğrafi hizalı (yüksek güven)';
    case 'approximate_bounds_fallback':
      return 'Yaklaşık sınır yedeği';
    case 'image_space_only':
      return 'Yalnızca görüntü uzayı';
    default:
      return 'Durum: ${raw.replaceAll('_', ' ')}';
  }
}

/// [boat_anchor_source] vb. teknik kodları gösterim için Türkçeleştirir.
String localizeBoatAnchorSource(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'gps_fallback':
      return 'GPS yedeği';
    case 'image_center':
      return 'Görüntü merkezi';
    case 'manual_image_anchor':
      return 'Manuel görüntü-anchor';
    case 'detected':
      return 'Algılandı';
    case 'photo_center_fallback':
      return 'Fotoğraf merkezi yedeği';
    default:
      return raw.replaceAll('_', ' ');
  }
}

/// Hotspot ayrıntısı: bölgesel tür yoksa (image_space).
const String kHotspotRegionalSpeciesRequiresCalib =
    'Bölgesel tür verisi için kalibre edilmiş koordinat gerekir.';

/// Zenginleştirme: derinlik / tür (image_space veya kaynak yok).
const String kEnrichDepthRequiresCalib = 'Kalibrasyon gerekli';
const String kEnrichSpeciesRequiresCalib = 'Kalibrasyon gerekli';
const String kEnrichBiodiversityRequiresCalib =
    'Bölgesel tür verisi için kalibre edilmiş koordinat gerekir.';
const String kEnrichWeatherBoatGpsFailed =
    'Tekne konumuna göre alınamadı';
const String kEnrichWeatherServerHint =
    'Sunucu bağlantısı gerekli';
const String kEnrichWeatherBoatScopeNote =
    'Hava (tekne konumu)';

/// Deniz durumu [source] alanını rozet metninde göstermek için.
String localizeSeaDataSource(String raw) {
  final s = raw.trim().toLowerCase();
  switch (s) {
    case '':
    case 'unknown':
      return kEnrichWeatherServerHint;
    case 'calibration_required':
      return kEnrichDepthRequiresCalib;
    case 'requires_gps_or_server':
      return kEnrichWeatherBoatGpsFailed;
    case 'marine_client_unavailable':
      return kEnrichWeatherServerHint;
    case 'open_meteo':
    case 'open-meteo':
      return 'Open-Meteo';
    case 'simulated':
      return 'simüle';
    default:
      return s.replaceAll('_', ' ');
  }
}

/// Android localhost uyarısı (SnackBar vb.).
String kAndroidLoopbackBlocked(String pcLanHostPort, String emulatorHostPort) =>
    'Bu telefonda "localhost" ve 127.0.0.1 bu cihazın kendisine işaret eder; bilgisayarınıza değil. '
    'Örnek: $pcLanHostPort gibi LAN adresini yazın. Emülatör ipucu: $emulatorHostPort.';

/// OBIS/GBIF vb. özet metni öncesi çerçeve (ham metin ayrı blokta gösterilir).
const String kRegionalSpeciesContextFraming =
    'Bu bölgede kayıtlı tür gözlemlerine dair harici veri tabanlarından özet bulunmaktadır. '
    'Bu bilgi kesin av noktası veya bolluk garantisi anlamına gelmez. '
    'Aşağıdaki metin araştırma kayıtlarından gelir ve orijinal dilde (çoğunlukla İngilizce/Latince) olabilir.';

const String kRegionalSpeciesContextSourceNote =
    'Kaynak özeti (OBIS / GBIF bağlamı; bilimsel adlar İngilizce/Latince olabilir):';

String localizeUiConfidenceWord(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'high':
    case 'yüksek':
      return 'Yüksek';
    case 'medium':
    case 'orta':
      return 'Orta';
    case 'low':
    case 'düşük':
      return 'Düşük';
    default:
      return raw.trim();
  }
}

/// Av tavsiyesi tür satırı; API `high`/`medium`/`low` veya kısa Türkçe dönebilir.
String localizeFishPredictionProbability(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return '—';
  if (t == 'high' || t == 'yüksek' || t.startsWith('yüksek')) {
    return 'Yüksek';
  }
  if (t == 'medium' || t == 'orta' || t.startsWith('orta')) {
    return 'Orta';
  }
  if (t == 'low' || t == 'düşük' || t.startsWith('düşük')) {
    return 'Düşük';
  }
  return raw.trim();
}

String kHotspotGpxShareCaption(String classification) =>
    'MeraSonar: $classification sınıfı mera (GPX)';

/// Tür/Grup künyesi İngilizce slug ise okunabilir Türkçe ada yaklaştırır.
String localizeSpeciesGroupSlug(String slug) {
  final s = slug.trim().toLowerCase();
  const m = <String, String>{
    'grouper': 'Grupör / orfoz',
    'snapper': 'Siniper',
    'demersal_predator': 'Dip avcısı',
    'pelagic_gamefish': 'Pelajik spor balığı',
    'pelagic predator': 'Pelajik avcı',
    'spanish_mackerel': 'Palamut / kral uskumru',
    'jack_mackerel': 'Sarıkanat',
    'flatfish': 'Dil balığı',
    'sea_bream': 'Çipura',
    'goatfish': 'Tekir',
    'mackerel': 'Uskumru',
    'mullet': 'Kefal',
    'eel': 'Yılan balığı',
    'triggerfish': 'Triger balığı',
    'swordfish': 'Kılıç balığı',
    'surgeonfish': 'Cerrah balığı',
    'scorpionfish': 'Skorpion balığı',
    'demersal bottom': 'Dipte yaşayan',
    'transitional_reef': 'Geçiş resifi',
    'structure_oriented': 'Yapı odaklı',
    'mid_depth predator': 'Orta derinlik avcısı',
    'ambush_predator': 'Pusu avcısı',
  };
  return m[s] ?? slug.replaceAll('_', ' ');
}

// —— Marine Intelligence (Faz 7d) ——
const String kMarineScreenTitle = 'Koordinat Deniz Analizi';
const String kMarineAnalyzeButton = 'Analiz Et';
const String kMarinePickFromMap = 'Haritadan Seç';
const String kMarineSaveSpot = 'Bu noktayı kaydet';
const String kMarineSavedSpotsTitle = 'Kayıtlı Noktalar';
const String kMarineRefreshSpot = 'Güncelle';
const String kMarineDeleteSpot = 'Sil';
const String kMarineFavoriteToggle = 'Favori';
const String kMarineNoData = 'Veri yok';
const String kMarineOfflineCachedBanner =
    'Bağlantı yok, son kayıtlı veri gösteriliyor.';
const String kMarineStaleBanner = 'Son senkron:';
const String kMarineCacheHitBadge = kPremiumCacheFromLocal;
const String kMarinePartialDataBadge = 'Kısmi veri';
const String kMarineSectionWeather = 'Hava Durumu';
const String kMarineSectionWind = 'Rüzgar';
const String kMarineSectionSea = 'Deniz ve Dalga';
const String kMarineSectionSwell = 'Ölü Dalga';
const String kMarineSectionAstronomy = 'Ay / Güneş';
const String kMarineSectionScore = 'Balıkçılık Skoru';
const String kMarineSectionProviders = 'Sağlayıcı Karşılaştırması';
const String kMarineSectionExplain = 'Neden böyle?';
const String kMarineSaveDialogTitle = 'Noktayı kaydet';
const String kMarineSpotNameHint = 'İsim';
const String kMarineSpotNoteHint = 'Not (isteğe bağlı)';
const String kMarineSpotTagsHint = 'Etiketler (virgülle)';
const String kMarineMapLongPressTitle = 'Bu noktayı analiz et';
const String kMarineGoToAnalysis = 'Koordinat Deniz Analizine Git';
const String kMarineMapPickerTitle = 'Haritadan koordinat seç';
const String kMarineUseCoordinate = 'Bu koordinatı kullan';
const String kMarineLastReport = 'Son rapor';
const String kMarineVisitCount = 'Ziyaret';
const String kMsgMarineReportFailed =
    'Deniz analizi alınamadı. Sunucu bağlantısını kontrol edip tekrar deneyin.';
const String kMsgMarineReportTimeout =
    'Deniz analizi zaman aşımına uğradı. Biraz sonra tekrar deneyin.';
const String kMsgMarineSpotsLoadFailed =
    'Kayıtlı noktalar yüklenemedi.';
const String kMsgMarineSpotsSaveFailed =
    'Nokta kaydedilemedi. Tekrar deneyin.';
const String kMsgMarineSpotDeleteFailed =
    'Nokta silinemedi.';
const String kMsgMarineSpotNotFound = 'Nokta bulunamadı.';
const String kMarineSuitabilityLabel = 'Uygunluk';
const String kMarineRiskLabel = 'Risk';
const String kMarineConfidenceLabel = 'Güven';
const String kMarinePlaceholderFuture = 'Yakında';

const String kMarineSectionDecision = 'Karar';
const String kMarineSectionDecisionTimeline = 'Gün içi karar pencereleri';
const String kMarineGoScoreLabel = 'Git skoru';
const String kMarineWaitScoreLabel = 'Bekle skoru';
const String kMarineDecisionExcellent = 'Çok Uygun';
const String kMarineDecisionGood = 'Uygun';
const String kMarineDecisionBorderline = 'Sınırda';
const String kMarineDecisionPoor = 'Zayıf';
const String kMarineDecisionUnsafe = 'Riskli';
const String kMarineLastDecisionPrefix = 'Son karar:';
const String kMarineLastDecisionSuitable = 'Uygun';
const String kMarineLastDecisionBorderline = 'Sınırda';
const String kMarineLastDecisionRisky = 'Riskli';
const String kMarineSectionScenario = 'Koşullar Değişirse';
const String kMarineGoScoreDeltaLabel = 'Go Score';
const String kMarineRiskDeltaLabel = 'Risk';
const String kMarineMostSensitivePrefix = 'En hassas faktör:';
const String kMarineTimelineBestSlot = 'En iyi pencere';
const String kMarineSectionAiComment = 'Captain Atlas Yorumu';
const String kMarineCaptainAtlasChip = 'Captain Atlas';
const String kMarineAiCommentFallbackBanner =
    'Captain Atlas şu an canlı AI yanıtı veremiyor, mevcut deniz verilerinden güvenli özet gösteriliyor.';
const String kMarineFetchAiCommentButton = "Captain Atlas'a Sor";
const String kMarineAiBestTimeLabel = 'En iyi zaman penceresi';
const String kMarineAiRiskLabel = 'Risk notu';
const String kMarineAiRecommendedActionsLabel = 'Önerilen adımlar';

const String kMarineAddCatchButton = 'Av Kaydı Ekle';
const String kMarineViewCatchesButton = 'Av Kayıtları';
const String kMarineCatchDialogTitle = 'Av Kaydı Ekle';
const String kMarineCatchSpeciesHint = 'Tür';
const String kMarineCatchLengthHint = 'Boy (cm)';
const String kMarineCatchWeightHint = 'Ağırlık (kg)';
const String kMarineCatchBaitHint = 'Yem';
const String kMarineCatchMethodHint = 'Yöntem';
const String kMarineCatchDateHint = 'Tarih / saat';
const String kMarineCatchNotesHint = 'Not';
const String kMarineCatchSaveButton = 'Kaydet';
const String kMarineCatchListTitle = 'Son av kayıtları';
const String kMarineCatchListEmpty = 'Henüz av kaydı yok.';
const String kMarineSpotReputationLabel = 'İtibar';
const String kMarineTopSpeciesPrefix = 'En çok:';
const String kMarineCatchCountLabel = 'Av kaydı';
const String kMarineSpotLevelBronze = 'Bronze';
const String kMarineSpotLevelSilver = 'Silver';
const String kMarineSpotLevelGold = 'Gold';
const String kMarineSpotLevelElite = 'Elite';
const String kMarineSpotLevelLegendary = 'Legendary';
const String kMsgMarineCatchLoadFailed = 'Av kayıtları yüklenemedi.';
const String kMsgMarineCatchDeleteFailed = 'Av kaydı silinemedi.';
const String kMsgMarineCatchNotFound = 'Av kaydı bulunamadı.';
const String kMsgMarineCatchUpdateFailed = 'Av kaydı güncellenemedi.';
const String kMarineCatchEditDialogTitle = 'Av Kaydını Düzenle';
const String kMarineRefreshIncludeAiComment = 'Captain Atlas yorumu dahil';
const String kMarinePremiumCoordinateTitle = 'Koordinat Girişi';
const String kMarineDecisionEmptyTitle =
    'Bir koordinat analiz ederek deniz karar özetini görün.';
const String kMarineExplainPositive = 'Olumlu faktörler';
const String kMarineExplainNegative = 'Dikkat edilmesi gerekenler';
const String kMarineExplainUncertainty = 'Belirsizlikler';
const String kMarineAiSourceAi = 'AI';
const String kMarineAiSourceFallback = 'Güvenli özet';
const String kMarineActionRefresh = 'Yenile';
const String kMarineCoordValidationError = 'Geçerli enlem ve boylam girin.';
const String kMarinePremiumConditionsTitle = 'Anlık Koşullar';
const String kMarinePremiumSunLabel = 'Güneş';
const String kMarinePremiumSourceLabel = 'Kaynak';
const String kMarinePremiumCaptainEmpty =
    'Captain Atlas yorumu henüz alınmadı. Sor butonuna basarak isteyebilirsiniz.';
const String kMarineProviderExpandTitle = 'Sağlayıcı karşılaştırması';

// —— Marine Compare (Faz 8e) ——
const String kMarineCompareScreenTitle = 'Noktaları Karşılaştır';
const String kMarineCompareButton = 'Karşılaştır';
const String kMarineComparePointA = 'A Noktası';
const String kMarineComparePointB = 'B Noktası';
const String kMarineCompareWinnerTitle = 'Daha Uygun Görünüyor';
const String kMarineCompareTieTitle = 'Berabere / Benzer';
const String kMarineCompareCaptainTitle = 'Captain Atlas Karşılaştırması';
const String kMarineCompareOpenFromAnalysis = 'İki Noktayı Karşılaştır';
const String kMarineCompareSelectMode = 'Karşılaştırma modu';
const String kMarineCompareSelectHint = 'Karşılaştırmak için iki nokta seçin';
const String kMarineCompareIncludeAiComment = 'Captain Atlas karşılaştırması dahil';
const String kMarineCompareScoreDelta = 'Skor farkı';
const String kMarineCompareMainReasons = 'Ana nedenler';
const String kMsgMarineCompareFailed =
    'Nokta karşılaştırması alınamadı. Sunucu bağlantısını kontrol edip tekrar deneyin.';
const String kMsgMarineCompareTimeout =
    'Nokta karşılaştırması zaman aşımına uğradı. Biraz sonra tekrar deneyin.';

// —— Premium Dashboard (UI-1) ——
const String kPremiumDashTitle = 'Genel Bakış';
const String kPremiumSidebarOverview = 'Genel Bakış';
const String kPremiumSidebarLive = 'Canlı Alan';
const String kPremiumSidebarMarine = 'Koordinat Analizi';
const String kPremiumSidebarMap = 'Harita';
const String kPremiumSidebarSpots = 'Saved Spots';
const String kPremiumSidebarCatches = 'Av Kayıtları';
const String kPremiumSidebarCompare = 'Karşılaştırma';
const String kPremiumSidebarTimeline = 'Zaman Çizelgesi';
const String kPremiumSidebarSettings = 'Ayarlar';
const String kPremiumCaptainReady = 'Hazır';
const String kPremiumCaptainThinking = 'Düşünüyor…';
const String kPremiumCaptainResponding = 'Yanıtlıyor…';
const String kPremiumHeaderLocation = 'Konum';
const String kPremiumHeaderWeather = 'Hava';
const String kPremiumHeaderMoon = 'Ay';
const String kPremiumHeaderTide = 'Gelgit';
const String kPremiumDashMapTitle = 'Harita Önizleme';
const String kPremiumDashScoreLabel = 'Skor';
const String kPremiumDashUpdatedLabel = 'Güncelleme';
const String kPremiumDashZoomIn = 'Yakınlaştır';
const String kPremiumDashZoomOut = 'Uzaklaştır';
const String kPremiumDashLiveScoreTitle = 'Canlı Balıkçılık Skoru';
const String kPremiumDashTimelineTitle = 'Gün İçi Zaman Çizelgesi';
const String kPremiumDashSummaryTitle = 'Kısa Özet';
const String kPremiumDashSummaryBody =
    'Koşullar genel olarak uygun görünüyor. Rüzgar düşük, dalga orta seviyede.';
const String kPremiumDashSpotsTitle = 'Kayıtlı Spotlar';
const String kPremiumDashSpotsEmpty = 'Henüz kayıtlı nokta yok.';
const String kPremiumDashCatchesTitle = 'Son Av Kayıtları';
const String kPremiumDashCatchesEmpty = 'Av kaydı bulunmuyor.';
const String kPremiumDashCompareTitle = 'Karşılaştırma';
const String kPremiumDashCompareBody = 'İki noktayı yan yana değerlendirin.';
const String kPremiumDashForecastTitle = '7 Günlük Tahmin';
const String kPremiumDashTideTitle = 'Gelgit Grafiği';
const String kPremiumDashTideSeaMovementTitle = 'Gelgit / Deniz Hareketi';
const String kPremiumDashTideWaveChartLabel = 'Dalga (m)';
const String kPremiumDashTideSeaMovementNote =
    'Gelgit sağlayıcısı bağlı değil. Dalga/akıntı ile değerlendiriliyor.';
const String kPremiumDashTideNoDataNote =
    'Bu koordinatta gelgit/akıntı sağlayıcı verisi yok.';
const String kPremiumCaptainCardTitle = 'Captain Atlas';
const String kPremiumCaptainCardBadge = 'v1';
const String kPremiumCaptainCardMessage =
    'Denizden selamlar! Bugünkü koşulları birlikte okuyalım.';
const String kPremiumCaptainAskButton = "Captain Atlas'a Sor";

// UI-9 — Captain Atlas 2.0
const String kCaptainAtlasNoContextTitle = 'Captain Atlas';
const String kCaptainAtlasNoContextMessage =
    'Captain Atlas için önce bir analiz veya koordinat raporu oluşturun.';
const String kCaptainAtlasScreenTitle = 'Captain Atlas Komuta Merkezi';
const String kCaptainAtlasContextSection = 'Son Bağlam';
const String kCaptainAtlasQuickQuestions = 'Hızlı Sorular';
const String kCaptainAtlasQuickWhere = 'Bugün nereye gitmeliyim?';
const String kCaptainAtlasQuickWhen = 'Hangi saat daha uygun?';
const String kCaptainAtlasQuickRisk = 'Risk ne?';
const String kCaptainAtlasQuickAb = 'A mı B mi?';
const String kCaptainAtlasQuickWind = 'Rüzgar artarsa ne olur?';
const String kCaptainAtlasCtaMarine = 'Koordinat analizine git';
const String kCaptainAtlasCtaLive = 'Canlı alanı aç';
const String kCaptainAtlasCtaCompare = 'Karşılaştırma yap';
const String kCaptainAtlasContextReport = 'Son koordinat raporu';
const String kCaptainAtlasContextLive = 'Son canlı skor';
const String kCaptainAtlasContextCompare = 'Son karşılaştırma';
const String kCaptainAtlasContextSpot = 'Son kayıtlı spot';
const String kCaptainAtlasContextEmpty = 'Henüz bağlam yok';
const String kCaptainAtlasOpenSheet = 'Captain Atlas ile yorumla';
const String kMarineDeleteSpotConfirmTitle = 'Noktayı sil';
const String kMarineDeleteSpotConfirmMessage =
    'Bu kayıtlı nokta kalıcı olarak silinecek. Devam edilsin mi?';
const String kMarineCatchDeleteConfirmTitle = 'Av kaydını sil';
const String kMarineCatchDeleteConfirmMessage =
    'Bu av kaydı silinecek. Devam edilsin mi?';
const String kPremiumTimelineSlotMorning = '06:00 — Uygun';
const String kPremiumTimelineSlotMid = '12:00 — Sınırda';
const String kPremiumTimelineSlotEvening = '18:00 — Riskli';

// —— Premium Dashboard (UI-2) ——
const String kPremiumDashConnectionOk = 'Sunucu bağlı';
const String kPremiumDashConnectionOff = 'Sunucu kapalı';
const String kPremiumDashConnectionChecking = 'Bağlantı kontrol…';
const String kPremiumDashConnectionUnknown = 'Bağlantı bilinmiyor';
const String kPremiumDashNoLocation = 'Konum yok';
const String kPremiumDashNoData = 'Veri yok';
const String kPremiumDashPlaceholderDash = '--';
const String kPremiumDashJustNow = 'Az önce';
const String kPremiumDashRefresh = 'Yenile';
const String kPremiumDashLiveScoreEmpty =
    'Canlı skor için Canlı Alan ekranını açın.';
const String kPremiumDashLiveScoreCta = 'Canlı Alana Git';
const String kPremiumDashSpotsCta = 'Koordinat Analizine Git';
const String kPremiumDashCatchesEmptyLong = 'Henüz av kaydı yok.';
const String kPremiumDashCatchesCta = 'Av Kayıtlarına Git';
const String kPremiumDashCompareEmpty = 'Henüz karşılaştırma yapılmadı.';
const String kPremiumDashCompareCta = 'Karşılaştırma Yap';
const String kPremiumDashMarineEmpty = 'Henüz koordinat analizi yok.';
const String kPremiumDashMarineCta = 'Koordinat Analizine Git';
const String kPremiumDashCaptainEmpty =
    'Captain Atlas hazır. Bir koordinat analizi sonrası yorum alabilirsiniz.';
const String kPremiumDashCaptainFallbackBadge = 'Güvenli özet';
const String kPremiumDashTimelineEmpty = 'Zaman çizelgesi verisi yok.';
const String kPremiumDashTimelineNoCoordinate =
    'Zaman çizelgesi için koordinat analizi yapın.';
const String kPremiumDashTimelineNoHourlyWindow =
    'Saatlik zaman penceresi bu raporda yok.';
const String kPremiumDashTimelineRefreshing = 'Güncelleniyor…';
const String kPremiumDashTimelineCachedBadge = 'Son kayıtlı veri';
const String kPremiumDashTimelineRefreshCta = 'Güncelle';
const String kPremiumDashTimelineAnalyzeCta = 'Koordinat Analizi';
const String kPremiumDashForecastEmpty = '7 günlük tahmin verisi yok.';
const String kPremiumDashForecastEmptyHint =
    '7 günlük tahmin için güncel koordinat raporu alın.';
const String kPremiumDashForecastWaitingProvider =
    '7 günlük tahmin için sağlayıcı verisi bekleniyor.';
const String kPremiumDashForecastFetchFailed =
    '7 günlük tahmin sağlayıcıdan alınamadı.';
const String kPremiumDashTideEmpty = 'Gelgit verisi yok.';
const String kPremiumDashTideNoProvider =
    'Gelgit sağlayıcısı bağlı değil. Dalga/akıntı ile değerlendiriliyor.';
const String kPremiumDashCurrentUnavailable =
    'Akıntı verisi bu koordinatta yok.';
const String kPremiumDashForecastDaysAvailable = '{count} günlük veri mevcut';
const String kPremiumDashMapEmpty = 'Harita önizlemesi için analiz verisi gerekir.';
const String kPremiumDashMapEmptyAwaiting =
    'Harita önizlemesi için koordinat analizi yapın.';
const String kPremiumDashMapCta = 'Haritayı Aç';
const String kPremiumDashMapLastCoordinate = 'Son koordinat';
const String kPremiumDashMapLastUpdate = 'Son güncelleme';
const String kPremiumDashMapWave = 'Dalga';
const String kPremiumDashMapCurrent = 'Akıntı';
const String kPremiumDashMapWind = 'Rüzgar';
const String kPremiumDashMapDataSource = 'Veri kaynağı';
const String kPremiumDashMapRealData = 'Gerçek veri';
const String kPremiumDashMapSavedSpot = 'Kayıtlı nokta';
const String kPremiumDashMapComparePoint = 'Karşılaştırma noktası';
const String kPremiumDashMapSourceReport = 'Marine rapor';
const String kPremiumDashMapSourceSavedSpot = 'Kayıtlı nokta';
const String kPremiumDashMapSourceCompare = 'Karşılaştırma';
const String kPremiumDashMapSavedSpotsCta = 'Kayıtlı Noktalar';
const String kPremiumDashMapCompareCta = 'Karşılaştır';

// UI-10 — Mission Control Dashboard
const String kMissionControlTitle = 'MeraSonar Mission Control';
const String kMissionControlSubtitle = 'Deniz operasyon komuta merkezi';
const String kMissionNoActiveMission = 'Henüz aktif görev yok';
const String kMissionScoreTitle = 'Mission Score';
const String kMissionScoreSubtitle = 'Marine Index';
const String kMissionScoreEmpty =
    'Koordinat analizi sonrası görev skoru burada görünür.';
const String kMissionScoreCta = 'Koordinat Analizi';
const String kMissionBestActionLabel = 'Önerilen aksiyon';
const String kMissionDecisionLabel = 'Karar';
const String kMissionRiskLabel = 'Risk';
const String kMissionConfidenceLabel = 'Güven';
const String kMissionLiveIndexTitle = 'Canlı Marine Index';
const String kMissionTimelineTitle = 'Decision Timeline';
const String kMissionTimelineEmpty =
    'Bir analiz sonrası zaman pencereleri burada görünür.';
const String kMissionTimelineBestWindow = 'En iyi pencere';
const String kMissionMapActiveTitle = 'Active Map Preview';
const String kMissionMapHotspots = 'Hotspot';
const String kMissionMapWinner = 'Kazanan';
const String kMissionCaptainCommandTitle = 'Captain Atlas Command';
const String kMissionCaptainContext = 'Son bağlam';
const String kMissionSpotsStripTitle = 'Saved Spots Intelligence';
const String kMissionCatchStripTitle = 'Catch Intelligence';
const String kMissionCatchCountLabel = 'Kayıt';
const String kMissionCompareStripTitle = 'Compare Snapshot';
const String kMissionSystemStatusTitle = 'System / Provider Status';
const String kMissionSystemBackend = 'Backend';
const String kMissionSystemMarine = 'Marine Intelligence';
const String kMissionSystemAi = 'Captain Atlas AI';
const String kMissionSystemCache = 'Önbellek';
const String kMissionSystemCacheFresh = 'Güncel';
const String kMissionSystemCacheStale = 'Eski veri';
const String kMissionSystemOnline = 'Çevrimiçi';
const String kMissionSystemOffline = 'Çevrimdışı';
const String kMissionSystemReady = 'Hazır';
const String kMissionDockMap = 'Harita';
const String kMissionDockMarine = 'Koordinat';
const String kMissionDockLive = 'Canlı';
const String kMissionDockCompare = 'Karşılaştır';
const String kMissionDockCaptain = 'Captain';
const String kMissionStaleData = 'Eski veri';
const String kMissionLastUpdate = 'Son güncelleme';
const String kMissionReputationLabel = 'İtibar';

// —— Release Hardening — performans / offline tutarlılık ——
const String kPremiumPerformanceModeTitle = 'Performans modu';
const String kPremiumPerformanceModeFull = 'Tam';
const String kPremiumPerformanceModeBalanced = 'Dengeli';
const String kPremiumPerformanceModeBattery = 'Pil tasarrufu';
const String kPremiumPerformanceModeFullHint =
    'Ambient, glow ve blur tam kapasitede';
const String kPremiumPerformanceModeBalancedHint =
    'Ambient yavaş, blur ve glow azaltılmış';
const String kPremiumPerformanceModeBatteryHint =
    'Ambient statik, blur düşük, sonsuz animasyon kapalı';
const String kPremiumSectionErrorTitle = 'Bu bölüm yüklenemedi';
const String kPremiumNoConnection = 'Bağlantı yok';
const String kPremiumLastSavedData = 'Son kayıtlı veri';
const String kPremiumCacheFromLocal = 'Önbellekten geldi';
const String kPremiumNoDataLabel = 'Veri yok';

// —— Live Area Premium (UI-3) ——
const String kLiveGpsTrustTitle = 'GPS güveni';
const String kLiveGpsTrustReliable = 'Güvenilir';
const String kLiveGpsTrustMedium = 'Orta';
const String kLiveGpsTrustLow = 'Düşük';
const String kLiveGpsTrustUnknown = 'Bilinmiyor';
const String kLiveGpsEmptyTitle = 'Konum durumu';
const String kLiveHotspotEmptyTitle = 'Yakın hotspot yok';
const String kLiveHotspotEmptyBody =
    'Son analiz yok. Yakındaki hotspotlar için önce alan analizi yapın.';
const String kLiveHotspotCtaScan = 'Alanı Tara';
const String kLiveHotspotCtaMap = 'Haritayı Aç';
const String kLiveHotspotTrustLabel = 'Güven';
const String kLiveHotspotTrustFromAnalysis = 'Son analize göre';
const String kLiveCaptainEmpty =
    'Canlı konum ve son analizle kısa bir değerlendirme alabilirsiniz.';
const String kLiveSafetyAdviceBadge = 'Tavsiye niteliğindedir';
const String kLiveSafetyLineProbabilistic = kTrustAlways;
const String kLiveSafetyLineGpsCalibration =
    'GPS ve harita kalibrasyonu sonuçları etkileyebilir.';
const String kLiveSafetyLineOfficialWarnings =
    'Resmi deniz uyarılarını takip edin.';
