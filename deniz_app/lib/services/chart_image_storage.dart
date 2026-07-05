import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies a picked chart [XFile] into app storage so [File] paths remain valid
/// after the system content URI (`content://`) is revoked (Android-safe).
///
/// Uses [applicationDocumentsDirectory] so paths survive until the user clears app data.
Future<File> materializePickedChartImage(XFile xfile) async {
  final dir = await getApplicationDocumentsDirectory();
  final charts = Directory(p.join(dir.path, 'chart_imports'));
  if (!await charts.exists()) {
    await charts.create(recursive: true);
  }

  final originalName = xfile.name.trim();
  var ext = p.extension(originalName).toLowerCase();
  if (ext.isEmpty || ext == '.tmp') {
    ext = '.jpg';
  }
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final outPath =
      p.join(charts.path, 'chart_$stamp$ext');

  final bytes = await xfile.readAsBytes();
  final outFile = File(outPath);
  await outFile.writeAsBytes(bytes);
  return outFile;
}
