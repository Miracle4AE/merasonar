import 'package:deniz_app/api_service.dart';

/// GPX 1.1 waypoint dışa aktarma (Garmin / telefon harita uygulamaları ile uyumlu).
class GpxExportService {
  GpxExportService._();

  static const String _xmlns = 'http://www.topografix.com/GPX/1/1';
  static const String creator = 'MeraSonar';

  /// Önerilen dosya adı: `deniz_mera_YYYYMMDD_HHMMSS.gpx`
  /// [single] verilirse tek nokta için: `deniz_mera_h{id}_{sınıf}_YYYYMMDD_HHMMSS.gpx`
  static String suggestedFileName({Hotspot? single}) {
    final n = DateTime.now().toLocal();
    final d = n.day.toString().padLeft(2, '0');
    final mo = n.month.toString().padLeft(2, '0');
    final h = n.hour.toString().padLeft(2, '0');
    final mi = n.minute.toString().padLeft(2, '0');
    final s = n.second.toString().padLeft(2, '0');
    final ts = '${n.year}$mo${d}_$h$mi$s';
    if (single != null) {
      return 'deniz_mera_h${single.id}_${single.classification}_$ts.gpx';
    }
    return 'deniz_mera_$ts.gpx';
  }

  /// Geçerli enlem/boylamı olan [hotspots] için GPX XML üretir.
  static String buildDocument(List<Hotspot> hotspots) {
    final valid = hotspots.where(_hasValidCoords).toList(growable: false);

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
      '<gpx version="1.1" creator="${_xmlEscape(creator)}" xmlns="$_xmlns">',
    );
    buf.writeln('  <metadata>');
    buf.writeln(
      '    <name>${_xmlEscape('MeraSonar mera noktaları')}</name>',
    );
    buf.writeln(
      '    <time>${DateTime.now().toUtc().toIso8601String()}</time>',
    );
    buf.writeln('  </metadata>');
    for (final h in valid) {
      buf.writeln(
        '  <wpt lat="${_formatCoord(h.latitude)}" '
        'lon="${_formatCoord(h.longitude)}">',
      );
      buf.writeln('    <name>${_xmlEscape(waypointName(h))}</name>');
      buf.writeln('    <desc>${_xmlEscape(waypointDesc(h))}</desc>');
      buf.writeln('    <type>${_xmlEscape('fishing_hotspot')}</type>');
      buf.writeln('  </wpt>');
    }
    buf.writeln('</gpx>');
    return buf.toString();
  }

  static bool _hasValidCoords(Hotspot h) {
    if (!h.latitude.isFinite || !h.longitude.isFinite) return false;
    if (h.latitude.abs() > 90 || h.longitude.abs() > 180) return false;
    return true;
  }

  /// Eski plotter uyumluluğu için kısa ASCII isim.
  static String waypointName(Hotspot h) {
    return 'M${h.id}_${h.classification}_r${h.rankByScoreThenDistance}';
  }

  static String waypointDesc(Hotspot h) {
    final lines = <String>[
      'Sınıf: ${h.classification}',
      'Skor: ${h.score.toStringAsFixed(3)}',
      'Mesafe: ${h.distanceM.toStringAsFixed(0)} m, yön: ${h.bearingDeg.toStringAsFixed(0)}°',
      if (h.reasoning.isNotEmpty) ...h.reasoning.take(4),
    ];
    return lines.join('\n');
  }

  static String _formatCoord(double v) {
    if (!v.isFinite) return '0.0';
    return v.toStringAsFixed(7);
  }

  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
