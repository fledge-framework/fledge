import 'package:fledge_assets/fledge_assets.dart';

import '../assets/audio_clip.dart';
import '../backend/audio_backend.dart';

/// Whether a key names a sound effect or a music track.
enum AudioKind {
  /// Short and frequent: decoded into memory, for instant starts.
  sound,

  /// Long: streamed (decoded while it plays), so it never sits whole in
  /// memory.
  music,
}

/// Where a key's clip is in loading.
enum AudioClipStatus {
  /// Registered; loading starts once the audio engine is up.
  waiting,

  /// Being read and decoded in the background.
  loading,

  /// Ready to play.
  ready,

  /// Couldn't be loaded; see [AudioLibrary.errorOf].
  failed,
}

class _Entry {
  _Entry(this.path, this.kind);

  final String path;
  final AudioKind kind;
  AudioClipStatus status = AudioClipStatus.waiting;
  Handle<AudioClip>? handle;
  String? error;
}

/// The game's sounds and music by key: the resource `playSfx` and
/// `playMusic` look keys up in.
///
/// Register clips at any time, before the audio engine has started too
/// (`world.loadSound` / `world.loadMusic`). Loading never blocks a frame:
/// `AudioEventSystem` starts each load in the background, through
/// `Assets<AudioClip>`, once the engine is up, and sends `AudioAssetLoaded`
/// (or `AudioFailed`) when it settles. Music asked for before its clip is
/// ready starts as soon as it is.
class AudioLibrary {
  final Map<String, _Entry> _entries = {};

  /// Registers the sound effect at [assetPath] under [key].
  void addSound(String key, String assetPath) =>
      _add(key, assetPath, AudioKind.sound);

  /// Registers the music track at [assetPath] under [key].
  void addMusic(String key, String assetPath) =>
      _add(key, assetPath, AudioKind.music);

  void _add(String key, String path, AudioKind kind) {
    final existing = _entries[key];
    if (existing != null && existing.path == path && existing.kind == kind) {
      return;
    }
    if (existing != null) {
      throw StateError(
        'AudioLibrary: "$key" is already ${existing.path} '
        '(${existing.kind.name}); remove it first',
      );
    }
    _entries[key] = _Entry(path, kind);
  }

  /// Every registered key.
  Iterable<String> get keys => _entries.keys;

  bool contains(String key) => _entries.containsKey(key);

  AudioKind? kindOf(String key) => _entries[key]?.kind;

  /// Where [key]'s clip is in loading, or null if it isn't registered.
  AudioClipStatus? statusOf(String key) => _entries[key]?.status;

  /// Why [key] failed to load.
  String? errorOf(String key) => _entries[key]?.error;

  /// [key]'s clip, once it's ready.
  AudioClip? clipOf(String key) {
    final entry = _entries[key];
    return entry?.status == AudioClipStatus.ready ? entry!.handle!.get() : null;
  }

  /// Whether every registered clip has settled (ready or failed): a
  /// loading screen can wait on this.
  bool get settled => _entries.values.every(
    (e) =>
        e.status == AudioClipStatus.ready || e.status == AudioClipStatus.failed,
  );

  /// Unregisters [key] and frees its clip.
  void remove(String key, AudioBackend? backend) {
    final entry = _entries.remove(key);
    final clip = entry?.handle?.get();
    if (clip != null) backend?.unload(clip.source);
    entry?.handle?.drop();
  }

  /// Starts loading every waiting clip. Called by `AudioEventSystem` once
  /// the engine is up; never waits.
  void startLoads(Assets<AudioClip> assets, AudioBackend backend) {
    for (final entry in _entries.values) {
      if (entry.status != AudioClipStatus.waiting) continue;
      entry.status = AudioClipStatus.loading;
      entry.handle = assets.load(
        entry.path,
        AudioClipLoader(
          backend,
          stream: entry.kind == AudioKind.music,
          onError: (e) {
            entry.status = AudioClipStatus.failed;
            entry.error = '$e';
          },
        ),
        debugLabel: entry.path,
      );
    }
  }

  /// Moves loads that have finished to ready, returning their keys
  /// (`AudioEventSystem` announces them), and the keys that failed.
  ({List<String> ready, List<String> failed}) collectSettled() {
    final ready = <String>[];
    final failed = <String>[];
    for (final MapEntry(:key, value: entry) in _entries.entries) {
      if (entry.status == AudioClipStatus.loading &&
          (entry.handle?.isReady ?? false)) {
        entry.status = AudioClipStatus.ready;
        ready.add(key);
      } else if (entry.status == AudioClipStatus.failed &&
          entry.handle != null) {
        // Report once: forget the handle of a failed load.
        entry.handle!.drop();
        entry.handle = null;
        failed.add(key);
      }
    }
    return (ready: ready, failed: failed);
  }
}
