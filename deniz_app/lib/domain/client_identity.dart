/// Backend Faz 5 `client_identity` sözleşmesi — opsiyonel AI istek alanı.
library;

class ClientIdentity {
  const ClientIdentity({
    required this.deviceId,
    this.userId,
    this.appVersion,
    this.platform = 'unknown',
    this.isPremium = false,
  });

  final String deviceId;
  final String? userId;
  final String? appVersion;
  final String platform;
  final bool isPremium;

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      if (userId != null && userId!.trim().isNotEmpty) 'user_id': userId,
      if (appVersion != null && appVersion!.trim().isNotEmpty)
        'app_version': appVersion,
      'platform': platform,
      'is_premium': isPremium,
    };
  }
}
