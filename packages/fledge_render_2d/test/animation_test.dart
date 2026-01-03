import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimationFrame', () {
    test('creates with index and duration', () {
      const frame = AnimationFrame(index: 5, duration: 0.1);
      expect(frame.index, 5);
      expect(frame.duration, 0.1);
    });
  });

  group('AnimationClip', () {
    test('creates from frames', () {
      final clip = AnimationClip(
        name: 'test',
        frames: const [
          AnimationFrame(index: 0, duration: 0.1),
          AnimationFrame(index: 1, duration: 0.2),
          AnimationFrame(index: 2, duration: 0.15),
        ],
      );

      expect(clip.name, 'test');
      expect(clip.frameCount, 3);
      expect(clip.looping, isTrue);
      expect(clip.duration, closeTo(0.45, 0.001));
    });

    test('creates from index range', () {
      final clip = AnimationClip.fromIndices(
        name: 'walk',
        startIndex: 4,
        endIndex: 7,
        frameDuration: 0.1,
      );

      expect(clip.name, 'walk');
      expect(clip.frameCount, 4);
      expect(clip.frames[0].index, 4);
      expect(clip.frames[3].index, 7);
      expect(clip.duration, closeTo(0.4, 0.001));
    });

    test('creates from index list', () {
      final clip = AnimationClip.fromIndexList(
        name: 'custom',
        indices: [0, 2, 4, 6, 4, 2],
        frameDuration: 0.1,
      );

      expect(clip.frameCount, 6);
      expect(clip.frames[4].index, 4);
    });

    test('creates with variable durations', () {
      final clip = AnimationClip.withDurations(
        name: 'variable',
        indices: [0, 1, 2],
        durations: [0.1, 0.2, 0.3],
      );

      expect(clip.duration, closeTo(0.6, 0.001));
      expect(clip.frames[1].duration, 0.2);
    });

    test('throws on mismatched lengths', () {
      expect(
        () => AnimationClip.withDurations(
          name: 'invalid',
          indices: [0, 1],
          durations: [0.1],
        ),
        throwsArgumentError,
      );
    });

    test('getFrameAtTime returns correct frame index', () {
      final clip = AnimationClip(
        name: 'test',
        frames: const [
          AnimationFrame(index: 0, duration: 0.1),
          AnimationFrame(index: 1, duration: 0.1),
          AnimationFrame(index: 2, duration: 0.1),
        ],
        looping: true,
      );

      expect(clip.getFrameAtTime(0), 0);
      expect(clip.getFrameAtTime(0.05), 0);
      expect(clip.getFrameAtTime(0.1), 1);
      expect(clip.getFrameAtTime(0.15), 1);
      expect(clip.getFrameAtTime(0.25), 2);
    });

    test('getFrameAtTime loops for looping clips', () {
      final clip = AnimationClip.fromIndices(
        name: 'loop',
        startIndex: 0,
        endIndex: 2,
        frameDuration: 0.1,
        looping: true,
      );

      // At time 0.35, which is 0.05 into the second loop
      expect(clip.getFrameAtTime(0.35), 0);
    });

    test('getFrameAtTime clamps for non-looping clips', () {
      final clip = AnimationClip.fromIndices(
        name: 'once',
        startIndex: 0,
        endIndex: 2,
        frameDuration: 0.1,
        looping: false,
      );

      // At time 0.5, which is past the end (0.3)
      expect(clip.getFrameAtTime(0.5), 2);
    });

    test('isStatic for single-frame clips', () {
      final singleFrame = AnimationClip(
        name: 'static',
        frames: const [AnimationFrame(index: 0, duration: 1)],
      );

      final multiFrame = AnimationClip.fromIndices(
        name: 'animated',
        startIndex: 0,
        endIndex: 2,
        frameDuration: 0.1,
      );

      expect(singleFrame.isStatic, isTrue);
      expect(multiFrame.isStatic, isFalse);
    });
  });

  group('AnimationPlayer', () {
    late AnimationPlayer player;

    setUp(() {
      player = AnimationPlayer(
        animations: {
          'idle': AnimationClip.fromIndices(
            name: 'idle',
            startIndex: 0,
            endIndex: 3,
            frameDuration: 0.2,
          ),
          'walk': AnimationClip.fromIndices(
            name: 'walk',
            startIndex: 4,
            endIndex: 7,
            frameDuration: 0.1,
          ),
          'attack': AnimationClip.fromIndices(
            name: 'attack',
            startIndex: 8,
            endIndex: 11,
            frameDuration: 0.1,
            looping: false,
          ),
        },
      );
    });

    test('starts stopped', () {
      expect(player.isStopped, isTrue);
      expect(player.currentAnimation, isNull);
    });

    test('plays animation', () {
      player.play('idle');

      expect(player.isPlaying, isTrue);
      expect(player.currentAnimation, 'idle');
      expect(player.currentIndex, 0);
    });

    test('updates animation', () {
      player.play('idle');
      player.update(0.25);

      expect(player.currentIndex, 1);
    });

    test('pauses and resumes', () {
      player.play('idle');
      player.update(0.1);

      player.pause();
      expect(player.isPaused, isTrue);

      player.update(0.5); // Should not advance while paused
      expect(player.currentIndex, 0);

      player.resume();
      expect(player.isPlaying, isTrue);
    });

    test('stops animation', () {
      player.play('idle');
      player.update(0.5);

      player.stop();

      expect(player.isStopped, isTrue);
      expect(player.time, 0);
    });

    test('toggles play/pause', () {
      player.play('idle');
      player.toggle();
      expect(player.isPaused, isTrue);

      player.toggle();
      expect(player.isPlaying, isTrue);
    });

    test('switches animations', () {
      player.play('idle');
      player.update(0.5);

      player.play('walk');

      expect(player.currentAnimation, 'walk');
      expect(player.time, 0); // Reset on switch
    });

    test('does not restart same animation without flag', () {
      player.play('idle');
      player.update(0.3);
      final timeBeforeReplay = player.time;

      player.play('idle'); // Same animation

      expect(player.time, timeBeforeReplay);
    });

    test('restarts same animation with flag', () {
      player.play('idle');
      player.update(0.3);

      player.play('idle', restart: true);

      expect(player.time, 0);
    });

    test('non-looping animation stops at end', () {
      player.play('attack');

      final finished = player.update(0.5); // Past the 0.4 duration

      expect(finished, isTrue);
      expect(player.isStopped, isTrue);
    });

    test('speed multiplier', () {
      player.play('idle');
      player.speed = 2.0;
      player.update(0.1);

      // Should have advanced 0.2 seconds worth
      expect(player.currentIndex, 1);
    });

    test('progress getter/setter', () {
      player.play('idle'); // Duration 0.8

      player.setProgress(0.5);
      expect(player.time, closeTo(0.4, 0.001));

      expect(player.progress, closeTo(0.5, 0.001));
    });

    test('currentFrame returns frame index within clip', () {
      player.play('idle');

      expect(player.currentFrame, 0);

      player.update(0.25);
      expect(player.currentFrame, 1);

      player.update(0.25);
      expect(player.currentFrame, 2);
    });

    test('hasAnimation', () {
      expect(player.hasAnimation('idle'), isTrue);
      expect(player.hasAnimation('jump'), isFalse);
    });

    test('addAnimation', () {
      final newClip = AnimationClip.fromIndices(
        name: 'jump',
        startIndex: 12,
        endIndex: 15,
        frameDuration: 0.1,
      );

      player.addAnimation(newClip);

      expect(player.hasAnimation('jump'), isTrue);
      player.play('jump');
      expect(player.currentIndex, 12);
    });

    test('removeAnimation', () {
      player.play('idle');
      player.removeAnimation('idle');

      expect(player.hasAnimation('idle'), isFalse);
      expect(player.isStopped, isTrue);
      expect(player.currentClip, isNull);
    });

    test('throws on playing non-existent animation', () {
      expect(() => player.play('unknown'), throwsArgumentError);
    });

    test('autoPlay plays first animation', () {
      final autoPlayer = AnimationPlayer(
        animations: {
          'first': AnimationClip.fromIndices(
            name: 'first',
            startIndex: 0,
            endIndex: 2,
            frameDuration: 0.1,
          ),
        },
        autoPlay: true,
      );

      expect(autoPlayer.isPlaying, isTrue);
      expect(autoPlayer.currentAnimation, 'first');
    });

    test('initialAnimation starts specific animation', () {
      final initPlayer = AnimationPlayer(
        animations: {
          'a': AnimationClip.fromIndices(
              name: 'a', startIndex: 0, endIndex: 1, frameDuration: 0.1),
          'b': AnimationClip.fromIndices(
              name: 'b', startIndex: 2, endIndex: 3, frameDuration: 0.1),
        },
        initialAnimation: 'b',
      );

      expect(initPlayer.currentAnimation, 'b');
    });
  });

  group('AnimateSystem', () {
    test('updates delta time', () {
      final system = AnimateSystem();
      system.deltaTime = 0.016;

      expect(system.deltaTime, 0.016);
    });
  });

  group('AnimationTime', () {
    test('stores delta time', () {
      final time = AnimationTime();
      time.deltaTime = 0.033;

      expect(time.deltaTime, 0.033);
    });
  });
}
