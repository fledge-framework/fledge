import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

const _engine = 'sounds/engine.wav';

void main() {
  late FakeBackend backend;
  late App app;
  late World world;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> frame() async {
    world.getResource<WallTime>()!.delta = 1 / 60;
    await app.tick();
  }

  List<T> sent<T>() {
    world.updateEvents();
    return world.eventReader<T>().read().toList();
  }

  /// Starts the engine and, unless [load] is false, loads every clip.
  Future<void> ready({bool load = true}) async {
    backend.start();
    await settle();
    await frame(); // starts the loads
    if (!load) return;
    for (final path in backend.loads.keys) {
      if (!backend.loads[path]!.isCompleted) backend.finishLoad(path);
    }
    await settle();
  }

  Future<void> setUpApp([AudioConfig config = const AudioConfig()]) async {
    backend = FakeBackend();
    app = App()
      ..insertResource(WallTime())
      ..addPlugin(AudioPlugin(config: config, backend: backend));
    world = app.world
      ..loadSound('engine', _engine)
      ..setVolume(AudioChannel.sfx, 0.5);
    // The first frame asks the engine to start; a test then starts it.
    await frame();
  }

  AudioSource sourceOf(Entity entity) => world.get<AudioSource>(entity)!;

  FakeVoice voiceOf(Entity entity) => backend.voice(sourceOf(entity).voice!);

  Iterable<FakeVoice> engineVoices() =>
      backend.playing.where((v) => v.source == 'source:$_engine');

  group('a looping source', () {
    setUp(setUpApp);

    test('auto-plays once its clip has loaded, and loops', () async {
      final e = world.spawn()
        ..insert(AudioSource.looping(soundKey: 'engine', volume: 0.8));
      await ready();
      await frame();
      expect(sourceOf(e.entity).isPlaying, isTrue);
      expect(voiceOf(e.entity).looping, isTrue);
    });

    test('stop() stops it at once, and play() starts it again', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final first = sourceOf(e.entity).voice!;

      sourceOf(e.entity).stop();
      await frame();
      expect(sourceOf(e.entity).isPlaying, isFalse);
      expect(backend.isPlaying(first), isFalse);
      expect(sent<SfxFinished>().map((f) => f.soundKey), ['engine']);
      await frame();
      expect(engineVoices(), isEmpty, reason: 'auto-play does not restart');

      sourceOf(e.entity).play();
      await frame();
      expect(sourceOf(e.entity).isPlaying, isTrue);
      expect(sourceOf(e.entity).voice, isNot(first));
      expect(engineVoices(), hasLength(1));
    });

    test('stop(fadeOut:) fades it out on the audio thread', () async {
      const fade = Duration(milliseconds: 500);
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;

      sourceOf(e.entity).stop(fadeOut: fade);
      await frame();
      expect(sourceOf(e.entity).isPlaying, isFalse);
      expect(backend.voice(voice).fade, (0.0, fade));
      expect(backend.voice(voice).stopAfter, fade);
      final volume = backend.voice(voice).volume;
      await frame();
      expect(
        backend.voice(voice).volume,
        volume,
        reason: 'no longer mixed by the source while it fades',
      );

      // Playable again while the old voice is still fading.
      sourceOf(e.entity).play();
      await frame();
      expect(sourceOf(e.entity).voice, isNot(voice));
      expect(engineVoices(), hasLength(2));
    });

    test('play() while playing restarts it', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final first = sourceOf(e.entity).voice!;
      sourceOf(e.entity).play();
      await frame();
      expect(backend.isPlaying(first), isFalse);
      expect(engineVoices(), hasLength(1));
      expect(sourceOf(e.entity).voice, isNot(first));
    });

    test('only the latest of play() and stop() in a frame counts', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      sourceOf(e.entity)
        ..play()
        ..stop();
      await frame();
      expect(engineVoices(), isEmpty);
    });
  });

  group('before it can play', () {
    setUp(setUpApp);

    test('a stop before the engine starts cancels auto-play', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await frame();
      sourceOf(e.entity).stop();
      await frame();
      await ready();
      await frame();
      await frame();
      expect(engineVoices(), isEmpty);
      expect(sourceOf(e.entity).isPlaying, isFalse);
    });

    test('a stop before the clip loads cancels auto-play', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready(load: false);
      sourceOf(e.entity).stop();
      await frame();
      backend.finishLoad(_engine);
      await settle();
      await frame();
      expect(engineVoices(), isEmpty);
    });

    test('a speed change while it plays reaches the voice (an engine '
        'revving)', () async {
      final e = world.spawn()
        ..insert(
          AudioSource(soundKey: 'engine', looping: true, playbackSpeed: 0.8),
        );
      await ready();
      sourceOf(e.entity).play();
      await frame();
      expect(voiceOf(e.entity).speed, 0.8);
      sourceOf(e.entity).playbackSpeed = 1.4;
      await frame();
      expect(voiceOf(e.entity).speed, 1.4);
    });

    test('a play() waits for the engine and the clip', () async {
      final e = world.spawn()
        ..insert(AudioSource(soundKey: 'engine', looping: true));
      sourceOf(e.entity).play();
      await frame();
      await ready(load: false);
      await frame();
      expect(sourceOf(e.entity).isPlaying, isFalse);
      backend.finishLoad(_engine);
      await settle();
      await frame();
      expect(sourceOf(e.entity).isPlaying, isTrue);
      expect(sourceOf(e.entity).request, isNull);
    });

    test('a source without autoPlay waits for play()', () async {
      final e = world.spawn()
        ..insert(AudioSource(soundKey: 'engine', looping: true));
      await ready();
      await frame();
      expect(sourceOf(e.entity).isPlaying, isFalse);
    });
  });

  group('while audio is paused', () {
    setUp(setUpApp);

    test('a stop with a fade stops at once', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      world.pauseAudio();
      await frame();
      expect(backend.voice(voice).paused, isTrue);
      sourceOf(e.entity).stop(fadeOut: const Duration(seconds: 1));
      await frame();
      expect(backend.isPlaying(voice), isFalse);
      expect(sourceOf(e.entity).isPlaying, isFalse);
    });

    test('a play() starts paused and is heard on resume', () async {
      final e = world.spawn()
        ..insert(AudioSource(soundKey: 'engine', looping: true));
      await ready();
      world.pauseAudio();
      await frame();
      sourceOf(e.entity).play();
      await frame();
      expect(voiceOf(e.entity).paused, isTrue);
      world.resumeAudio();
      await frame();
      expect(voiceOf(e.entity).paused, isFalse);
    });
  });

  group('a source that is gone', () {
    setUp(setUpApp);

    test('despawning the entity stops its voice', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      world.despawn(e.entity);
      await frame();
      expect(backend.voice(voice).fade, (
        0.0,
        SpatialAudioSystem.orphanFadeOut,
      ));
      expect(backend.voice(voice).stopAfter, SpatialAudioSystem.orphanFadeOut);
      expect(world.audioState!.sourceVoices, isEmpty);
      backend.end(voice); // its scheduled stop arrives
      await frame();
      expect(world.audioState!.sounds, isEmpty);
    });

    test('removing the AudioSource stops its voice', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      world.remove<AudioSource>(e.entity);
      await frame();
      expect(backend.voice(voice).stopAfter, isNotNull);
    });

    test('replacing the AudioSource stops the old voice', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      world.insert(e.entity, AudioSource.looping(soundKey: 'engine'));
      await frame();
      expect(backend.voice(voice).stopAfter, isNotNull);
      expect(sourceOf(e.entity).isPlaying, isTrue);
    });

    test('while paused, at once', () async {
      final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      world.pauseAudio();
      await frame();
      world.despawn(e.entity);
      await frame();
      expect(backend.isPlaying(voice), isFalse);
    });

    test('a voice that ended by itself is simply forgotten', () async {
      final e = world.spawn()
        ..insert(AudioSource(soundKey: 'engine', autoPlay: true));
      await ready();
      await frame();
      final voice = sourceOf(e.entity).voice!;
      backend.end(voice);
      await frame();
      expect(sourceOf(e.entity).isPlaying, isFalse);
      expect(world.audioState!.sourceVoices, isEmpty);
    });
  });

  group('mixing', () {
    test('a source without a Transform2D plays centred at its volume '
        'times its channel volume', () async {
      setUpApp();
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(AudioListener());
      final e = world.spawn()
        ..insert(AudioSource.looping(soundKey: 'engine', volume: 0.8));
      await ready();
      await frame();
      expect(voiceOf(e.entity).volume, closeTo(0.4, 1e-9));
      expect(voiceOf(e.entity).pan, 0.0);

      world.setVolume(AudioChannel.sfx, 1.0);
      await frame();
      await frame();
      expect(voiceOf(e.entity).volume, closeTo(0.8, 1e-9));
    });

    test('a source with a Transform2D but no listener plays at its volume '
        'times its channel volume', () async {
      setUpApp();
      final e = world.spawn()
        ..insert(Transform2D.from(5000, 0))
        ..insert(AudioSource.looping(soundKey: 'engine', volume: 0.8));
      await ready();
      await frame();
      expect(voiceOf(e.entity).volume, closeTo(0.4, 1e-9));
      expect(voiceOf(e.entity).pan, 0.0);
    });

    test('a source with a Transform2D is attenuated and panned', () async {
      setUpApp();
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(AudioListener());
      final e = world.spawn()
        ..insert(Transform2D.from(550, 0))
        ..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      // Halfway between the reference (100) and max (1000) distances.
      expect(voiceOf(e.entity).volume, closeTo(0.25, 1e-9));
      expect(voiceOf(e.entity).pan, closeTo(0.55, 1e-9));
    });

    test('with spatial audio off, sources play and stop, unmixed', () async {
      setUpApp(const AudioConfig.nonSpatial());
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(AudioListener());
      final e = world.spawn()
        ..insert(Transform2D.from(550, 0))
        ..insert(AudioSource.looping(soundKey: 'engine'));
      await ready();
      await frame();
      expect(voiceOf(e.entity).volume, closeTo(0.5, 1e-9));
      expect(voiceOf(e.entity).pan, 0.0);
      sourceOf(e.entity).stop();
      await frame();
      expect(engineVoices(), isEmpty);
    });
  });

  test('sources can be stopped while only audio is pumped', () async {
    setUpApp();
    final e = world.spawn()..insert(AudioSource.looping(soundKey: 'engine'));
    await ready();
    await frame();
    sourceOf(e.entity).stop();
    await world.pumpAudio();
    expect(engineVoices(), isEmpty);
  });
}
