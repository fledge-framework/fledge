import 'package:flutter_soloud/flutter_soloud.dart';

/// Resource managing loaded audio assets.
///
/// Similar to TilemapAssets pattern - stores loaded audio by key.
///
/// ```dart
/// final assets = world.getResource<AudioAssets>()!;
/// await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
/// await assets.loadMusic('theme', 'assets/music/theme.mp3');
///
/// // Use later
/// world.playSfx('explosion');
/// world.playMusic('theme');
/// ```
class AudioAssets {
  /// The underlying SoLoud instance.
  final SoLoud _soloud;

  /// Loaded sound effects by key.
  final Map<String, LoadedSound> _sounds = {};

  /// Loaded music tracks by key.
  final Map<String, LoadedMusic> _music = {};

  AudioAssets(this._soloud);

  /// Load a sound effect from an asset path.
  ///
  /// ```dart
  /// await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
  /// ```
  Future<LoadedSound> loadSound(String key, String assetPath) async {
    final source = await _soloud.loadAsset(assetPath);
    final loaded = LoadedSound(key: key, source: source, assetPath: assetPath);
    _sounds[key] = loaded;
    return loaded;
  }

  /// Load a music track from an asset path.
  ///
  /// ```dart
  /// await assets.loadMusic('theme', 'assets/music/theme.mp3');
  /// ```
  Future<LoadedMusic> loadMusic(String key, String assetPath) async {
    final source = await _soloud.loadAsset(assetPath);
    final loaded = LoadedMusic(key: key, source: source, assetPath: assetPath);
    _music[key] = loaded;
    return loaded;
  }

  /// Get a loaded sound by key.
  LoadedSound? getSound(String key) => _sounds[key];

  /// Get a loaded music track by key.
  LoadedMusic? getMusic(String key) => _music[key];

  /// Check if a sound is loaded.
  bool hasSound(String key) => _sounds.containsKey(key);

  /// Check if a music track is loaded.
  bool hasMusic(String key) => _music.containsKey(key);

  /// Unload a sound and free resources.
  void unloadSound(String key) {
    final sound = _sounds.remove(key);
    if (sound != null) {
      _soloud.disposeSource(sound.source);
    }
  }

  /// Unload a music track and free resources.
  void unloadMusic(String key) {
    final music = _music.remove(key);
    if (music != null) {
      _soloud.disposeSource(music.source);
    }
  }

  /// Unload all assets.
  void unloadAll() {
    for (final sound in _sounds.values) {
      _soloud.disposeSource(sound.source);
    }
    for (final music in _music.values) {
      _soloud.disposeSource(music.source);
    }
    _sounds.clear();
    _music.clear();
  }

  /// All loaded sound keys.
  Iterable<String> get soundKeys => _sounds.keys;

  /// All loaded music keys.
  Iterable<String> get musicKeys => _music.keys;
}

/// A loaded sound effect.
class LoadedSound {
  /// The asset key.
  final String key;

  /// The SoLoud audio source.
  final AudioSource source;

  /// Original asset path (for debugging/reloading).
  final String assetPath;

  const LoadedSound({
    required this.key,
    required this.source,
    required this.assetPath,
  });
}

/// A loaded music track.
class LoadedMusic {
  /// The asset key.
  final String key;

  /// The SoLoud audio source.
  final AudioSource source;

  /// Original asset path (for debugging/reloading).
  final String assetPath;

  const LoadedMusic({
    required this.key,
    required this.source,
    required this.assetPath,
  });
}
