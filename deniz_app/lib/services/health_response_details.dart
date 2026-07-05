import 'dart:convert';

import 'package:deniz_app/services/backend_discovery_service.dart';

/// `/health` yanıt ayrıştırma.
class HealthResponseDetails {
  const HealthResponseDetails({
    required this.valid,
    this.status,
    this.service,
    this.version,
  });

  final bool valid;
  final String? status;
  final String? service;
  final String? version;

  factory HealthResponseDetails.fromBody(String body) {
    if (!validateHealthResponse(body)) {
      return const HealthResponseDetails(valid: false);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const HealthResponseDetails(valid: false);
      }
      final m = Map<String, dynamic>.from(decoded);
      return HealthResponseDetails(
        valid: true,
        status: m['status']?.toString(),
        service: m['service']?.toString(),
        version: m['version']?.toString(),
      );
    } catch (_) {
      return const HealthResponseDetails(valid: false);
    }
  }
}
