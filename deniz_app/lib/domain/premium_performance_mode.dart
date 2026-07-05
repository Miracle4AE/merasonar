/// Kullanıcı performans tercihi — düşük cihaz / pil tasarrufu.
enum PremiumPerformanceMode {
  full,
  balanced,
  batterySaver,
}

extension PremiumPerformanceModeStorage on PremiumPerformanceMode {
  String get storageKey => name;

  static PremiumPerformanceMode fromStorage(String? raw) {
    return PremiumPerformanceMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => PremiumPerformanceMode.full,
    );
  }
}
