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

void main() {
  // Filesystem watching on macOS/Linux CI is racy — `package:watcher`
  // can miss events under sandboxes. We drive the watcher directly via
  // its debug hook, which is what a real event would trigger. On web
  // that hook still exists; the actual DirectoryWatcher is what the
  // pure-native path relies on and is exercised by manual testing.
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

      // The poll system drains queued reload callbacks. Provide a
      // minimal `World` since [System.run] takes one.
      final poll = HotReloadPollSystem(watcher);
      await poll.run(World());

      expect(
        handle.get(),
        'world',
        reason: 'reload should have been driven through the poll system',
      );
    });
  });

  group('HotReloadPollSystem', () {
    test(
      'drains queued callbacks without needing a real watcher event',
      () async {
        final watcher = HotReloadWatcher();
        var callCount = 0;
        watcher.watchWithCallback('does-not-exist', () async {
          callCount++;
        });
        // Fire a synthetic event; this exercises the enqueue path.
        watcher.debugFireChange('does-not-exist');

        final poll = HotReloadPollSystem(watcher);
        await poll.run(World());

        expect(callCount, 1);

        // Second poll drains nothing.
        await poll.run(World());
        expect(callCount, 1);
      },
    );
  });
}
