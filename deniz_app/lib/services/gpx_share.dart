import 'dart:convert' show utf8;
import 'dart:developer' show log;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api_service.dart';
import '../l10n/app_strings_tr.dart';
import 'gpx_export_service.dart';

/// GPX üretir, geçici dosyaya yazar ve sistem paylaşımını açar.
class GpxShare {
  GpxShare._();

  static bool _hasValidCoords(Hotspot h) {
    if (!h.latitude.isFinite || !h.longitude.isFinite) return false;
    if (h.latitude.abs() > 90 || h.longitude.abs() > 180) return false;
    return true;
  }

  /// [hotspots] boş veya tümü geçersiz koordinatlıysa [emptyMessage] ile SnackBar.
  static Future<void> shareHotspots(
    BuildContext context, {
    required List<Hotspot> hotspots,
    String shareText = kGpxShareDefaultCaption,
    String emptyMessage = kGpxEmptyDefault,
  }) async {
    final valid = hotspots.where(_hasValidCoords).toList(growable: false);
    if (valid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hotspots.isEmpty
                  ? emptyMessage
                  : kGpxNoCoordsValid,
            ),
          ),
        );
      }
      return;
    }

    try {
      final gpx = GpxExportService.buildDocument(valid);
      final dir = await getTemporaryDirectory();
      final name = valid.length == 1
          ? GpxExportService.suggestedFileName(single: valid.first)
          : GpxExportService.suggestedFileName();
      final file = File('${dir.path}/$name');
      await file.writeAsString(gpx, encoding: utf8);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/gpx+xml')],
        text: shareText,
        fileNameOverrides: [name],
      );
    } catch (e, st) {
      log('gpx_share: $e', name: 'GpxShare', stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(kGpxShareFailedSnack),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
