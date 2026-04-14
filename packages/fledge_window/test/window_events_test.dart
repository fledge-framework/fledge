import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fledge_window/fledge_window.dart';

void main() {
  group('WindowOperationFailed', () {
    test('toString includes the operation and reason', () {
      const failure = WindowOperationFailed(
        operation: 'setMode',
        reason: 'display not found',
      );
      final s = failure.toString();
      expect(s, contains('setMode'));
      expect(s, contains('display not found'));
    });

    test('toString includes attemptedMode when set', () {
      const failure = WindowOperationFailed(
        operation: 'setMode',
        reason: 'denied',
        attemptedMode: WindowMode.fullscreen,
      );
      expect(failure.toString(), contains('fullscreen'));
    });

    test('attemptedMode is optional', () {
      const failure = WindowOperationFailed(
        operation: 'resize',
        reason: 'bad size',
      );
      expect(failure.attemptedMode, isNull);
    });
  });

  group('WindowEventSystem.centerOnDisplay', () {
    test('centres a window inside primary display bounds', () {
      const displayBounds = Rect.fromLTWH(0, 0, 1920, 1080);
      final offset = WindowEventSystem.centerOnDisplay(
        const Size(1280, 720),
        displayBounds,
      );
      expect(offset.dx, 320);
      expect(offset.dy, 180);
    });

    test('accounts for non-zero display origin (secondary monitor)', () {
      const displayBounds = Rect.fromLTWH(1920, 100, 2560, 1440);
      final offset = WindowEventSystem.centerOnDisplay(
        const Size(1280, 720),
        displayBounds,
      );
      expect(offset.dx, 1920 + (2560 - 1280) / 2);
      expect(offset.dy, 100 + (1440 - 720) / 2);
    });

    test('a window the same size as the display sits at its origin', () {
      const displayBounds = Rect.fromLTWH(50, 50, 1920, 1080);
      final offset = WindowEventSystem.centerOnDisplay(
        const Size(1920, 1080),
        displayBounds,
      );
      expect(offset.dx, 50);
      expect(offset.dy, 50);
    });
  });
}
