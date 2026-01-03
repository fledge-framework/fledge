import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class GameState {
  bool isPlaying;
  bool isPaused;

  GameState({this.isPlaying = false, this.isPaused = false});
}

class Position {
  double x, y;
  Position(this.x, this.y);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('RunConditions', () {
    test('resource predicate returns true when predicate matches', () {
      final world = World();
      world.insertResource(GameState(isPlaying: true));

      final condition = RunConditions.resource<GameState>((s) => s.isPlaying);
      expect(condition(world), isTrue);
    });

    test('resource predicate returns false when predicate fails', () {
      final world = World();
      world.insertResource(GameState(isPlaying: false));

      final condition = RunConditions.resource<GameState>((s) => s.isPlaying);
      expect(condition(world), isFalse);
    });

    test('resource predicate returns false when resource missing', () {
      final world = World();

      final condition = RunConditions.resource<GameState>((s) => s.isPlaying);
      expect(condition(world), isFalse);
    });

    test('resourceExists returns true when resource exists', () {
      final world = World();
      world.insertResource(GameState());

      expect(RunConditions.resourceExists<GameState>()(world), isTrue);
    });

    test('resourceExists returns false when resource missing', () {
      final world = World();

      expect(RunConditions.resourceExists<GameState>()(world), isFalse);
    });

    test('and combines conditions correctly', () {
      final world = World();
      world.insertResource(GameState(isPlaying: true, isPaused: false));

      final allTrue = RunConditions.and([
        RunConditions.resource<GameState>((s) => s.isPlaying),
        RunConditions.resource<GameState>((s) => !s.isPaused),
      ]);
      expect(allTrue(world), isTrue);

      final oneFalse = RunConditions.and([
        RunConditions.resource<GameState>((s) => s.isPlaying),
        RunConditions.resource<GameState>((s) => s.isPaused),
      ]);
      expect(oneFalse(world), isFalse);
    });

    test('or combines conditions correctly', () {
      final world = World();
      world.insertResource(GameState(isPlaying: true, isPaused: false));

      final oneTrue = RunConditions.or([
        RunConditions.resource<GameState>((s) => s.isPlaying),
        RunConditions.resource<GameState>((s) => s.isPaused),
      ]);
      expect(oneTrue(world), isTrue);

      final allFalse = RunConditions.or([
        RunConditions.resource<GameState>((s) => !s.isPlaying),
        RunConditions.resource<GameState>((s) => s.isPaused),
      ]);
      expect(allFalse(world), isFalse);
    });

    test('not negates condition', () {
      final world = World();
      world.insertResource(GameState(isPlaying: true));

      final notPlaying =
          RunConditions.not(RunConditions.resource<GameState>((s) => s.isPlaying));
      expect(notPlaying(world), isFalse);

      final notPaused =
          RunConditions.not(RunConditions.resource<GameState>((s) => s.isPaused));
      expect(notPaused(world), isTrue);
    });

    test('always returns true', () {
      final world = World();
      expect(RunConditions.always()(world), isTrue);
    });

    test('never returns false', () {
      final world = World();
      expect(RunConditions.never()(world), isFalse);
    });
  });

  group('System run conditions', () {
    test('FunctionSystem with runIf executes when condition true', () async {
      final world = World();
      world.insertResource(GameState(isPlaying: true));

      var executed = false;
      final system = FunctionSystem(
        'conditionalSystem',
        runIf: RunConditions.resource<GameState>((s) => s.isPlaying),
        run: (world) {
          executed = true;
        },
      );

      expect(system.shouldRun(world), isTrue);
      await system.run(world);
      expect(executed, isTrue);
    });

    test('FunctionSystem with runIf skipped when condition false', () {
      final world = World();
      world.insertResource(GameState(isPlaying: false));

      final system = FunctionSystem(
        'conditionalSystem',
        runIf: RunConditions.resource<GameState>((s) => s.isPlaying),
        run: (world) {},
      );

      expect(system.shouldRun(world), isFalse);
    });

    test('FunctionSystem without runIf always runs', () {
      final world = World();

      final system = FunctionSystem(
        'unconditionalSystem',
        run: (world) {},
      );

      expect(system.shouldRun(world), isTrue);
    });

    test('AsyncFunctionSystem with runIf works correctly', () async {
      final world = World();
      world.insertResource(GameState(isPlaying: true));

      var executed = false;
      final system = AsyncFunctionSystem(
        'asyncConditional',
        runIf: RunConditions.resource<GameState>((s) => s.isPlaying),
        run: (world) async {
          executed = true;
        },
      );

      expect(system.shouldRun(world), isTrue);
      await system.run(world);
      expect(executed, isTrue);
    });
  });

  group('Schedule respects run conditions', () {
    test('skips systems with false conditions', () async {
      final world = World();
      world.insertResource(GameState(isPlaying: false));

      final executed = <String>[];

      final schedule = Schedule()
        ..addSystem(FunctionSystem(
          'unconditional',
          run: (_) => executed.add('unconditional'),
        ))
        ..addSystem(FunctionSystem(
          'conditional',
          runIf: RunConditions.resource<GameState>((s) => s.isPlaying),
          run: (_) => executed.add('conditional'),
        ));

      await schedule.run(world);

      expect(executed, equals(['unconditional']));
    });

    test('runs systems when conditions become true', () async {
      final world = World();
      final gameState = GameState(isPlaying: false);
      world.insertResource(gameState);

      final executed = <String>[];

      final schedule = Schedule()
        ..addSystem(FunctionSystem(
          'conditional',
          runIf: RunConditions.resource<GameState>((s) => s.isPlaying),
          run: (_) => executed.add('conditional'),
        ));

      // First run - condition false
      await schedule.run(world);
      expect(executed, isEmpty);

      // Change state
      gameState.isPlaying = true;

      // Second run - condition now true
      await schedule.run(world);
      expect(executed, equals(['conditional']));
    });

    test('dependent systems still run after skipped system', () async {
      final world = World();
      world.insertResource(GameState(isPlaying: false));

      final posId = ComponentId.of<Position>();
      final executed = <String>[];

      final schedule = Schedule()
        ..addSystem(FunctionSystem(
          'skipped',
          writes: {posId},
          runIf: RunConditions.never(),
          run: (_) => executed.add('skipped'),
        ))
        ..addSystem(FunctionSystem(
          'dependent',
          writes: {posId},
          run: (_) => executed.add('dependent'),
        ));

      await schedule.run(world);

      // The dependent system should run even though the first was skipped
      expect(executed, equals(['dependent']));
    });
  });
}
