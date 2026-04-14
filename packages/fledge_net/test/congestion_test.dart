import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('CongestionController', () {
    late CongestionController controller;

    setUp(() {
      controller = CongestionController();
    });

    test('initial state has window 65536 and bytesInFlight 0', () {
      expect(controller.congestionWindow, 65536);
      expect(controller.bytesInFlight, 0);
    });

    test('canSend returns true when under window', () {
      expect(controller.canSend(1000), true);
    });

    test('canSend returns false when at window', () {
      controller.bytesInFlight = 65536;
      expect(controller.canSend(1), false);
    });

    test('canSend returns false when over window', () {
      controller.bytesInFlight = 65000;
      expect(controller.canSend(600), false);
    });

    test('onPacketSent increases bytesInFlight', () {
      controller.onPacketSent(500);
      expect(controller.bytesInFlight, 500);

      controller.onPacketSent(300);
      expect(controller.bytesInFlight, 800);
    });

    test('onPacketAcked decreases bytesInFlight and increases window', () {
      controller.onPacketSent(1000);
      expect(controller.bytesInFlight, 1000);

      final windowBefore = controller.congestionWindow;
      controller.onPacketAcked(600);

      expect(controller.bytesInFlight, 400);
      expect(controller.congestionWindow, greaterThan(windowBefore));
      // Window should increase by 100 (the _increaseStep).
      expect(controller.congestionWindow, windowBefore + 100);
    });

    test('onPacketLost halves the window', () {
      final windowBefore = controller.congestionWindow;
      controller.onPacketLost();
      expect(controller.congestionWindow, windowBefore * 0.5);
    });

    test('window does not go below minimum (1200)', () {
      // Set window to something small.
      controller.congestionWindow = 2000;
      controller.onPacketLost(); // 2000 * 0.5 = 1000, clamped to 1200
      expect(controller.congestionWindow, 1200);

      // Lose again, should stay at floor.
      controller.onPacketLost(); // 1200 * 0.5 = 600, clamped to 1200
      expect(controller.congestionWindow, 1200);
    });

    test('window does not go above maximum (256000)', () {
      controller.congestionWindow = 255950;
      controller.onPacketAcked(100); // +100 = 256050, clamped to 256000
      expect(controller.congestionWindow, 256000);

      // Another ack should not increase beyond max.
      controller.onPacketAcked(100);
      expect(controller.congestionWindow, 256000);
    });
  });
}
