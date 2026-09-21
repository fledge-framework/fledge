# Assets

The `fledge_assets` package provides ref-counted asset management shared by the render, audio, and Tiled plugins. It defines the primitives every asset-owning plugin builds on: `HandleId`, `Handle<T>`, `Assets<T>`, and `Loader<T>`.

The core is **pure Dart** — no Flutter dependency. Each asset-owning package (`fledge_render_2d`, `fledge_audio`, `fledge_tiled`, ...) supplies its own concrete `T` and its own `Loader<T>`.

## Installation

```yaml
dependencies:
  fledge_assets: ^0.1.0
```

Most users don't depend on `fledge_assets` directly — the render, audio, and Tiled packages re-export the primitives they need. Depend on it explicitly only when you're writing a custom asset type of your own, or when you want hot reload.

## Quick Start

```dart
import 'package:fledge_assets/fledge_assets.dart';

// A per-type asset store — typically inserted as an ECS resource by
// the owning plugin (RenderPlugin, AudioPlugin, TiledPlugin).
final assets = Assets<Texture>();

// Register an asset you already have in memory.
final handle = assets.add(myTexture);

// Or load one asynchronously via a loader.
final handle2 = assets.load('assets/sprites/player.png', FileTextureLoader());
// handle2.get() returns null until the async load completes.

// Share and release.
final shared = handle.clone();  // refcount++
handle.drop();                  // refcount--
// Entry still alive because `shared` holds a reference.
shared.drop();
// Entry dropped, memory freed.
```

## Core concepts

### HandleId

A lightweight identifier for an asset entry:

```dart
final id = HandleId(42, debugLabel: 'player.png');
```

Two `HandleId`s are equal iff their numeric `id`s match. The `debugLabel` is diagnostic-only — it is preserved through reloads to keep hot-reload logs readable, but it is **not** part of equality.

### Handle&lt;T&gt;

A smart-pointer wrapper around a `HandleId` that owns a share of the entry's reference count.

| Operation | Effect |
|-----------|--------|
| `handle.clone()` | Increments the refcount, returns a new `Handle` for the same id. |
| `handle.drop()` | Decrements the refcount. If it reaches zero, the entry (and its asset) is removed from the store. |
| `handle.get()` | Returns the underlying `T`, or `null` while an async load is still running. |

**Important**: because Dart has no destructors, going out of scope does **not** decrement the refcount. Code that stops using a handle must call `drop()` explicitly, or the entry leaks. This matches Bevy's convention.

### Assets&lt;T&gt;

A per-type resource that stores loaded assets, tracks their reference counts, and knows how to reload them from their original path.

```dart
// Register an asset already in memory.
final h1 = assets.add(myTexture, debugLabel: 'player');

// Async load — dedupes by path (a second load of the same path returns
// a fresh handle to the existing entry, incrementing the refcount).
final h2 = assets.load('assets/sprites/enemy.png', FileTextureLoader());
final h3 = assets.load('assets/sprites/enemy.png', FileTextureLoader());
// h2 and h3 refer to the SAME entry; refcount is 2.

// Look up by id.
final loaded = assets.get(h1.id);           // Texture? — null while loading

// Force a reload from disk (called by the hot-reload poll system).
await assets.reload(h1.id);
```

Reserved slot pattern — for well-known entries such as a 1×1 solid-color texture:

```dart
const kSolidColorTextureId = HandleId(0, debugLabel: 'solid_color_1x1');
assets.addWithId(kSolidColorTextureId, solidWhite);
```

### Loader&lt;T&gt;

The interface asset-owning packages implement to decode bytes from disk into their domain type:

```dart
abstract class Loader<T> {
  Future<T> load(String path);
}
```

Loaders live in the package that owns the asset type — `FileTextureLoader` in `fledge_render_2d`, `AudioClipLoader` in `fledge_audio`, and so on — so the pure-Dart `fledge_assets` core stays free of platform decoders.

## AssetPlugin and hot reload

`AssetPlugin` is optional. It does **not** insert any `Assets<T>` resources itself — each downstream plugin owns the concrete type it needs. `AssetPlugin` exists to gate the [hot-reload watcher](https://pub.dev/packages/watcher) + poll system.

```dart
final app = App()
  ..addPlugin(AssetPlugin(enableHotReload: true))  // dev builds only
  ..addPlugin(RenderPlugin())
  ..addPlugin(AudioPlugin());
```

When hot reload is on, file-change events on paths passed to `Assets<T>.load` trigger `Assets<T>.reload(id)` on the next tick — the texture / audio clip / tilemap swaps in without restarting the app.

**Platform note**: hot reload is a native-only convenience. On web the underlying `package:watcher` implementation is a no-op, so `watch(...)` calls become no-ops as well. This matches Fledge's desktop-primary stance. Production builds should leave `enableHotReload` off.

## Writing a custom asset type

Say your game has a `LevelScript` type loaded from JSON files. To make it a first-class Fledge asset:

```dart
// 1. Define a loader.
class LevelScriptLoader implements Loader<LevelScript> {
  @override
  Future<LevelScript> load(String path) async {
    final content = await File(path).readAsString();
    return LevelScript.fromJson(jsonDecode(content));
  }
}

// 2. Own the store — usually as an ECS resource inserted by a plugin.
class LevelPlugin implements Plugin {
  @override
  void build(App app) {
    app.insertResource(Assets<LevelScript>());
  }
}

// 3. Use it.
final assets = world.getResource<Assets<LevelScript>>()!;
final level = assets.load('assets/levels/1.json', LevelScriptLoader());
```

## Design notes

- **Why refcounts, not GC?** Dart has no destructors, so an asset system relying on unreachability would leak until the next full sweep. Explicit refcounts give games predictable free-on-last-drop semantics — critical for large texture sets.
- **Why per-type stores?** A single `Assets<Object>` would work but would force every consumer to downcast. Per-type stores let `Assets<Texture>.get(id)` return `Texture?` without a cast, and let downstream plugins declare their reads/writes on the concrete store.
- **Why not tie handles to lifetimes automatically?** Bevy uses Rust's ownership model for this and Fledge cannot. Being explicit means bugs are visible (an entry that never drops shows up in a hot-reload log), rather than hidden inside a finalizer that runs at an unpredictable time.

## Resources reference

| Resource | Description |
|----------|-------------|
| `Assets<T>` | Per-type store. Inserted by the owning plugin (RenderPlugin, AudioPlugin, ...). |
| `HotReloadWatcher` | File-system watcher, inserted by `AssetPlugin(enableHotReload: true)`. |

## Systems reference

| System | Schedule | Description |
|--------|----------|-------------|
| `HotReloadPollSystem` | `Schedules.first` | Drains pending reload events and calls `Assets<T>.reload` for each dirty id. Only added when `enableHotReload: true`. |

## See also

- [2D Rendering](/docs/plugins/render) — uses `Assets<Texture>`.
- [Audio](/docs/plugins/audio) — uses `Assets<AudioClip>`.
- [Tiled Tilemaps](/docs/plugins/tiled) — uses `Assets<TilemapAsset>` and `Assets<TilesetAsset>`.
