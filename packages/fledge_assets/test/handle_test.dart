import 'package:fledge_assets/fledge_assets.dart';
import 'package:test/test.dart';

void main() {
  group('HandleId', () {
    test('equal by id, debugLabel excluded', () {
      const a = HandleId(7, debugLabel: 'player');
      const b = HandleId(7, debugLabel: 'other');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('unequal when ids differ', () {
      expect(const HandleId(1), isNot(equals(const HandleId(2))));
    });
  });

  group('Handle', () {
    test('clone bumps refcount, drop decrements, entry disappears at 0', () {
      final assets = Assets<String>();
      final h1 = assets.add('hello');
      expect(assets.refCount(h1.id), 1);

      final h2 = h1.clone();
      expect(assets.refCount(h1.id), 2);
      expect(h2.id, equals(h1.id));

      h1.drop();
      expect(assets.refCount(h1.id), 1);
      expect(assets.get(h1.id), 'hello',
          reason: 'entry stays while any handle holds a ref');

      h2.drop();
      expect(assets.refCount(h1.id), 0);
      expect(assets.get(h1.id), isNull,
          reason: 'entry should be evicted at refcount 0');
    });

    test('double-drop on the same instance is idempotent', () {
      final assets = Assets<String>();
      final h = assets.add('once');
      final clone = h.clone();

      h.drop();
      h.drop(); // second drop must NOT free the entry the clone owns.

      expect(assets.refCount(h.id), 1,
          reason: 'clone still holds one live reference');
      expect(clone.get(), 'once');
    });

    test('get() returns the underlying asset via the store', () {
      final assets = Assets<int>();
      final h = assets.add(42);
      expect(h.get(), 42);
      expect(h.isReady, isTrue);
      h.drop();
    });
  });
}
