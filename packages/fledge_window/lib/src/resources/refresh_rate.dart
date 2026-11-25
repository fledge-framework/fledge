import 'dart:ui' as ui;

/// A display as Flutter's engine reports it (`PlatformDispatcher.displays`):
/// its size in physical pixels and its refresh rate.
typedef EngineDisplay = ({ui.Size physicalSize, double refreshRate});

/// The displays Flutter's engine knows about. Empty when there is no
/// binding yet, or on a platform that doesn't report displays.
List<EngineDisplay> engineDisplays() {
  try {
    return [
      for (final display in ui.PlatformDispatcher.instance.displays)
        (physicalSize: display.size, refreshRate: display.refreshRate),
    ];
  } catch (_) {
    return const [];
  }
}

/// Refresh rates for displays described by `screen_retriever`, which
/// doesn't report them, taken from the matching [engine] displays.
///
/// Each entry of [displays] is a display's size and scale factor. A display
/// matches the engine display whose physical size equals its size times its
/// scale factor (or its size as is, for backends that report physical
/// pixels), within two pixels; identical monitors are paired in order. A
/// display with no match, or whose match reports no rate, gets [fallback],
/// except that when the engine knows exactly one display, every unmatched
/// display gets that one's rate.
List<double> matchRefreshRates(
  List<({ui.Size size, double scaleFactor})> displays,
  List<EngineDisplay> engine, {
  required double fallback,
}) {
  bool near(ui.Size a, ui.Size b) =>
      (a.width - b.width).abs() <= 2 && (a.height - b.height).abs() <= 2;

  final used = <int>{};
  final rates = <double>[];
  for (final display in displays) {
    final physical = display.size * display.scaleFactor;
    var match = -1;
    for (var i = 0; i < engine.length && match < 0; i++) {
      if (used.contains(i)) continue;
      final size = engine[i].physicalSize;
      if (near(size, physical) || near(size, display.size)) match = i;
    }
    if (match >= 0) used.add(match);
    final rate = match >= 0
        ? engine[match].refreshRate
        : engine.length == 1
        ? engine.single.refreshRate
        : 0.0;
    rates.add(rate > 0 ? rate : fallback);
  }
  return rates;
}
