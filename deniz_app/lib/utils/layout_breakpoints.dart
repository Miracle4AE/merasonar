import 'package:flutter/widgets.dart';

/// Telefon / dar ekran düzeni (harita alanı öncelikli).
const double kMobileLayoutBreakpointWidth = 700;

/// Tablet — 2 kolon dashboard.
const double kTabletLayoutBreakpointWidth = 700;

/// Geniş masaüstü — tam sidebar + 3 kolon grid.
const double kDesktopLayoutBreakpointWidth = 1100;

bool useMobileLayout(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w > 0 && w < kMobileLayoutBreakpointWidth;
}

bool useTabletLayout(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= kTabletLayoutBreakpointWidth && w < kDesktopLayoutBreakpointWidth;
}

bool useDesktopLayout(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= kDesktopLayoutBreakpointWidth;
}
