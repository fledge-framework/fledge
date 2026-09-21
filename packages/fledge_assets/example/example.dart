import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

/// A toy [Loader] — real games plug in a `TextureLoader`,
/// `AudioClipLoader`, `TilemapLoader`, etc. from their owning package.
class StringLoader implements Loader<String> {
  @override
  Future<String> load(String path) async => 'contents-of:$path';
}

/// Minimal fledge_assets example.
///
/// Wires the optional [AssetPlugin], installs a per-type [Assets]
/// store, and walks the two ways an entry lands in the store:
///
/// - `add` — for something you already have in memory.
/// - `load` — for an async file-backed load through a [Loader].
///
/// A [Handle] is a ref-counted smart pointer; cloning bumps the
/// count, [Handle.drop] releases one share, and the underlying entry
/// is evicted the moment its last live handle drops.
void main() async {
  final app = App()..addPlugin(AssetPlugin());

  // Each asset type has its own store. Downstream plugins install
  // their own (`Assets<Texture>`, `Assets<AudioClip>`, ...); games
  // and tests can build ad-hoc ones like this.
  final store = Assets<String>();
  app.insertResource(store);

  // In-memory asset. Refcount starts at 1.
  final greeting = store.add('hello, world', debugLabel: 'greeting');
  assert(greeting.get() == 'hello, world');

  // Async load. `get()` returns null until the loader resolves.
  final page = store.load('README.md', StringLoader(), debugLabel: 'page');
  await Future<void>.delayed(Duration.zero);
  assert(page.isReady);

  // Cloning bumps the refcount; the entry is freed only when the
  // last handle drops.
  final shared = page.clone();
  page.drop();
  assert(store.get(shared.id) != null);
  shared.drop();
  assert(store.get(shared.id) == null);

  greeting.drop();
  await app.tick();
}
