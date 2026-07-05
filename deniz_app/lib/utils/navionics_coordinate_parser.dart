/// Navionics girişi için izin verilen rakam sayısı (derece + MM.MMM).
int maxNavionicsEntryDigits({required bool isLatitude}) =>
    isLatitude ? 7 : 8;

/// Görüntülen metinden yalnızca rakamları çıkarır.
String extractNavionicsEntryDigits(String raw) =>
    raw.replaceAll(RegExp(r'\D'), '');

/// Ondalık dereceden Navionics giriş rakam dizisine (derece + dakika basamakları).
String decimalToNavionicsEntryDigits(
  double decimal, {
  required bool isLatitude,
}) {
  final abs = decimal.abs();
  final deg = abs.floor();
  final minutes = (abs - deg) * 60.0;
  final minInt = minutes.floor().clamp(0, 59);
  final minFrac = ((minutes - minInt) * 1000).round().clamp(0, 999);
  final degDigits = deg.toString();
  final minDigits =
      '${minInt.toString().padLeft(2, '0')}${minFrac.toString().padLeft(3, '0')}';
  return '$degDigits$minDigits';
}

/// Kullanıcının yazdığı rakamlardan Navionics metnini üretir.
///
/// Örnek enlem: `3724252` → `37°24.252' N`
/// Örnek boylam: `02713632` → `027°13.632' E`
String formatNavionicsEntryFromDigits(
  String digits, {
  required bool isLatitude,
}) {
  final maxDeg = isLatitude ? 2 : 3;
  final maxTotal = maxNavionicsEntryDigits(isLatitude: isLatitude);
  var clipped = extractNavionicsEntryDigits(digits);
  if (clipped.length > maxTotal) {
    clipped = clipped.substring(0, maxTotal);
  }
  if (clipped.isEmpty) return '';

  final degLen = clipped.length < maxDeg ? clipped.length : maxDeg;
  final degPart = clipped.substring(0, degLen);
  final minDigits = clipped.length > maxDeg ? clipped.substring(maxDeg) : '';
  final hemi = isLatitude ? 'N' : 'E';

  final degText = (!isLatitude && (minDigits.isNotEmpty || degPart.length >= maxDeg))
      ? degPart.padLeft(3, '0')
      : degPart;

  final buffer = StringBuffer(degText);
  if (clipped.length >= maxDeg || minDigits.isNotEmpty) {
    buffer.write('°');
  }
  if (minDigits.isNotEmpty) {
    if (minDigits.length <= 2) {
      buffer.write(minDigits);
    } else {
      buffer
        ..write(minDigits.substring(0, 2))
        ..write('.')
        ..write(minDigits.substring(2));
    }
  }
  if (minDigits.length >= 5) {
    buffer.write("' $hemi");
  }

  return buffer.toString();
}

/// Tam veya kısmi Navionics giriş metnini gösterim için normalize eder.
String normalizeNavionicsEntryDisplay(
  String raw, {
  required bool isLatitude,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final parsed = parseNavionicsCoordinate(trimmed, isLatitude: isLatitude);
  if (parsed != null) {
    return formatNavionicsCoordinate(parsed, isLatitude: isLatitude);
  }
  return formatNavionicsEntryFromDigits(
    extractNavionicsEntryDigits(trimmed),
    isLatitude: isLatitude,
  );
}

///
/// Örnekler: `37°24.252' N`, `27°13.632' E`, `37.4042`, `37,4042`
class NavionicsCoordinateParseResult {
  const NavionicsCoordinateParseResult({this.degrees, this.error});

  final double? degrees;
  final String? error;

  bool get isOk => degrees != null && error == null;
}

double? parseNavionicsCoordinate(String raw, {required bool isLatitude}) {
  return parseNavionicsCoordinateDetailed(
    raw,
    isLatitude: isLatitude,
  ).degrees;
}

NavionicsCoordinateParseResult parseNavionicsCoordinateDetailed(
  String raw, {
  required bool isLatitude,
}) {
  var s = raw.trim();
  if (s.isEmpty) {
    return const NavionicsCoordinateParseResult(error: 'Koordinat boş.');
  }

  final upper = s.toUpperCase().replaceAll(',', '.');
  var sign = 1;
  if (upper.contains('S') || upper.contains('G')) {
    sign = -1;
  } else if (upper.contains('W') || upper.contains('B')) {
    sign = -1;
  }

  if (upper.startsWith('-')) {
    sign = -1;
  } else if (upper.startsWith('+')) {
    sign = 1;
  }

  final cleaned = upper
      .replaceAll(RegExp(r'[NSEWGB\s_]'), '')
      .replaceAll('°', ' ')
      .replaceAll('º', ' ')
      .replaceAll("'", ' ')
      .replaceAll('′', ' ')
      .replaceAll('"', ' ')
      .replaceAll('″', ' ')
      .replaceAll('D', ' ')
      .replaceAll('M', ' ')
      .trim();

  if (cleaned.isEmpty) {
    return const NavionicsCoordinateParseResult(
      error: 'Geçerli bir koordinat girin.',
    );
  }

  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  double? value;
  if (parts.length == 1) {
    value = double.tryParse(parts.first);
  } else if (parts.length == 2) {
    final deg = double.tryParse(parts[0]);
    final min = double.tryParse(parts[1]);
    if (deg != null && min != null) {
      value = deg.abs() + (min.abs() / 60.0);
    }
  } else if (parts.length >= 3) {
    final deg = double.tryParse(parts[0]);
    final min = double.tryParse(parts[1]);
    final sec = double.tryParse(parts[2]);
    if (deg != null && min != null && sec != null) {
      value = deg.abs() + (min.abs() / 60.0) + (sec.abs() / 3600.0);
    }
  }

  if (value == null) {
    return const NavionicsCoordinateParseResult(
      error: 'Navionics formatı okunamadı. Örnek: 37°24.252\' N',
    );
  }

  final signed = value.abs() * sign;
  if (isLatitude && signed.abs() > 90) {
    return const NavionicsCoordinateParseResult(
      error: 'Enlem −90° ile +90° arasında olmalı.',
    );
  }
  if (!isLatitude && signed.abs() > 180) {
    return const NavionicsCoordinateParseResult(
      error: 'Boylam −180° ile +180° arasında olmalı.',
    );
  }

  return NavionicsCoordinateParseResult(degrees: signed);
}

/// Ondalık dereceyi Navionics’teki gibi `D°M.MMM' H` biçimine çevirir.
String formatNavionicsCoordinate(double decimal, {required bool isLatitude}) {
  final abs = decimal.abs();
  final deg = abs.floor();
  final minutes = (abs - deg) * 60.0;
  final hemi = isLatitude
      ? (decimal >= 0 ? 'N' : 'S')
      : (decimal >= 0 ? 'E' : 'W');
  final degWidth = isLatitude ? 2 : 3;
  final degText = deg.toString().padLeft(degWidth, '0');
  final minText = minutes.toStringAsFixed(3).padLeft(6, '0');
  return "$degText°$minText' $hemi";
}
