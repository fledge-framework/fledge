import 'dart:async';
import 'dart:io';

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

/// File-backed loader that just reads a text file's contents. Real
/// texture / audio loaders live in the packages that own those types;
/// this stripped-down version keeps the hot-reload test hermetic.
class _FileTextLoader implements Loader<String> {
  @override
  Future<String> load(String path) => File(path).readAsString();
}

/// Loader whose every call waits on a completer the test controls.
class _ManualLoader implements Loader<String> {
  final List<Completer<String>> calls = [];

  @override
  Future<String> load(String path) {
    final c = Completer<String>();
    calls.add(c);
    return c.future;
  }
}

/// Lets pending microtasks and zero-delay timers run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // Filesystem watching on macOS/Linux CI is racy — `package:watcher`
  // can miss events under sandboxes. We drive the watcher directly via
  // its debug hook, which is what a real event would trigger.
  group('HotReloadWatcher + HotReloadPollSystem', () {
    late Directory tempDir;
    late File file;
    late Assets<String> assets;
    late HotReloadWatcher watcher;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fledge_assets_hr');
      file = File('${tempDir.path}${Platform.pathSeparator}greeting.txt');
      await file.writeAsString('hello');
      assets = Assets<String>();
      watcher = HotReloadWatcher();
    });

    tearDown(() async {
      await watcher.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('poll system reloads the asset when the file changes', () async {
      final handle = assets.load(file.path, _FileTextLoader());
      // Wait for initial async load.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(handle.get(), 'hello');

      watcher.watch(file.path, assets, handle.id);

      // Change the file on disk.
      await file.writeAsString('world');

      // Simulate the watcher's event handler firing. In production
      // `package:watcher` calls this from its native event stream;
      // in tests we trigger it directly so we don't race the OS.
      watcher.debugFireChange(file.path);

      // The poll system starts the reload; the value lands when the
      // loader completes.
      HotReloadPollSystem(watcher).run(World());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        handle.get(),
        'world',
        reason: 'reload should have been driven through the poll system',
      );
    });

    test('a file change marks the entry dirty until the poll drains it', () {
      final handle = assets.load(file.path, _ManualLoader());
      watcher.watch(file.path, assets, handle.id);

      watcher.debugFireChange(file.path);
      HotReloadPollSystem(watcher).run(World());

      expect(
        assets.drainDirtyReloads(),
        isEmpty,
        reason: 'the poll system drains the dirty set',
      );
    });
  });

  group('HotReloadPollSystem', () {
    test('run is synchronous and starts reloads without awaiting', () async {
      final loader = _ManualLoader();
      final assets = Assets<String>();
      final handle = assets.load('a.txt', loader);
      loader.calls.single.complete('v1');
      await _settle();

      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      watcher.watch('a.txt', assets, handle.id);
      watcher.debugFireChange('a.txt');

      final poll = HotReloadPollSystem(watcher);
      // Synchronous: returns no future for the tick to await.
      final dynamic result = (poll as dynamic).run(World());
      expect(result, isNot(isA<Future<void>>()));
      expect(loader.calls, hasLength(2), reason: 'reload started');
      expect(handle.get(), 'v1', reason: 'old value kept until it lands');

      loader.calls[1].complete('v2');
      await _settle();
      expect(handle.get(), 'v2');
    });

    test('drains Assets.markDirty for stores that are world resources', () {
      final loader = _ManualLoader();
      final assets = Assets<String>();
      final handle = assets.load('b.txt', loader);
      final world = World()..insertResource(assets);
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      final poll = HotReloadPollSystem(watcher);

      assets
        ..markDirty(handle.id)
        ..markDirty(handle.id);
      poll.run(world);
      expect(loader.calls, hasLength(2), reason: 'one load + one reload');

      poll.run(world);
      expect(loader.calls, hasLength(2), reason: 'nothing dirty, no work');
    });

    test('a failed reload keeps the value and records the error', () async {
      final loader = _ManualLoader();
      final assets = Assets<String>();
      final reported = <Object>[];
      assets.onLoadError = (path, e, st) => reported.add(e);
      final handle = assets.load('c.txt', loader);
      loader.calls.single.complete('v1');
      await _settle();

      final world = World()..insertResource(assets);
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      assets.markDirty(handle.id);
      HotReloadPollSystem(watcher).run(world);
      loader.calls[1].completeError(StateError('bad file'));
      await _settle();

      expect(handle.get(), 'v1');
      expect(handle.error, isA<StateError>());
      expect(reported, hasLength(1));
    });

    test('overlapping reloads: the latest started wins', () async {
      final loader = _ManualLoader();
      final assets = Assets<String>();
      final handle = assets.load('d.txt', loader);
      loader.calls.single.complete('v1');
      await _settle();

      final world = World()..insertResource(assets);
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      final poll = HotReloadPollSystem(watcher);
      assets.markDirty(handle.id);
      poll.run(world);
      assets.markDirty(handle.id);
      poll.run(world);

      loader.calls[2].complete('newest');
      await _settle();
      loader.calls[1].complete('stale');
      await _settle();
      expect(handle.get(), 'newest');
    });

    test('starts queued callbacks without needing a real watcher event', () {
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      var callCount = 0;
      watcher.watchWithCallback('does-not-exist', () async {
        callCount++;
      });
      // Fire a synthetic event; this exercises the enqueue path.
      watcher.debugFireChange('does-not-exist');

      final poll = HotReloadPollSystem(watcher);
      poll.run(World());
      expect(callCount, 1);

      // Second poll drains nothing.
      poll.run(World());
      expect(callCount, 1);
    });

    test('callback errors go to onCallbackError', () async {
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      final errors = <Object>[];
      watcher.onCallbackError = (e, st) {
        errors.add(e);
      };
      watcher
        ..watchWithCallback('x', () async => throw StateError('boom'))
        ..debugFireChange('x');

      HotReloadPollSystem(watcher).run(World());
      await _settle();

      expect(errors.single, isA<StateError>());
    });

    test('runs from an App tick with hot reload enabled', () async {
      final loader = _ManualLoader();
      final assets = Assets<String>();
      final handle = assets.load('e.txt', loader);
      final app = App()
        ..addPlugin(AssetPlugin(enableHotReload: true))
        ..insertResource(assets);
      addTearDown(app.dispose);

      app.world.getResource<HotReloadWatcher>()!
        ..watch('e.txt', assets, handle.id)
        ..debugFireChange('e.txt');
      await app.tick();

      expect(loader.calls, hasLength(2));
    });
  });

  group('HotReloadWatcher paths', () {
    test('matches by basename across either separator', () {
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      var calls = 0;
      watcher
        ..watchWithCallback(r'assets\img\hero.png', () async => calls++)
        ..debugFireChange('/abs/assets/img/hero.png');
      expect(watcher.drainPending(), hasLength(1));
      expect(calls, 0, reason: 'callbacks start in the poll system');
    });

    test('a file of the same name in another folder is not a match', () {
      final watcher = HotReloadWatcher();
      addTearDown(watcher.dispose);
      watcher
        ..watchWithCallback('assets/a/tree.png', () async {})
        ..debugFireChange('/abs/assets/b/tree.png');
      expect(watcher.drainPending(), isEmpty);
    });
  });
}
