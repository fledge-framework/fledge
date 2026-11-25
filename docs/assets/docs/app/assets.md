# Assets

`fledge_assets` is the shared store behind textures, audio clips and tilemaps:
a per-type `Assets<T>` resource that hands out reference-counted `Handle<T>`s,
loads files asynchronously through a `Loader<T>`, and can reload them when they
change on disk during development.

```yaml
dependencies:
  fledge_assets: ^0.6.0
```

It's pure Dart (Dart 3.11+), with no Flutter dependency. You'll often use it
without adding it yourself: `RenderPlugin` inserts an `Assets<Texture>`, and
the audio and Tiled packages provide loaders for their types. Signatures are
in the [fledge_assets API reference](https://pub.dev/documentation/fledge_assets/latest/).

## Handles and the store

```dart
import 'package:fledge_assets/fledge_assets.dart';

class LevelData {
  final List<String> rows;
  LevelData(this.rows);
}

/// Serves levels from memory; a real loader reads a file or an asset bundle.
class MemoryLevelLoader implements Loader<LevelData> {
  MemoryLevelLoader(this.files);

  final Map<String, String> files;

  @override
  Future<LevelData> load(String path) async {
    final text = files[path];
    if (text == null) throw StateError('no such level: $path');
    return LevelData(text.split('\n'));
  }
}

Future<void> main() async {
  final loader = MemoryLevelLoader({'level1': '#..#\n#..#'});
  final levels = Assets<LevelData>();

  final a = levels.load('level1', loader);
  final b = levels.load('level1', loader); // same path: same entry
  print('${a.id == b.id} ${levels.refCount(a.id)}'); // true 2
  print(a.isReady); // false: the load hasn't finished

  await Future<void>.delayed(Duration.zero);
  print('${a.isReady} ${a.get()!.rows.length}'); // true 2

  final missing = levels.load('level9', loader);
  await Future<void>.delayed(Duration.zero);
  print(missing.isReady); // false, and it stays false

  b.drop();
  print(levels.refCount(a.id)); // 1
  a.drop();
  print(levels.get(a.id)); // null: the entry is gone
}
```

- **`load(path, loader)`** returns a `Handle<T>` at once and starts the load.
  `handle.get()` is `null` and `handle.isReady` is false until it finishes.
  Loading a path that's already in the store doesn't load it again: you get a
  new handle onto the same entry, and its reference count goes up.
- **`add(asset)`** stores something you already have in memory.
  **`addWithId(HandleId(n), asset)`** stores it under a fixed id; id 0 is kept
  free for such well-known entries (`fledge_render_2d` puts its 1×1
  solid-colour texture there).
- **Reference counting.** Each handle holds one reference. `clone()` returns
  a new handle and adds one; `drop()` releases this handle's reference
  (calling it twice does nothing). When the count reaches zero the entry is
  removed. Dart has no destructors, so a handle you stop using without
  `drop()` keeps its asset alive. `Assets` also has `refCount(id)`,
  `incrementRef(id)` and `decrementRef(id)` for code that manages ids
  directly.
- **`get(id)`, `ready(id)`, `all`, `findByPath(path)`** look entries up.
  Each entry is an `AssetEntry` (value, ref count, path, loader).

**Failed loads are silent.** If the loader throws, the entry stays in the
store with no value, and the handle is never ready. Log from inside your
loader (as `fledge_audio`'s `AudioClipLoader(onError:)` does) if you need to
know.

## Writing a loader

A `Loader<T>` has one method, `Future<T> load(String path)`. Loaders live
with the type they produce: `FileTextureLoader` in `fledge_render_2d`,
`AudioClipLoader` in `fledge_audio`, `TmxLoader` in `fledge_tiled`. A
file-based loader for your own type:

```dart
import 'dart:io';

import 'package:fledge_assets/fledge_assets.dart';

class Dialogue {
  final List<String> lines;
  Dialogue(this.lines);
}

class DialogueLoader implements Loader<Dialogue> {
  const DialogueLoader();

  @override
  Future<Dialogue> load(String path) async =>
      Dialogue(await File(path).readAsLines());
}
```

`dart:io` files don't exist on the web; a web build would load through
Flutter's `rootBundle` instead.

## Assets in a game

Store the `Assets<T>` as a resource, start loads at startup, and let systems
use an asset once its handle is ready. Never await a load inside a system:

<!-- snippet-setup
class Dialogue {
  final List<String> lines;
  Dialogue(this.lines);
}

class DialogueLoader implements Loader<Dialogue> {
  const DialogueLoader();

  @override
  Future<Dialogue> load(String path) async => Dialogue([path]);
}
-->

```dart
class IntroDialogue {
  Handle<Dialogue>? handle;
  bool shown = false;
}

final app = App()
  ..insertResource(Assets<Dialogue>())
  ..insertResource(IntroDialogue())
  ..addSystem(
    FunctionSystem(
      'loadIntro',
      resourceWrites: {Assets<Dialogue>, IntroDialogue},
      run: (world) {
        world.getResource<IntroDialogue>()!.handle = world
            .getResource<Assets<Dialogue>>()!
            .load('assets/intro.txt', const DialogueLoader());
      },
    ),
    schedule: Schedules.startup,
  )
  ..addSystem(
    FunctionSystem(
      'showIntro',
      resourceWrites: {IntroDialogue},
      run: (world) {
        final intro = world.getResource<IntroDialogue>()!;
        final dialogue = intro.handle?.get();
        if (dialogue == null || intro.shown) return; // not loaded yet
        intro.shown = true;
        dialogue.lines.forEach(print);
      },
    ),
  );
```

## Hot reload

During development, `AssetPlugin(enableHotReload: true)` reloads assets when
their files change:

```dart
final app = App()
  ..addPlugin(AssetPlugin(enableHotReload: true))
  ..addPlugin(RenderPlugin());

final textures = app.world.getResource<Assets<Texture>>()!;
const path = 'assets/sprites/player.png';
final player = textures.load(path, const FileTextureLoader());

// Nothing is watched until you ask:
app.world.getResource<HotReloadWatcher>()?.watch(path, textures, player.id);
```

The plugin inserts a `HotReloadWatcher` resource and adds
`HotReloadPollSystem` to `Schedules.first` (phase `FirstSets.content`; order
against it with `HotReloadPollSystem.systemName`). With
`enableHotReload: false`, the default, it adds nothing, and the asset store
works the same without the plugin.

**No asset is watched automatically**, not even by the render, audio or
Tiled plugins. Register each file:

| `HotReloadWatcher` method | Does |
|---|---|
| `watch(path, assets, id)` | When `path` changes, reload entry `id` through its loader |
| `watchWithCallback(path, callback)` | When `path` changes, run your async callback |
| `unwatch(path)` | Stop reacting to `path` |
| `dispose()` | Stop every file watcher (`AssetPlugin.cleanup` calls it) |

Each change is queued, and the poll system runs the queued reloads at the
start of the next frame. The reloaded value replaces the old one in the same
entry, so every handle sees it. Before reloading, the watcher marks the entry
dirty; Fledge doesn't consume that set, so after a tick
`assets.drainDirtyReloads()` tells you which entries were reloaded (to rebuild
anything you derived from them).

Limitations:

- **Desktop development only.** `HotReloadPollSystem` is `async` and awaits
  each reload, file I/O included, inside the frame, so a reload stalls that
  frame. That's acceptable while editing, not in a shipped game: keep
  `enableHotReload` off in release builds. Don't enable it on the web, where
  there is no file system to watch.
- A changed file matches a watched path exactly or, failing that, by file
  name alone, so two watched files with the same name in different folders
  both reload.
- Failed reloads are silent, like failed loads: the old value stays.

## See also

- [Sprites & Animation](/docs/rendering/sprites-animation) for textures
- [Audio](/docs/platform/audio)
- [Tiled Maps](/docs/gameplay/tiled)
