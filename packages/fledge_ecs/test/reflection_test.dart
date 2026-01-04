import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class NamedEntity {
  String name;
  int? id;
  NamedEntity(this.name, [this.id]);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
    TypeRegistry.instance.clear();
  });

  group('FieldInfo', () {
    test('stores field metadata', () {
      const field = FieldInfo(name: 'x', type: double);
      expect(field.name, equals('x'));
      expect(field.type, equals(double));
      expect(field.isNullable, isFalse);
    });

    test('nullable field', () {
      const field = FieldInfo(name: 'id', type: int, isNullable: true);
      expect(field.isNullable, isTrue);
    });

    test('default value factory', () {
      final field = FieldInfo(
        name: 'value',
        type: int,
        defaultValue: () => 42,
      );
      expect(field.defaultValue?.call(), equals(42));
    });

    test('toString includes field info', () {
      const field = FieldInfo(name: 'x', type: double);
      expect(field.toString(), contains('x'));
      expect(field.toString(), contains('double'));
    });
  });

  group('ComponentTypeInfo', () {
    test('stores type metadata', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [
          const FieldInfo(name: 'x', type: double),
          const FieldInfo(name: 'y', type: double),
        ],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      expect(info.type, equals(Position));
      expect(info.name, equals('Position'));
      expect(info.fields.length, equals(2));
    });

    test('fromJson creates instance', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      final position = info.fromJson({'x': 10.0, 'y': 20.0});
      expect(position.x, equals(10.0));
      expect(position.y, equals(20.0));
    });

    test('toJson serializes instance', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      final json = info.toJson(Position(10, 20));
      expect(json, equals({'x': 10.0, 'y': 20.0}));
    });

    test('defaultFactory creates instance', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
        defaultFactory: () => Position(0, 0),
      );

      final defaultPos = info.defaultFactory!();
      expect(defaultPos.x, equals(0));
      expect(defaultPos.y, equals(0));
    });
  });

  group('TypeRegistry', () {
    test('instance is singleton', () {
      expect(TypeRegistry.instance, same(TypeRegistry.instance));
    });

    test('registerComponent adds type', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      TypeRegistry.instance.registerComponent(info);

      expect(TypeRegistry.instance.isRegistered<Position>(), isTrue);
      expect(TypeRegistry.instance.count, equals(1));
    });

    test('getByType returns registered type', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      TypeRegistry.instance.registerComponent(info);

      final retrieved = TypeRegistry.instance.getByType<Position>();
      expect(retrieved, same(info));
    });

    test('getByName returns registered type', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      TypeRegistry.instance.registerComponent(info);

      final retrieved = TypeRegistry.instance.getByName('Position');
      expect(retrieved, same(info));
    });

    test('getByRuntimeType returns registered type', () {
      final info = ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      );

      TypeRegistry.instance.registerComponent(info);

      final retrieved = TypeRegistry.instance.getByRuntimeType(Position);
      expect(retrieved, same(info));
    });

    test('returns null for unregistered type', () {
      expect(TypeRegistry.instance.getByType<Position>(), isNull);
      expect(TypeRegistry.instance.getByName('Position'), isNull);
    });

    test('clear removes all types', () {
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));

      TypeRegistry.instance.clear();

      expect(TypeRegistry.instance.count, equals(0));
      expect(TypeRegistry.instance.isRegistered<Position>(), isFalse);
    });

    test('registeredTypes returns all types', () {
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));

      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Velocity>(
        type: Velocity,
        name: 'Velocity',
        fields: [],
        fromJson: (json) =>
            Velocity(json['dx'] as double, json['dy'] as double),
        toJson: (vel) => {'dx': vel.dx, 'dy': vel.dy},
      ));

      expect(TypeRegistry.instance.registeredTypes.length, equals(2));
    });

    test('registeredNames returns all names', () {
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));

      expect(TypeRegistry.instance.registeredNames, containsAll(['Position']));
    });
  });

  group('TypeRegistryExtension', () {
    test('registerSimple registers component', () {
      TypeRegistry.instance.registerSimple<Position>(
        name: 'Position',
        fields: [
          const FieldInfo(name: 'x', type: double),
          const FieldInfo(name: 'y', type: double),
        ],
        constructor: (args) => Position(args[0] as double, args[1] as double),
        getFields: (pos) => [pos.x, pos.y],
      );

      expect(TypeRegistry.instance.isRegistered<Position>(), isTrue);

      final info = TypeRegistry.instance.getByType<Position>()!;
      final json = info.toJson(Position(10, 20));
      expect(json, equals({'x': 10.0, 'y': 20.0}));

      final restored = info.fromJson({'x': 5.0, 'y': 15.0});
      expect(restored.x, equals(5.0));
      expect(restored.y, equals(15.0));
    });
  });

  group('EntitySerializer', () {
    late World world;

    setUp(() {
      world = World();
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [
          const FieldInfo(name: 'x', type: double),
          const FieldInfo(name: 'y', type: double),
        ],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));

      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Velocity>(
        type: Velocity,
        name: 'Velocity',
        fields: [
          const FieldInfo(name: 'dx', type: double),
          const FieldInfo(name: 'dy', type: double),
        ],
        fromJson: (json) =>
            Velocity(json['dx'] as double, json['dy'] as double),
        toJson: (vel) => {'dx': vel.dx, 'dy': vel.dy},
      ));
    });

    test('toJson serializes entity', () {
      final entity = world.spawn()
        ..insert(Position(10, 20))
        ..insert(Velocity(1, 2));

      final json = EntitySerializer.toJson(world, entity.entity);

      expect(json, isNotNull);
      expect(json!['entity']['id'], equals(entity.entity.id));
      expect(json['components']['Position'], equals({'x': 10.0, 'y': 20.0}));
      expect(json['components']['Velocity'], equals({'dx': 1.0, 'dy': 2.0}));
    });

    test('toJson returns null for dead entity', () {
      final entity = world.spawn().entity;
      world.despawn(entity);

      final json = EntitySerializer.toJson(world, entity);
      expect(json, isNull);
    });

    test('toJson skips unregistered components', () {
      final entity = world.spawn()
        ..insert(Position(10, 20))
        ..insert(NamedEntity('test')); // Not registered

      final json = EntitySerializer.toJson(world, entity.entity);

      expect(json!['components'].containsKey('Position'), isTrue);
      expect(json['components'].containsKey('NamedEntity'), isFalse);
    });

    test('fromJson deserializes entity', () {
      final json = {
        'entity': {'id': 0, 'generation': 0},
        'components': {
          'Position': {'x': 10.0, 'y': 20.0},
          'Velocity': {'dx': 1.0, 'dy': 2.0},
        },
      };

      final entity = EntitySerializer.fromJson(world, json);

      expect(world.isAlive(entity), isTrue);
      expect(world.get<Position>(entity)?.x, equals(10.0));
      expect(world.get<Position>(entity)?.y, equals(20.0));
      expect(world.get<Velocity>(entity)?.dx, equals(1.0));
      expect(world.get<Velocity>(entity)?.dy, equals(2.0));
    });

    test('fromJson skips unknown component types', () {
      final json = {
        'entity': {'id': 0, 'generation': 0},
        'components': {
          'Position': {'x': 10.0, 'y': 20.0},
          'Unknown': {'foo': 'bar'},
        },
      };

      final entity = EntitySerializer.fromJson(world, json);

      expect(world.isAlive(entity), isTrue);
      expect(world.get<Position>(entity)?.x, equals(10.0));
    });
  });

  group('BatchEntitySerializer', () {
    late World world;

    setUp(() {
      world = World();
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));
    });

    test('toJsonList serializes multiple entities', () {
      final e1 = world.spawn()..insert(Position(1, 2));
      final e2 = world.spawn()..insert(Position(3, 4));

      final jsonList =
          BatchEntitySerializer.toJsonList(world, [e1.entity, e2.entity]);

      expect(jsonList.length, equals(2));
    });

    test('fromJsonList deserializes multiple entities', () {
      final jsonList = [
        {
          'entity': {'id': 0, 'generation': 0},
          'components': {
            'Position': {'x': 1.0, 'y': 2.0},
          },
        },
        {
          'entity': {'id': 1, 'generation': 0},
          'components': {
            'Position': {'x': 3.0, 'y': 4.0},
          },
        },
      ];

      final entities = BatchEntitySerializer.fromJsonList(world, jsonList);

      expect(entities.length, equals(2));
      expect(world.get<Position>(entities[0])?.x, equals(1.0));
      expect(world.get<Position>(entities[1])?.x, equals(3.0));
    });
  });

  group('World serialization extension', () {
    late World world;

    setUp(() {
      world = World();
      TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
        type: Position,
        name: 'Position',
        fields: [],
        fromJson: (json) => Position(json['x'] as double, json['y'] as double),
        toJson: (pos) => {'x': pos.x, 'y': pos.y},
      ));
    });

    test('entityToJson works', () {
      final entity = world.spawn()..insert(Position(10, 20));

      final json = world.entityToJson(entity.entity);

      expect(json, isNotNull);
      expect(json!['components']['Position']['x'], equals(10.0));
    });

    test('entityFromJson works', () {
      final json = {
        'entity': {'id': 0, 'generation': 0},
        'components': {
          'Position': {'x': 10.0, 'y': 20.0},
        },
      };

      final entity = world.entityFromJson(json);

      expect(world.get<Position>(entity)?.x, equals(10.0));
    });
  });
}
