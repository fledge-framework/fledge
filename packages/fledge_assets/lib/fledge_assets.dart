/// Ref-counted asset management for the Fledge ECS game framework.
///
/// This library provides the shared primitives that the render, audio,
/// and Tiled plugins use to load, share, and unload assets:
///
/// - [HandleId] / [Handle] — smart-pointer references into an [Assets]
///   store. Cloning bumps a reference count; [Handle.drop] releases
///   it, and the last drop removes the entry.
/// - [Assets] — a per-type resource that stores loaded assets, tracks
///   their reference counts, and knows how to reload each one from
///   its original path.
/// - [Loader] — the interface asset-owning packages implement to
///   decode bytes from disk into their domain-specific type
///   (`Texture`, `AudioClip`, `Tilemap`, ...).
/// - [AssetPlugin] — an optional plugin that gates the [HotReloadWatcher]
///   + [HotReloadPollSystem] pair for native builds. The core store is
///   usable without it.
///
/// The core is intentionally pure Dart with no Flutter dependency:
/// every asset type belongs to the package that owns it.
library;

export 'src/asset_plugin.dart';
export 'src/assets.dart' show Assets, AssetEntry;
export 'src/handle.dart' show Handle, HandleId;
export 'src/hot_reload.dart' show HotReloadPollSystem, HotReloadWatcher;
export 'src/loader.dart' show Loader;
