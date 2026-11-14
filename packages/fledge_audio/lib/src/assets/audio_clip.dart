import 'package:fledge_assets/fledge_assets.dart';

import '../backend/audio_backend.dart';

/// A loaded audio file, ready to play: the value stored in
/// `Assets<AudioClip>`.
class AudioClip {
  /// The engine's source, as [AudioBackend.load] returned it.
  final Object source;

  /// The asset it was loaded from.
  final String assetPath;

  /// Whether it decodes while playing (music) rather than sitting decoded
  /// in memory (sound effects).
  final bool streamed;

  const AudioClip({
    required this.source,
    required this.assetPath,
    this.streamed = false,
  });
}

/// Loads [AudioClip]s through an [AudioBackend], for `Assets<AudioClip>`.
class AudioClipLoader implements Loader<AudioClip> {
  const AudioClipLoader(this.backend, {this.stream = false, this.onError});

  final AudioBackend backend;

  /// Decode while playing (music) instead of all at once.
  final bool stream;

  /// Told why a load failed (`Assets` itself keeps failures silent).
  final void Function(Object error)? onError;

  @override
  Future<AudioClip> load(String path) async {
    try {
      final source = await backend.load(path, stream: stream);
      return AudioClip(source: source, assetPath: path, streamed: stream);
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }
}
