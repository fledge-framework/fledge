/// Loads asset data of type [T] from a path.
///
/// Implementations decode file bytes into the domain-specific asset
/// type — `Texture`, `AudioClip`, `Tilemap`, and so on — and return
/// them asynchronously.
///
/// Loaders live in the package that owns the asset type:
/// `FileTextureLoader` belongs to `fledge_render_2d`,
/// `AudioClipLoader` to `fledge_audio`, and so on. This lets the
/// pure-Dart `fledge_assets` core stay free of Flutter or
/// platform-specific decoders.
abstract class Loader<T> {
  /// Load an asset from [path]. Called by [Assets.load] on the first
  /// registration and by [Assets.reload] when a hot-reload event fires
  /// on the same path.
  Future<T> load(String path);
}
