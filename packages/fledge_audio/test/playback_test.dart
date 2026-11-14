import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

const _fade = Duration(seconds: 2);

void main() {
  late FakeBackend backend;
  late App app;
  late World world;

  /// Lets engine-start and load futures land.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// One frame of [delta] seconds.
  Future<void> frame([double delta = 1 / 60]) async {
    world.getResource<WallTime>()!.delta = delta;
    await app.tick();
  }

  /// The responses the last frame sent.
  List<T> sent<T>() {
    world.updateEvents();
    return world.eventReader<T>().read().toList();
  }

  /// Starts the engine and finishes every load asked for so far.
  Future<void> ready() async {
    backend.start();
    await settle();
    await frame(); // starts the loads
    for (final path in backend.loads.keys) {
      if (!backend.loads[path]!.isCompleted) backend.finishLoad(path);
    }
    await settle();
  }

  setUp(() {
    backend = FakeBackend();
    app = App()
      ..insertResource(WallTime())
      ..addPlugin(AudioPlugin(backend: backend));
    world = app.world
      ..loadMusic('morning', 'music/morning.ogg')
      ..loadMusic('afternoon', 'music/afternoon.ogg')
      ..loadMusic('night', 'music/night.ogg')
      ..loadSound('hoe', 'sounds/hoe.wav');
  });

  group('starting up', () {
    test('the frame never waits for the engine', () async {
      await frame(); // the engine hasn't started: this returns anyway
      expect(world.audioState!.isInitialized, isFalse);
      backend.start();
      await settle();
      expect(world.audioState!.isInitialized, isTrue);
    });

    test(
      'music asked for before the engine starts plays once it can',
      () async {
        world.playMusic('morning');
        await frame();
        await frame();
        await ready();
        await frame();
        final voice = world.audioState!.currentMusicVoice!;
        expect(backend.voice(voice).source, 'source:music/morning.ogg');
        expect(world.currentMusicKey, 'morning');
        expect(sent<AudioFailed>(), isEmpty);
      },
    );

    test('music streams; sound effects are decoded up front', () async {
      await ready();
      expect(backend.streamed['music/morning.ogg'], isTrue);
      expect(backend.streamed['sounds/hoe.wav'], isFalse);
    });

    test('loaded clips are announced', () async {
      backend.start();
      await settle();
      await frame();
      backend.finishLoad('music/morning.ogg');
      backend.failLoad('music/night.ogg', 'no such file');
      await settle();
      await frame();
      expect(sent<AudioAssetLoaded>().map((e) => e.key), ['morning']);
    });

    test('a failed load is reported once, and its music fails', () async {
      backend.start();
      await settle();
      await frame();
      backend.failLoad('music/night.ogg', 'no such file');
      await settle();
      world.playMusic('night');
      await frame();
      final failures = sent<AudioFailed>();
      expect(failures.map((f) => f.key), ['night', 'night']);
      expect(failures.first.error, contains('no such file'));
      await frame();
      expect(sent<AudioFailed>(), isEmpty);
    });

    test('an engine that fails to start leaves audio off, quietly', () async {
      await frame(); // asks the engine to start
      backend.failStart('no device');
      await settle();
      world.playMusic('morning');
      await frame();
      expect(world.audioState!.isInitialized, isFalse);
      expect(world.audioState!.initError, 'no device');
      expect(backend.voices, isEmpty);
    });
  });

  group('music', () {
    test('only the latest request counts while clips load', () async {
      backend.start();
      await settle();
      world
        ..playMusic('morning')
        ..playMusic('afternoon');
      await frame();
      backend.finishLoad('music/afternoon.ogg');
      await settle();
      await frame();
      expect(world.currentMusicKey, 'afternoon');
      backend.finishLoad('music/morning.ogg');
      await settle();
      await frame();
      expect(world.currentMusicKey, 'afternoon');
      expect(backend.playing, hasLength(1));
    });

    test('asking for the track already playing changes nothing', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final voice = world.audioState!.currentMusicVoice;
      world.playMusic('morning', crossfade: _fade);
      await frame();
      expect(world.audioState!.currentMusicVoice, voice);
      expect(backend.playing, hasLength(1));
      world.playMusic('morning', restart: true);
      await frame();
      expect(world.audioState!.currentMusicVoice, isNot(voice));
    });

    test('a crossfade fades the old track out and the new one in', () async {
      await ready();
      world.setVolume(AudioChannel.music, 0.5);
      world.playMusic('morning');
      await frame();
      final old = world.audioState!.currentMusicVoice!;
      sent<MusicStarted>();
      world.playMusic('afternoon', volume: 0.8, crossfade: _fade);
      await frame();
      final now = world.audioState!.currentMusicVoice!;
      expect(backend.voice(old).fade, (0.0, _fade));
      expect(backend.voice(old).stopAfter, _fade);
      expect(backend.voice(now).volume, 0.0);
      expect(backend.voice(now).fade, (0.4, _fade));
      final changed = sent<MusicChanged>().single;
      expect((changed.previousKey, changed.newKey), ('morning', 'afternoon'));
    });

    test('fading in from silence really fades in', () async {
      await ready();
      world.playMusic('morning', crossfade: _fade);
      await frame();
      final voice = backend.voice(world.audioState!.currentMusicVoice!);
      expect(voice.volume, 0.0);
      expect(voice.fade, (1.0, _fade));
    });

    test('crossfades that overlap leave no track behind', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final first = world.audioState!.currentMusicVoice!;
      world.playMusic('afternoon', crossfade: _fade);
      await frame();
      final second = world.audioState!.currentMusicVoice!;
      world.playMusic('night', crossfade: _fade);
      await frame();
      // Both earlier tracks fade out and stop themselves.
      for (final voice in [first, second]) {
        expect(backend.voice(voice).fade!.$1, 0.0);
        expect(backend.voice(voice).stopAfter, _fade);
      }
      expect(world.audioState!.fadingOut, [first, second]);
      backend
        ..end(first)
        ..end(second);
      await frame();
      expect(world.audioState!.fadingOut, isEmpty);
    });

    test('a channel change reaches the track that is playing', () async {
      await ready();
      world.playMusic('morning', volume: 0.8);
      await frame();
      final voice = backend.voice(world.audioState!.currentMusicVoice!);
      world.setVolume(AudioChannel.music, 0.5);
      await frame();
      expect(voice.fade!.$1, closeTo(0.4, 1e-9));
    });

    test('a channel change mid fade-in keeps the fade\'s length', () async {
      await ready();
      world.playMusic('morning', crossfade: _fade);
      await frame(0.5);
      final voice = backend.voice(world.audioState!.currentMusicVoice!);
      world.setVolume(AudioChannel.music, 0.5);
      await frame(0.5);
      final (to, over) = voice.fade!;
      expect(to, 0.5);
      expect(over.inMilliseconds, closeTo(1500, 20));
    });

    test('stopping with a fade fades out and forgets the track', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final voice = world.audioState!.currentMusicVoice!;
      world.stopMusic(fadeOut: _fade);
      await frame();
      expect(backend.voice(voice).fade, (0.0, _fade));
      expect(backend.voice(voice).stopAfter, _fade);
      expect(world.currentMusicKey, isNull);
    });

    test('a track that does not loop says when it ends', () async {
      await ready();
      world.playMusic('morning', loop: false);
      await frame();
      backend.end(world.audioState!.currentMusicVoice!);
      await frame();
      expect(sent<MusicFinished>().single.musicKey, 'morning');
      expect(world.currentMusicKey, isNull);
    });
  });

  group('sound effects', () {
    test('play at the sfx channel volume, and say when they end', () async {
      await ready();
      world.setVolume(AudioChannel.sfx, 0.5);
      world.playSfx('hoe', volume: 0.8);
      await frame();
      final started = sent<SfxStarted>().single;
      expect(backend.voice(started.voice).volume, closeTo(0.4, 1e-9));
      backend.end(started.voice);
      await frame();
      expect(sent<SfxFinished>().single.soundKey, 'hoe');
    });

    test('are skipped, with a reason, when they cannot play', () async {
      backend.start();
      await settle();
      world
        ..playSfx('hoe') // still loading
        ..playSfx('nope'); // unknown
      await frame();
      final reasons = {for (final f in sent<AudioFailed>()) f.key: f.error};
      expect(reasons['hoe'], 'still loading');
      expect(reasons['nope'], contains('no such sound'));
    });

    test(
      'with a position, are panned and attenuated from the listener',
      () async {
        await ready();
        world.spawn()
          ..insert(Transform2D.from(0, 0))
          ..insert(AudioListener());
        world
          ..playSfx('hoe', position: (0, 0))
          ..playSfx('hoe', position: (600, 0));
        await frame();
        final voices = [
          for (final s in sent<SfxStarted>()) backend.voice(s.voice),
        ];
        expect(voices[0].volume, 1.0);
        expect(voices[0].pan, 0.0);
        expect(voices[1].volume, lessThan(1.0));
        expect(voices[1].pan, greaterThan(0.0));
      },
    );
  });

  group('pausing', () {
    test('pauses and resumes every voice; new music starts paused', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final music = backend.voice(world.audioState!.currentMusicVoice!);
      world.pauseAudio();
      await frame();
      expect(music.paused, isTrue);
      world.playMusic('afternoon', crossfade: _fade);
      await frame();
      final next = backend.voice(world.audioState!.currentMusicVoice!);
      expect(next.paused, isTrue);
      world.resumeAudio();
      await frame();
      expect(music.paused, isFalse);
      expect(next.paused, isFalse);
    });

    test('losing focus pauses, regaining it resumes', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final music = backend.voice(world.audioState!.currentMusicVoice!);
      world.getResource<AudioFocus>()!.hasFocus = false;
      await frame();
      expect(music.paused, isTrue);
      expect(sent<AudioPaused>().single.byFocusLoss, isTrue);
      world.getResource<AudioFocus>()!.hasFocus = true;
      await frame();
      expect(music.paused, isFalse);
    });

    test('focus coming back leaves the game\'s own pause alone', () async {
      await ready();
      world.pauseAudio();
      await frame();
      world.getResource<AudioFocus>()!
        ..hasFocus = false
        ..hasFocus = true;
      await frame();
      expect(world.isAudioPaused, isTrue);
    });
  });

  group('pumping (the world not ticking)', () {
    test('music starts with only pumps, no ticks', () async {
      world.playMusic('morning');
      await world.pumpAudio(); // asks the engine to start
      backend.start();
      await settle();
      await world.pumpAudio(); // starts the loads
      backend.finishLoad('music/morning.ogg');
      await settle();
      await world.pumpAudio();
      expect(world.currentMusicKey, 'morning');
    });

    test('gameplay events waiting for the next tick are left alone', () async {
      app.addEvent<_Gameplay>();
      world.eventWriter<_Gameplay>().send(const _Gameplay());
      await world.pumpAudio();
      await world.pumpAudio();
      world.updateEvents(); // what the next tick does first
      expect(world.eventReader<_Gameplay>().read(), hasLength(1));
    });

    test('focus pause works while the world is still', () async {
      await ready();
      world.playMusic('morning');
      await frame();
      final music = backend.voice(world.audioState!.currentMusicVoice!);
      world.getResource<AudioFocus>()!.hasFocus = false;
      await world.pumpAudio();
      expect(music.paused, isTrue);
    });
  });

  test('every system orders explicitly', () {
    expect(app.checkScheduleOrdering(), isEmpty);
  });
}

class _Gameplay {
  const _Gameplay();
}
