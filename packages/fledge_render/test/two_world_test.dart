import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:test/test.dart';

/// Test component for main world.
class Position {
  final double x;
  final double y;

  Position(this.x, this.y);
}

/// Test component for main world.
class Velocity {
  final double dx;
  final double dy;

  Velocity(this.dx, this.dy);
}

/// Extracted render data.
class ExtractedPosition {
  final Entity entity;
  final double x;
  final double y;

  ExtractedPosition(this.entity, this.x, this.y);
}

/// Test extractor.
class PositionExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, pos) in mainWorld.query1<Position>().iter()) {
      renderWorld.spawn()..insert(ExtractedPosition(entity, pos.x, pos.y));
    }
  }
}

void main() {
  group('RenderWorld', () {
    test('spawn creates entity', () {
      final renderWorld = RenderWorld();
      renderWorld.spawn()..insert(ExtractedPosition(Entity(0, 0), 1, 2));

      expect(renderWorld.entityCount, equals(1));
    });

    test('clear removes all entities', () {
      final renderWorld = RenderWorld();
      renderWorld.spawn()..insert(ExtractedPosition(Entity(0, 0), 1, 2));
      renderWorld.spawn()..insert(ExtractedPosition(Entity(1, 0), 3, 4));

      expect(renderWorld.entityCount, equals(2));

      renderWorld.clear();

      expect(renderWorld.entityCount, equals(0));
    });

    test('resources persist across clear', () {
      final renderWorld = RenderWorld();
      renderWorld.insertResource('test resource');
      renderWorld.spawn()..insert(ExtractedPosition(Entity(0, 0), 1, 2));

      renderWorld.clear();

      expect(renderWorld.getResource<String>(), equals('test resource'));
      expect(renderWorld.entityCount, equals(0));
    });

    test('query returns entities', () {
      final renderWorld = RenderWorld();
      renderWorld.spawn()..insert(ExtractedPosition(Entity(0, 0), 1, 2));
      renderWorld.spawn()..insert(ExtractedPosition(Entity(1, 0), 3, 4));

      final results = renderWorld.query1<ExtractedPosition>().iter().toList();

      expect(results, hasLength(2));
    });

    test('hasResource returns correct value', () {
      final renderWorld = RenderWorld();

      expect(renderWorld.hasResource<String>(), isFalse);

      renderWorld.insertResource('test');

      expect(renderWorld.hasResource<String>(), isTrue);
    });

    test('removeResource removes and returns resource', () {
      final renderWorld = RenderWorld();
      renderWorld.insertResource('test');

      final removed = renderWorld.removeResource<String>();

      expect(removed, equals('test'));
      expect(renderWorld.hasResource<String>(), isFalse);
    });
  });

  group('Extractor', () {
    test('ComponentExtractor extracts single component', () {
      final mainWorld = World();
      final renderWorld = RenderWorld();

      // Add entities to main world
      mainWorld.spawn()..insert(Position(1, 2));
      mainWorld.spawn()..insert(Position(3, 4));

      // Create and run extractor
      final extractor = ComponentExtractor<Position, ExtractedPosition>(
        (world, entity, pos) => ExtractedPosition(entity, pos.x, pos.y),
      );
      extractor.extract(mainWorld, renderWorld);

      // Verify extraction
      final extracted = renderWorld.query1<ExtractedPosition>().iter().toList();
      expect(extracted, hasLength(2));
    });

    test('PositionExtractor extracts positions', () {
      final mainWorld = World();
      final renderWorld = RenderWorld();

      mainWorld.spawn()..insert(Position(10, 20));
      mainWorld.spawn()..insert(Position(30, 40));

      final extractor = PositionExtractor();
      extractor.extract(mainWorld, renderWorld);

      final extracted = renderWorld.query1<ExtractedPosition>().iter().toList();
      expect(extracted, hasLength(2));

      final positions = extracted.map((e) => (e.$2.x, e.$2.y)).toList();
      expect(positions, containsAll([(10.0, 20.0), (30.0, 40.0)]));
    });
  });

  group('Extractors', () {
    test('register adds extractor', () {
      final extractors = Extractors();

      expect(extractors.isEmpty, isTrue);

      extractors.register(PositionExtractor());

      expect(extractors.length, equals(1));
      expect(extractors.isNotEmpty, isTrue);
    });

    test('remove removes extractor', () {
      final extractors = Extractors();
      final extractor = PositionExtractor();

      extractors.register(extractor);
      expect(extractors.length, equals(1));

      extractors.remove(extractor);
      expect(extractors.isEmpty, isTrue);
    });

    test('clear removes all extractors', () {
      final extractors = Extractors();
      extractors.register(PositionExtractor());
      extractors.register(PositionExtractor());

      extractors.clear();

      expect(extractors.isEmpty, isTrue);
    });
  });

  group('ExtractSystem', () {
    test('clears render world and runs extractors', () {
      final mainWorld = World();
      final renderWorld = RenderWorld();

      // Add extractors as resource
      mainWorld.insertResource(Extractors()..register(PositionExtractor()));

      // Add entities to main world
      mainWorld.spawn()..insert(Position(1, 2));

      // Pre-populate render world
      renderWorld.spawn()..insert(ExtractedPosition(Entity(99, 0), 0, 0));
      expect(renderWorld.entityCount, equals(1));

      // Run extract system
      final extractSystem = ExtractSystem();
      extractSystem.run(mainWorld, renderWorld);

      // Should have cleared old data and extracted new
      final extracted = renderWorld.query1<ExtractedPosition>().iter().toList();
      expect(extracted, hasLength(1));
      expect(extracted.first.$2.x, equals(1));
    });

    test('handles missing extractors resource', () {
      final mainWorld = World();
      final renderWorld = RenderWorld();

      // No extractors resource
      final extractSystem = ExtractSystem();

      // Should not throw
      expect(() => extractSystem.run(mainWorld, renderWorld), returnsNormally);
    });
  });

  group('RenderStage', () {
    test('stages are in correct order', () {
      final stages = RenderStage.values;

      expect(stages.indexOf(RenderStage.extract), equals(0));
      expect(stages.indexOf(RenderStage.prepare), equals(1));
      expect(stages.indexOf(RenderStage.queue), equals(2));
      expect(stages.indexOf(RenderStage.render), equals(3));
      expect(stages.indexOf(RenderStage.cleanup), equals(4));
    });
  });

  group('RenderSchedule', () {
    test('addSystem adds to correct stage', () {
      final schedule = RenderSchedule();
      final system = SyncRenderSystem('test', (mainWorld, renderWorld) {});

      schedule.addSystem(RenderStage.prepare, system);

      expect(schedule.getSystems(RenderStage.prepare), contains(system));
      expect(schedule.getSystems(RenderStage.queue), isEmpty);
    });

    test('addFunctionSystem adds async function', () {
      final schedule = RenderSchedule();

      schedule.addFunctionSystem(
        RenderStage.render,
        'async_test',
        (mainWorld, renderWorld) async {},
      );

      expect(schedule.getSystems(RenderStage.render), hasLength(1));
    });

    test('addSyncSystem adds sync function', () {
      final schedule = RenderSchedule();

      schedule.addSyncSystem(
        RenderStage.cleanup,
        'sync_test',
        (mainWorld, renderWorld) {},
      );

      expect(schedule.getSystems(RenderStage.cleanup), hasLength(1));
    });

    test('removeSystem removes from stage', () {
      final schedule = RenderSchedule();
      final system = SyncRenderSystem('test', (mainWorld, renderWorld) {});

      schedule.addSystem(RenderStage.prepare, system);
      schedule.removeSystem(RenderStage.prepare, system);

      expect(schedule.getSystems(RenderStage.prepare), isEmpty);
    });

    test('removeSystemByName removes by name', () {
      final schedule = RenderSchedule();

      schedule.addSyncSystem(
        RenderStage.queue,
        'my_system',
        (mainWorld, renderWorld) {},
      );

      final removed =
          schedule.removeSystemByName(RenderStage.queue, 'my_system');

      expect(removed, isTrue);
      expect(schedule.getSystems(RenderStage.queue), isEmpty);
    });

    test('run executes stages in order', () async {
      final schedule = RenderSchedule();
      final mainWorld = World();
      final renderWorld = RenderWorld();
      final log = <String>[];

      schedule.addSyncSystem(
        RenderStage.extract,
        'extract',
        (m, r) => log.add('extract'),
      );
      schedule.addSyncSystem(
        RenderStage.prepare,
        'prepare',
        (m, r) => log.add('prepare'),
      );
      schedule.addSyncSystem(
        RenderStage.queue,
        'queue',
        (m, r) => log.add('queue'),
      );
      schedule.addSyncSystem(
        RenderStage.render,
        'render',
        (m, r) => log.add('render'),
      );
      schedule.addSyncSystem(
        RenderStage.cleanup,
        'cleanup',
        (m, r) => log.add('cleanup'),
      );

      await schedule.run(mainWorld, renderWorld);

      expect(log, equals(['extract', 'prepare', 'queue', 'render', 'cleanup']));
    });

    test('run extracts data automatically', () async {
      final schedule = RenderSchedule();
      final mainWorld = World();
      final renderWorld = RenderWorld();

      // Register extractor
      mainWorld.insertResource(Extractors()..register(PositionExtractor()));

      // Add entity to main world
      mainWorld.spawn()..insert(Position(5, 6));

      // Track if render stage sees the data
      var foundEntity = false;
      schedule.addSyncSystem(
        RenderStage.render,
        'check',
        (m, r) {
          final extracted = r.query1<ExtractedPosition>().iter().toList();
          foundEntity = extracted.isNotEmpty && extracted.first.$2.x == 5;
        },
      );

      await schedule.run(mainWorld, renderWorld);

      expect(foundEntity, isTrue);
    });

    test('clear removes all systems', () {
      final schedule = RenderSchedule();

      schedule.addSyncSystem(
        RenderStage.extract,
        's1',
        (m, r) {},
      );
      schedule.addSyncSystem(
        RenderStage.render,
        's2',
        (m, r) {},
      );

      schedule.clear();

      expect(schedule.systemCount, equals(0));
    });

    test('systemCount returns total systems', () {
      final schedule = RenderSchedule();

      schedule.addSyncSystem(RenderStage.extract, 's1', (m, r) {});
      schedule.addSyncSystem(RenderStage.prepare, 's2', (m, r) {});
      schedule.addSyncSystem(RenderStage.queue, 's3', (m, r) {});

      expect(schedule.systemCount, equals(3));
    });
  });
}
