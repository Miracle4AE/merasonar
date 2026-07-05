import 'package:flutter/material.dart';

/// Alt hotspot strip + command bar — çakışmayı önleyen birleşik chrome.
class MapBottomChrome extends StatelessWidget {
  const MapBottomChrome({
    super.key,
    required this.commandBar,
    this.hotspotStrip,
    this.showStrip = false,
  });

  final Widget commandBar;
  final Widget? hotspotStrip;
  final bool showStrip;

  static const double _stripHeight = 92;
  static const double _commandHeight = 64;
  static const double _gap = 6;
  static const double _padding = 8;

  static double reservedHeight({required bool hasStrip}) {
    return _padding +
        (hasStrip ? _stripHeight + _gap : 0) +
        _commandHeight +
        _padding;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, _padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStrip && hotspotStrip != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _stripHeight),
                child: ClipRect(child: hotspotStrip!),
              ),
              const SizedBox(height: _gap),
            ],
            commandBar,
          ],
        ),
      ),
    );
  }
}
