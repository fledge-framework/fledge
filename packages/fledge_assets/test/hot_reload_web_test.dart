@TestOn('browser')
library;

import 'package:fledge_assets/fledge_assets.dart';
import 'package:test/test.dart';

/// Loader that never completes; the web test only checks registration.
class _NeverLoader implements Loader<String> {
  @override
  Future<String> load(String path) => Future<String>.value('');
}

void main() {
  // On the web there's no dart:io file watching: watch() must quietly
  // start no watcher instead of throwing.
  test('watch is a no-op where dart:io file watching is unavailable', () {
    final watcher = HotReloadWatcher();
    final assets = Assets<String>();
    final handle = assets.load('assets/a.txt', _NeverLoader());

    expect(
      () => watcher.watch('assets/a.txt', assets, handle.id),
      returnsNormally,
    );
    expect(
      () => watcher.watchWithCallback('assets/b.txt', () async {}),
      returnsNormally,
    );
    watcher.debugFireChange('assets/a.txt');
    expect(assets.drainDirtyReloads(), [handle.id]);
  });
}
