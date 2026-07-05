// Log ve crash raporlarında PII/secret sızıntısını azaltır.

String maskApiKey(String? value) {
  if (value == null || value.isEmpty) return '[empty]';
  if (value.length <= 8) return '[redacted]';
  return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
}

/// GPS koordinatlarını log için kısaltır (tam hassasiyet loglanmaz).
String truncateCoordinates(double? lat, double? lon, {int decimals = 2}) {
  if (lat == null || lon == null) return '[no-coords]';
  final la = lat.toStringAsFixed(decimals);
  final lo = lon.toStringAsFixed(decimals);
  return '$la,$lo';
}

String truncateLogBody(String body, {int maxLen = 160}) {
  if (body.length <= maxLen) return body;
  return '${body.substring(0, maxLen)}…[truncated]';
}

String sanitizeLogMessage(String message) {
  var out = message;
  out = out.replaceAllMapped(
    RegExp(r'sk-proj-[A-Za-z0-9_\-]{10,}', caseSensitive: false),
    (_) => '[openai-key-redacted]',
  );
  out = out.replaceAllMapped(
    RegExp(r'OPENAI_API_KEY\s*=\s*\S+', caseSensitive: false),
    (_) => 'OPENAI_API_KEY=[redacted]',
  );
  return out;
}
