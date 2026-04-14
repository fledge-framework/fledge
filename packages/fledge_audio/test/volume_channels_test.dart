import 'package:fledge_audio/fledge_audio.dart';
import 'package:flutter_test/flutter_test.dart';

VolumeChannels _channels() => VolumeChannels(
      const AudioChannelConfig(music: 1, sfx: 1, voice: 1, ambient: 1),
    );

void main() {
  group('VolumeChannels basic', () {
    test('initial volumes come from config', () {
      final c = VolumeChannels(
        const AudioChannelConfig(music: 0.3, sfx: 0.6, voice: 1, ambient: 0.8),
      );
      expect(c.getVolume(AudioChannel.master), 1.0);
      expect(c.getVolume(AudioChannel.music), 0.3);
      expect(c.getVolume(AudioChannel.sfx), 0.6);
      expect(c.getVolume(AudioChannel.ambient), 0.8);
    });

    test('setVolume clamps to [0, 1]', () {
      final c = _channels();
      c.setVolume(AudioChannel.sfx, 2.5);
      expect(c.getVolume(AudioChannel.sfx), 1.0);
      c.setVolume(AudioChannel.sfx, -1);
      expect(c.getVolume(AudioChannel.sfx), 0.0);
    });

    test('effectiveVolume multiplies master by channel', () {
      final c = _channels();
      c.setVolume(AudioChannel.master, 0.5);
      c.setVolume(AudioChannel.music, 0.4);
      expect(c.getEffectiveVolume(AudioChannel.music), closeTo(0.2, 1e-9));
      expect(c.getEffectiveVolume(AudioChannel.master), 0.5);
    });
  });

  group('VolumeChannels fade', () {
    test('fadeTo with zero duration jumps to target and is not fading', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 0.8, Duration.zero);
      expect(c.getVolume(AudioChannel.music), 0.8);
      expect(c.isFading(AudioChannel.music), isFalse);
    });

    test('linear interpolation over duration', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 1.0, const Duration(seconds: 1));

      expect(c.isFading(AudioChannel.music), isTrue);
      expect(c.getVolume(AudioChannel.music), 0.0);

      c.advanceFades(0.25);
      expect(c.getVolume(AudioChannel.music), closeTo(0.25, 1e-9));

      c.advanceFades(0.5);
      expect(c.getVolume(AudioChannel.music), closeTo(0.75, 1e-9));

      c.advanceFades(0.5); // overshoots past 1.0
      expect(c.getVolume(AudioChannel.music), 1.0);
      expect(c.isFading(AudioChannel.music), isFalse);
    });

    test('fade direction works both ways', () {
      final c = _channels()..setVolume(AudioChannel.sfx, 1.0);
      c.fadeTo(AudioChannel.sfx, 0.0, const Duration(milliseconds: 500));
      c.advanceFades(0.25);
      expect(c.getVolume(AudioChannel.sfx), closeTo(0.5, 1e-9));
      c.advanceFades(0.25);
      expect(c.getVolume(AudioChannel.sfx), 0.0);
    });

    test('setVolume cancels an in-progress fade', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 1.0, const Duration(seconds: 1));
      c.advanceFades(0.25);
      c.setVolume(AudioChannel.music, 0.1);
      expect(c.isFading(AudioChannel.music), isFalse);
      c.advanceFades(10);
      expect(c.getVolume(AudioChannel.music), 0.1);
    });

    test('fadeTo replaces an active fade', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 1.0, const Duration(seconds: 10));
      c.advanceFades(1.0);
      // halfway to 0.1 of the original fade → 0.1 volume
      expect(c.getVolume(AudioChannel.music), closeTo(0.1, 1e-9));

      // Redirect: 0.1 → 0.5 over 1s, starts fresh at the current volume.
      c.fadeTo(AudioChannel.music, 0.5, const Duration(seconds: 1));
      c.advanceFades(0.5);
      expect(c.getVolume(AudioChannel.music), closeTo(0.3, 1e-9));
      c.advanceFades(0.5);
      expect(c.getVolume(AudioChannel.music), 0.5);
    });

    test('fadeTo target is clamped to [0, 1]', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 3, const Duration(seconds: 1));
      c.advanceFades(2);
      expect(c.getVolume(AudioChannel.music), 1.0);
    });

    test('advanceFades with zero/negative delta is a no-op', () {
      final c = _channels()..setVolume(AudioChannel.music, 0);
      c.fadeTo(AudioChannel.music, 1.0, const Duration(seconds: 1));
      c.advanceFades(0);
      expect(c.getVolume(AudioChannel.music), 0.0);
      c.advanceFades(-1);
      expect(c.getVolume(AudioChannel.music), 0.0);
    });

    test('independent fades per channel', () {
      final c = _channels()
        ..setVolume(AudioChannel.music, 0)
        ..setVolume(AudioChannel.sfx, 1.0);
      c.fadeTo(AudioChannel.music, 1.0, const Duration(seconds: 1));
      c.fadeTo(AudioChannel.sfx, 0.0, const Duration(seconds: 2));
      c.advanceFades(0.5);
      expect(c.getVolume(AudioChannel.music), closeTo(0.5, 1e-9));
      expect(c.getVolume(AudioChannel.sfx), closeTo(0.75, 1e-9));
    });
  });
}
