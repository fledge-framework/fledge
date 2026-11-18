import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

import '../assets/audio_clip.dart';
import '../backend/audio_backend.dart';
import '../components/audio_listener.dart';
import '../config/audio_config.dart';
import '../events/audio_events.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_library.dart';
import '../resources/audio_state.dart';
import 'audio_init_system.dart';
import 'spatial_audio_system.dart';

/// Carries out audio requests, and drives clip loading.
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`, after
/// [AudioInitSystem]. Every frame it reads every request, so none expire
/// unread while the engine starts:
///
/// - Channel volume, pause and resume apply at once (before the engine is
///   up too).
/// - Music waits until the engine is up and its clip is loaded; only the
///   latest music request counts.
/// - A sound effect plays if its clip is ready; otherwise it is skipped
///   with an [AudioFailed] (a late sound effect would be wrong).
///
/// Once the engine is up it starts loading every registered clip in the
/// background (never waiting on one) and announces each as it lands
/// ([AudioAssetLoaded], or [AudioFailed]).
class AudioEventSystem implements System {
  /// The `SystemMeta.name` of [AudioEventSystem].
  static const String systemName = 'AudioEventSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    sets: const [FirstSets.platform],
    after: const [AudioInitSystem.systemName],
    reads: {ComponentId.of<AudioListener>(), ComponentId.of<Transform2D>()},
    eventReads: const {
      PlaySfxRequest,
      PlayMusicRequest,
      StopMusicRequest,
      PauseAudioRequest,
      ResumeAudioRequest,
      SetChannelVolumeRequest,
    },
    eventWrites: const {
      SfxStarted,
      MusicStarted,
      MusicChanged,
      AudioFailed,
      AudioPaused,
      AudioResumed,
      AudioAssetLoaded,
    },
    resourceReads: const {SpatialAudioConfig},
    resourceWrites: const {
      AudioState,
      AudioLibrary,
      VolumeChannels,
      Assets<AudioClip>,
    },
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final state = world.getResource<AudioState>();
    final library = world.getResource<AudioLibrary>();
    final channels = world.getResource<VolumeChannels>();
    if (state == null || library == null || channels == null) return;
    final failed = world.eventWriter<AudioFailed>();

    // Requests that need no engine.
    for (final request in world.eventReader<SetChannelVolumeRequest>().read()) {
      final fade = request.fadeDuration;
      if (fade != null) {
        channels.fadeTo(request.channel, request.volume, fade);
      } else {
        channels.setVolume(request.channel, request.volume);
      }
    }
    for (final _ in world.eventReader<PauseAudioRequest>().read()) {
      if (state.pauseAll()) {
        world.eventWriter<AudioPaused>().send(const AudioPaused());
      }
    }
    for (final _ in world.eventReader<ResumeAudioRequest>().read()) {
      if (state.resumeAll()) {
        world.eventWriter<AudioResumed>().send(const AudioResumed());
      }
    }
    // Music: the latest request waits until it can be carried out.
    for (final request in world.eventReader<PlayMusicRequest>().read()) {
      state.pendingMusic = request;
    }
    for (final request in world.eventReader<StopMusicRequest>().read()) {
      state.pendingMusic = request;
    }
    final sfx = world.eventReader<PlaySfxRequest>().read().toList();

    if (!state.isInitialized) {
      for (final request in sfx) {
        failed.send(AudioFailed(request.soundKey, 'audio has not started'));
      }
      return;
    }

    // Loading.
    final assets = world.getResource<Assets<AudioClip>>();
    if (assets != null) library.startLoads(assets, state.backend);
    final settled = library.collectSettled();
    for (final key in settled.ready) {
      world.eventWriter<AudioAssetLoaded>().send(
        AudioAssetLoaded(key, isMusic: library.kindOf(key) == AudioKind.music),
      );
    }
    for (final key in settled.failed) {
      failed.send(AudioFailed(key, library.errorOf(key) ?? 'failed to load'));
    }

    _music(world, state, library, channels);

    for (final request in sfx) {
      _playSfx(world, request, state, library, channels);
    }
  }

  void _music(
    World world,
    AudioState state,
    AudioLibrary library,
    VolumeChannels channels,
  ) {
    switch (state.pendingMusic) {
      case null:
        return;
      case StopMusicRequest(:final fadeOutDuration):
        state.pendingMusic = null;
        final voice = state.currentMusicVoice;
        if (voice == null) return;
        _fadeOut(state, voice, fadeOutDuration);
        state
          ..currentMusicVoice = null
          ..currentMusicKey = null
          ..musicFadeRemaining = 0;
      case final PlayMusicRequest request:
        final key = request.musicKey;
        final status = library.statusOf(key);
        if (status == AudioClipStatus.waiting ||
            status == AudioClipStatus.loading) {
          return; // Still loading: keep waiting.
        }
        state.pendingMusic = null;
        final clip = library.clipOf(key);
        if (clip == null) {
          world.eventWriter<AudioFailed>().send(
            AudioFailed(
              key,
              status == null
                  ? 'no such music in the AudioLibrary'
                  : library.errorOf(key) ?? 'failed to load',
            ),
          );
          return;
        }
        _startMusic(world, state, request, clip, channels);
    }
  }

  void _fadeOut(AudioState state, AudioVoice voice, Duration? fade) {
    final backend = state.backend;
    if (fade == null || fade <= Duration.zero) {
      backend.stop(voice);
      return;
    }
    // From wherever it is now, on the audio thread; it stops itself.
    backend
      ..fadeVolume(voice, 0, fade)
      ..stopAfter(voice, fade);
    state.fadingOut.add(voice);
  }

  void _startMusic(
    World world,
    AudioState state,
    PlayMusicRequest request,
    AudioClip clip,
    VolumeChannels channels,
  ) {
    final backend = state.backend;
    final channel = channels.getEffectiveVolume(AudioChannel.music);
    final target = request.volume * channel;
    final fade = request.crossfadeDuration;
    final fading = fade != null && fade > Duration.zero;
    final previous = state.currentMusicKey;
    final current = state.currentMusicVoice;

    if (previous == request.musicKey &&
        current != null &&
        backend.isPlaying(current) &&
        !request.restart) {
      // Already playing: only the volume can change.
      if (request.volume != state.musicVolume) {
        state.musicVolume = request.volume;
        backend.fadeVolume(
          current,
          target,
          fading ? fade : const Duration(milliseconds: 50),
        );
      }
      return;
    }

    if (current != null) _fadeOut(state, current, fade);

    final voice = backend.play(
      clip.source,
      volume: fading ? 0.0 : target,
      looping: request.loop,
      paused: state.isPaused,
    );
    if (request.startPosition > 0) {
      backend.seek(
        voice,
        Duration(microseconds: (request.startPosition * 1e6).round()),
      );
    }
    if (fading) backend.fadeVolume(voice, target, fade);
    state
      ..currentMusicKey = request.musicKey
      ..currentMusicVoice = voice
      ..musicVolume = request.volume
      ..musicLooping = request.loop
      ..musicFadeRemaining = fading ? fade.inMicroseconds / 1e6 : 0
      ..appliedMusicChannel = channel;

    world.eventWriter<MusicStarted>().send(MusicStarted(request.musicKey));
    if (previous != null) {
      world.eventWriter<MusicChanged>().send(
        MusicChanged(previousKey: previous, newKey: request.musicKey),
      );
    }
  }

  void _playSfx(
    World world,
    PlaySfxRequest request,
    AudioState state,
    AudioLibrary library,
    VolumeChannels channels,
  ) {
    final key = request.soundKey;
    final failed = world.eventWriter<AudioFailed>();
    if (state.isPaused) {
      failed.send(AudioFailed(key, 'audio is paused'));
      return;
    }
    final clip = library.clipOf(key);
    if (clip == null) {
      final status = library.statusOf(key);
      failed.send(
        AudioFailed(key, switch (status) {
          null => 'no such sound in the AudioLibrary',
          AudioClipStatus.failed => library.errorOf(key) ?? 'failed to load',
          _ => 'still loading',
        }),
      );
      return;
    }
    var volume = request.volume * channels.getEffectiveVolume(AudioChannel.sfx);
    var pan = 0.0;
    final position = request.position;
    final config = world.getResource<SpatialAudioConfig>();
    if (position != null && config != null && config.enabled) {
      final listener = SpatialAudioSystem.listenerPosition(world);
      if (listener != null) {
        final (attenuation, p) = SpatialAudioSystem.mix(
          listener,
          position,
          config,
        );
        volume *= attenuation;
        pan = p;
      }
    }
    final voice = state.backend.play(
      clip.source,
      volume: volume,
      pan: pan,
      speed: request.playbackSpeed,
    );
    state.sounds[voice] = key;
    world.eventWriter<SfxStarted>().send(SfxStarted(key, voice));
  }
}
