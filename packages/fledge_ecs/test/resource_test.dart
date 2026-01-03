import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class TestResource {
  int value;
  TestResource(this.value);
}

class AnotherResource {
  String name;
  AnotherResource(this.name);
}

void main() {
  group('Resources', () {
    late Resources resources;

    setUp(() {
      resources = Resources();
    });

    test('insert and get resource', () {
      resources.insert(TestResource(42));
      final resource = resources.get<TestResource>();

      expect(resource, isNotNull);
      expect(resource!.value, equals(42));
    });

    test('get returns null for missing resource', () {
      final resource = resources.get<TestResource>();
      expect(resource, isNull);
    });

    test('insert replaces existing resource', () {
      resources.insert(TestResource(1));
      resources.insert(TestResource(2));

      expect(resources.get<TestResource>()!.value, equals(2));
    });

    test('getOrInsert creates resource if missing', () {
      final resource = resources.getOrInsert(() => TestResource(100));
      expect(resource.value, equals(100));
    });

    test('getOrInsert returns existing resource', () {
      resources.insert(TestResource(50));
      final resource = resources.getOrInsert(() => TestResource(100));
      expect(resource.value, equals(50));
    });

    test('remove removes and returns resource', () {
      resources.insert(TestResource(42));
      final removed = resources.remove<TestResource>();

      expect(removed, isNotNull);
      expect(removed!.value, equals(42));
      expect(resources.get<TestResource>(), isNull);
    });

    test('remove returns null for missing resource', () {
      expect(resources.remove<TestResource>(), isNull);
    });

    test('contains returns true for existing resource', () {
      resources.insert(TestResource(1));
      expect(resources.contains<TestResource>(), isTrue);
    });

    test('contains returns false for missing resource', () {
      expect(resources.contains<TestResource>(), isFalse);
    });

    test('multiple resource types coexist', () {
      resources.insert(TestResource(1));
      resources.insert(AnotherResource('test'));

      expect(resources.get<TestResource>()!.value, equals(1));
      expect(resources.get<AnotherResource>()!.name, equals('test'));
    });

    test('clear removes all resources', () {
      resources.insert(TestResource(1));
      resources.insert(AnotherResource('test'));
      resources.clear();

      expect(resources.length, equals(0));
      expect(resources.get<TestResource>(), isNull);
      expect(resources.get<AnotherResource>(), isNull);
    });
  });

  group('Res', () {
    test('value returns the resource', () {
      final resource = TestResource(42);
      final res = Res(resource);

      expect(res.value, same(resource));
      expect(res.value.value, equals(42));
    });

    test('call returns the resource', () {
      final resource = TestResource(42);
      final res = Res(resource);

      expect(res(), same(resource));
    });
  });

  group('ResMut', () {
    test('value returns the resource', () {
      final resource = TestResource(42);
      final res = ResMut(resource);

      expect(res.value, same(resource));
    });

    test('resource is mutable', () {
      final resource = TestResource(1);
      final res = ResMut(resource);

      res.value.value = 100;
      expect(resource.value, equals(100));
    });
  });

  group('ResOption', () {
    test('value returns resource when present', () {
      final resource = TestResource(42);
      final res = ResOption(resource);

      expect(res.value, same(resource));
      expect(res.exists, isTrue);
    });

    test('value returns null when missing', () {
      final res = ResOption<TestResource>(null);

      expect(res.value, isNull);
      expect(res.exists, isFalse);
    });
  });

  group('World resource methods', () {
    late World world;

    setUp(() {
      world = World();
    });

    test('insertResource and getResource', () {
      world.insertResource(TestResource(42));

      expect(world.getResource<TestResource>(), isNotNull);
      expect(world.getResource<TestResource>()!.value, equals(42));
    });

    test('hasResource', () {
      expect(world.hasResource<TestResource>(), isFalse);
      world.insertResource(TestResource(1));
      expect(world.hasResource<TestResource>(), isTrue);
    });

    test('removeResource', () {
      world.insertResource(TestResource(42));
      final removed = world.removeResource<TestResource>();

      expect(removed, isNotNull);
      expect(removed!.value, equals(42));
      expect(world.hasResource<TestResource>(), isFalse);
    });
  });
}
