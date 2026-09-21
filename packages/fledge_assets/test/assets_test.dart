import 'dart:async';

import 'package:fledge_assets/fledge_assets.dart';
import 'package:test/test.dart';

/// Deterministic loader for tests: returns whatever [_result] holds
/// once the completer is filled. Tracks call count so the dedup test
/// can prove the second `load()` did not re-invoke it.
class _StringLoader implements Loader<String> {
  int calls = 0;
  final Map<String, String> _byPath;

  _StringLoader(this._byPath);

  @override
  Future<String> load(String path) async {
    calls++;
    // Simulate an async boundary so callers can observe the
    // "not-yet-ready" state before completion.
    await Future<void>.delayed(Duration.zero);
    final v = _byPath[path];
    if (v == null) throw StateError('no fixture for $path');
    return v;
  }
}

void main() {
  group('Assets.add', () {
    test('returns a handle whose get() yields the asset', () {
      final assets = Assets<String>();
      final h = assets.add('immediate');
      expect(h.get(), 'immediate');
      expect(h.isReady, isTrue);
      expect(assets.refCount(h.id), 1);
    });

    test('minted ids start at 1 (0 reserved)', () {
      final assets = Assets<String>();
      final h = assets.add('a');
      expect(h.id.id, greaterThanOrEqualTo(1));
    });
  });

  group('Assets.addWithId', () {
    test('reserves a caller-supplied id (e.g. solid-color texture)', () {
      final assets = Assets<String>();
      const reserved = HandleId(0, debugLabel: 'solid');
      final h = assets.addWithId(reserved, 'white');
      expect(h.id, equals(reserved));
      expect(h.get(), 'white');
    });

    test('throws if the id is already taken', () {
      final assets = Assets<String>();
      const id = HandleId(0);
      assets.addWithId(id, 'a');
      expect(
        () => assets.addWithId(id, 'b'),
        throwsA(isA<StateError>()),
      );
    });

    test('subsequent add() does not collide with reserved ids', () {
      final assets = Assets<String>();
      final reserved = assets.addWithId(const HandleId(5), 'r');
      final auto = assets.add('a');
      expect(auto.id.id, greaterThan(reserved.id.id));
    });
  });

  group('Assets.load', () {
    test('get() null until async load completes, then non-null', () async {
      final loader = _StringLoader({'p': 'value'});
      final assets = Assets<String>();
      final h = assets.load('p', loader);

      expect(h.get(), isNull,
          reason: 'load is async — value should not appear synchronously');
      expect(h.isReady, isFalse);

      // Let the microtask + zero-delay complete.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(h.get(), 'value');
      expect(h.isReady, isTrue);
    });

    test('two loads on the same path share one entry (dedup)', () async {
      final loader = _StringLoader({'p': 'value'});
      final assets = Assets<String>();

      final h1 = assets.load('p', loader);
      final h2 = assets.load('p', loader);

      expect(h1.id, equals(h2.id),
          reason: 'both handles should point at the same entry');
      expect(assets.refCount(h1.id), 2,
          reason: 'the second load bumps refcount rather than starting a '
              'second loader invocation');
      expect(loader.calls, 1);
    });

    test('reload replaces the value with a fresh loader call', () async {
      final store = <String, String>{'p': 'v1'};
      final loader = _StringLoader(store);
      final assets = Assets<String>();
      final h = assets.load('p', loader);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.get(), 'v1');

      store['p'] = 'v2';
      await assets.reload(h.id);
      expect(h.get(), 'v2');
      expect(loader.calls, 2);
    });

    test('reload on an add()-only entry is a no-op (no path/loader)', () async {
      final assets = Assets<String>();
      final h = assets.add('static');
      await assets.reload(h.id);
      expect(h.get(), 'static');
    });

    test('drop of last handle removes the path index too', () async {
      final loader = _StringLoader({'p': 'v'});
      final assets = Assets<String>();
      final h = assets.load('p', loader);
      h.drop();
      expect(assets.findByPath('p'), isNull);
      expect(assets.get(h.id), isNull);
    });
  });
}
