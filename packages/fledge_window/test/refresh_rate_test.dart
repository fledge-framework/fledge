import 'dart:ui';

import 'package:fledge_window/src/resources/refresh_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = 60.0;

  test('matches displays by physical size (logical size x scale)', () {
    final rates = matchRefreshRates(
      [
        (size: const Size(1512, 982), scaleFactor: 2.0), // MacBook, 120 Hz
        (size: const Size(2560, 1440), scaleFactor: 1.0), // monitor, 144 Hz
      ],
      [
        (physicalSize: const Size(2560, 1440), refreshRate: 144.0),
        (physicalSize: const Size(3024, 1964), refreshRate: 120.0),
      ],
      fallback: fallback,
    );
    expect(rates, [120.0, 144.0]);
  });

  test('also matches a backend that reports physical pixels', () {
    final rates = matchRefreshRates(
      [(size: const Size(3840, 2160), scaleFactor: 1.5)],
      [
        (physicalSize: const Size(1920, 1080), refreshRate: 60.0),
        (physicalSize: const Size(3840, 2160), refreshRate: 165.0),
      ],
      fallback: fallback,
    );
    expect(rates, [165.0]);
  });

  test('identical monitors pair up in order', () {
    final rates = matchRefreshRates(
      [
        (size: const Size(1920, 1080), scaleFactor: 1.0),
        (size: const Size(1920, 1080), scaleFactor: 1.0),
      ],
      [
        (physicalSize: const Size(1920, 1080), refreshRate: 75.0),
        (physicalSize: const Size(1920, 1080), refreshRate: 144.0),
      ],
      fallback: fallback,
    );
    expect(rates, [75.0, 144.0]);
  });

  test('a lone engine display covers an unmatched one', () {
    final rates = matchRefreshRates(
      [(size: const Size(1280, 800), scaleFactor: 1.25)],
      [(physicalSize: const Size(2000, 1000), refreshRate: 90.0)],
      fallback: fallback,
    );
    expect(rates, [90.0]);
  });

  test('no match, no engine displays, or no reported rate fall back', () {
    expect(
      matchRefreshRates(
        [(size: const Size(1920, 1080), scaleFactor: 1.0)],
        const [],
        fallback: fallback,
      ),
      [fallback],
    );
    expect(
      matchRefreshRates(
        [(size: const Size(1920, 1080), scaleFactor: 1.0)],
        [
          (physicalSize: const Size(1000, 1000), refreshRate: 75.0),
          (physicalSize: const Size(800, 600), refreshRate: 50.0),
        ],
        fallback: fallback,
      ),
      [fallback],
    );
    expect(
      matchRefreshRates(
        [(size: const Size(1920, 1080), scaleFactor: 1.0)],
        [(physicalSize: const Size(1920, 1080), refreshRate: 0.0)],
        fallback: fallback,
      ),
      [fallback],
    );
  });

  test('the test binding reports its display', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final displays = engineDisplays();
    expect(displays, isNotEmpty);
    expect(displays.first.refreshRate, greaterThan(0));
  });
}
