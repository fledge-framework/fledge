import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../assets/audio_assets.dart';
import '../config/audio_config.dart';
import '../events/audio_events.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_state.dart';

/// System that processes audio playback requests.
class AudioEventSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'AudioEventSystem',
        eventReads: {
          PlaySfxRequest,
          PlayMusicRequest,
          StopMusicRequest,
          PauseAudioRequest,
          ResumeAudioRequest,
          SetChannelVolumeRequest,
          PreloadAudioRequest,
        },
        eventWrites: {
          SfxStarted,
          MusicStarted,
          MusicChanged,
          AudioFailed,
          AudioPaused,
          AudioResumed,
          AudioAssetLoaded,
        },
        resourceReads: {AudioAssets, VolumeChannels, SpatialAudioConfig},
        resourceWrites: {AudioState},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final state = world.getResource<AudioState>();
    if (state == null || !state.isInitialized) return;

    final assets = world.getResource<AudioAssets>()!;
    final channels = world.getResource<VolumeChannels>()!;
    final soloud = state.soloud;

    // Process SFX requests
    for (final request in world.eventReader<PlaySfxRequest>().read()) {
      await _handlePlaySfx(world, request, assets, state, channels, soloud);
    }

    // Process music requests
    for (final request in world.eventReader<PlayMusicRequest>().read()) {
      await _handlePlayMusic(world, request, assets, state, channels, soloud);
    }

    // Process stop music requests
    for (final request in world.eventReader<StopMusicRequest>().read()) {
      _handleStopMusic(world, request, state, soloud);
    }

    // Process pause/resume
    for (final _ in world.eventReader<PauseAudioRequest>().read()) {
      _handlePause(world, state, soloud);
    }
    for (final _ in world.eventReader<ResumeAudioRequest>().read()) {
      _handleResume(world, state, soloud);
    }

    // Process volume changes
    for (final request in world.eventReader<SetChannelVolumeRequest>().read()) {
      _handleVolumeChange(request, channels);
    }

    // Process preload requests
    for (final request in world.eventReader<PreloadAudioRequest>().read()) {
      await _handlePreload(world, request, assets);
    }
  }

  Future<void> _handlePlaySfx(
    World world,
    PlaySfxRequest request,
    AudioAssets assets,
    AudioState state,
    VolumeChannels channels,
    SoLoud soloud,
  ) async {
    final sound = assets.getSound(request.soundKey);
    if (sound == null) {
      world.eventWriter<AudioFailed>().send(
            AudioFailed(request.soundKey, 'Sound not loaded'),
          );
      return;
    }

    final effectiveVolume =
        channels.getEffectiveVolume(AudioChannel.sfx) * request.volume;

    final handle = await soloud.play(
      sound.source,
      volume: effectiveVolume,
    );

    // Apply playback speed
    if (request.playbackSpeed != 1.0) {
      soloud.setRelativePlaySpeed(handle, request.playbackSpeed);
    }

    state.registerSound(handle);
    world.eventWriter<SfxStarted>().send(SfxStarted(request.soundKey, handle));
  }

  Future<void> _handlePlayMusic(
    World world,
    PlayMusicRequest request,
    AudioAssets assets,
    AudioState state,
    VolumeChannels channels,
    SoLoud soloud,
  ) async {
    final music = assets.getMusic(request.musicKey);
    if (music == null) {
      world.eventWriter<AudioFailed>().send(
            AudioFailed(request.musicKey, 'Music not loaded'),
          );
      return;
    }

    final effectiveVolume =
        channels.getEffectiveVolume(AudioChannel.music) * request.volume;

    // Handle crossfade if requested
    if (request.crossfadeDuration != null && state.currentMusicHandle != null) {
      state.fadingOutMusicHandle = state.currentMusicHandle;
      state.crossfadeDuration = request.crossfadeDuration;
      state.crossfadeElapsed = 0.0;
      state.crossfadeTargetVolume = effectiveVolume;
    } else if (state.currentMusicHandle != null) {
      // Stop current music immediately
      soloud.stop(state.currentMusicHandle!);
    }

    final handle = await soloud.play(
      music.source,
      volume: request.crossfadeDuration != null ? 0.0 : effectiveVolume,
      looping: request.loop,
    );

    if (request.startPosition > 0) {
      final positionDuration = Duration(
        milliseconds: (request.startPosition * 1000).round(),
      );
      soloud.seek(handle, positionDuration);
    }

    final previousKey = state.currentMusicKey;
    state.currentMusicHandle = handle;
    state.currentMusicKey = request.musicKey;

    world.eventWriter<MusicStarted>().send(MusicStarted(request.musicKey));
    if (previousKey != null && request.crossfadeDuration == null) {
      world.eventWriter<MusicChanged>().send(
            MusicChanged(previousKey: previousKey, newKey: request.musicKey),
          );
    }
  }

  void _handleStopMusic(
    World world,
    StopMusicRequest request,
    AudioState state,
    SoLoud soloud,
  ) {
    if (state.currentMusicHandle == null) return;

    if (request.fadeOutDuration != null) {
      // Set up fade out
      state.fadingOutMusicHandle = state.currentMusicHandle;
      state.crossfadeDuration = request.fadeOutDuration;
      state.crossfadeElapsed = 0.0;
      state.currentMusicHandle = null;
      state.currentMusicKey = null;
    } else {
      // Stop immediately
      soloud.stop(state.currentMusicHandle!);
      state.currentMusicHandle = null;
      state.currentMusicKey = null;
    }
  }

  void _handlePause(World world, AudioState state, SoLoud soloud) {
    if (state.isPaused) return;

    // Pause all active sounds
    for (final handle in state.activeSounds) {
      if (soloud.getIsValidVoiceHandle(handle)) {
        soloud.setPause(handle, true);
      }
    }
    // Pause music
    if (state.currentMusicHandle != null &&
        soloud.getIsValidVoiceHandle(state.currentMusicHandle!)) {
      soloud.setPause(state.currentMusicHandle!, true);
    }
    if (state.fadingOutMusicHandle != null &&
        soloud.getIsValidVoiceHandle(state.fadingOutMusicHandle!)) {
      soloud.setPause(state.fadingOutMusicHandle!, true);
    }

    state.isPaused = true;
    world.eventWriter<AudioPaused>().send(const AudioPaused());
  }

  void _handleResume(World world, AudioState state, SoLoud soloud) {
    if (!state.isPaused) return;

    // Resume all active sounds
    for (final handle in state.activeSounds) {
      if (soloud.getIsValidVoiceHandle(handle)) {
        soloud.setPause(handle, false);
      }
    }
    // Resume music
    if (state.currentMusicHandle != null &&
        soloud.getIsValidVoiceHandle(state.currentMusicHandle!)) {
      soloud.setPause(state.currentMusicHandle!, false);
    }
    if (state.fadingOutMusicHandle != null &&
        soloud.getIsValidVoiceHandle(state.fadingOutMusicHandle!)) {
      soloud.setPause(state.fadingOutMusicHandle!, false);
    }

    state.isPaused = false;
    state.pausedByFocusLoss = false;
    world.eventWriter<AudioResumed>().send(const AudioResumed());
  }

  void _handleVolumeChange(
    SetChannelVolumeRequest request,
    VolumeChannels channels,
  ) {
    // TODO: Implement fade if fadeDuration is set
    channels.setVolume(request.channel, request.volume);
  }

  Future<void> _handlePreload(
    World world,
    PreloadAudioRequest request,
    AudioAssets assets,
  ) async {
    try {
      if (request.isMusic) {
        await assets.loadMusic(request.key, request.assetPath);
      } else {
        await assets.loadSound(request.key, request.assetPath);
      }
      world.eventWriter<AudioAssetLoaded>().send(
            AudioAssetLoaded(request.key, isMusic: request.isMusic),
          );
    } catch (e) {
      world.eventWriter<AudioFailed>().send(
            AudioFailed(request.key, e.toString()),
          );
    }
  }
}
