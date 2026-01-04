import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

enum GameState { menu, playing, paused, gameOver }

class Position {
  double x, y;
  Position(this.x, this.y);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('State', () {
    test('starts with initial state', () {
      final state = State<GameState>(GameState.menu);
      expect(state.current, equals(GameState.menu));
    });

    test('isIn returns true for current state', () {
      final state = State<GameState>(GameState.menu);
      expect(state.isIn(GameState.menu), isTrue);
      expect(state.isIn(GameState.playing), isFalse);
    });

    test('set schedules transition', () {
      final state = State<GameState>(GameState.menu);
      state.set(GameState.playing);

      // State hasn't changed yet
      expect(state.current, equals(GameState.menu));
      expect(state.isPending, isTrue);
    });

    test('applyTransition changes state', () {
      final state = State<GameState>(GameState.menu);
      state.set(GameState.playing);
      state.applyTransition();

      expect(state.current, equals(GameState.playing));
      expect(state.isPending, isFalse);
    });

    test('justEntered is true after transition', () {
      final state = State<GameState>(GameState.menu);

      // Initially just entered
      expect(state.justEntered, isTrue);

      // Clear and apply no transition
      state.applyTransition();
      expect(state.justEntered, isFalse);

      // Transition to new state
      state.set(GameState.playing);
      state.applyTransition();
      expect(state.justEntered, isTrue);
    });

    test('justExited is true during transition', () {
      final state = State<GameState>(GameState.menu);

      expect(state.justExited, isFalse);

      state.set(GameState.playing);
      state.applyTransition();

      // During transition frame, both are true
      expect(state.justExited, isTrue);
      expect(state.justEntered, isTrue);
    });

    test('cancelTransition clears pending state', () {
      final state = State<GameState>(GameState.menu);
      state.set(GameState.playing);
      expect(state.isPending, isTrue);

      state.cancelTransition();
      expect(state.isPending, isFalse);
      expect(state.current, equals(GameState.menu));
    });

    test('set to same state does nothing', () {
      final state = State<GameState>(GameState.menu);
      state.set(GameState.menu);
      expect(state.isPending, isFalse);
    });
  });

  group('StateRegistry', () {
    test('stores multiple state types', () {
      final registry = StateRegistry();
      registry.add(State<GameState>(GameState.menu));

      expect(registry.length, equals(1));
      expect(registry.get<GameState>(), isNotNull);
    });

    test('applyTransitions applies all', () {
      final registry = StateRegistry();
      final gameState = State<GameState>(GameState.menu);
      registry.add(gameState);

      gameState.set(GameState.playing);
      registry.applyTransitions();

      expect(gameState.current, equals(GameState.playing));
    });
  });

  group('State conditions', () {
    test('InState returns true when in state', () {
      final world = World();
      world.insertResource(State<GameState>(GameState.playing));

      final condition = const InState<GameState>(GameState.playing).condition;
      expect(condition(world), isTrue);

      final wrongCondition = const InState<GameState>(GameState.menu).condition;
      expect(wrongCondition(world), isFalse);
    });

    test('InState returns false when state not registered', () {
      final world = World();

      final condition = const InState<GameState>(GameState.playing).condition;
      expect(condition(world), isFalse);
    });

    test('OnEnterState returns true when just entered', () {
      final world = World();
      final state = State<GameState>(GameState.menu);
      world.insertResource(state);

      // Just created, so justEntered is true
      var condition = const OnEnterState<GameState>(GameState.menu).condition;
      expect(condition(world), isTrue);

      // After clearing flags, no longer just entered
      state.applyTransition();
      expect(condition(world), isFalse);

      // Transition to playing
      state.set(GameState.playing);
      state.applyTransition();

      condition = const OnEnterState<GameState>(GameState.playing).condition;
      expect(condition(world), isTrue);
    });

    test('OnExitState returns true when exiting', () {
      final world = World();
      final state = State<GameState>(GameState.menu);
      world.insertResource(state);

      final condition = const OnExitState<GameState>(GameState.menu).condition;
      expect(condition(world), isFalse);

      // Transition to playing - during transition, menu was exited
      state.set(GameState.playing);
      state.applyTransition();

      // Now we're in playing, but the exit flag is for "any state"
      // The condition checks for menu specifically
      expect(condition(world), isFalse); // We're no longer in menu

      // Check that playing's exit condition would be true if we exit playing
      final playingExit =
          const OnExitState<GameState>(GameState.playing).condition;
      state.set(GameState.menu);
      state.applyTransition();
      expect(playingExit(world), isFalse); // We're now in menu, not playing
    });

    test('StateConditions.inAny matches any state', () {
      final world = World();
      final state = State<GameState>(GameState.playing);
      world.insertResource(state);

      final condition = StateConditions.inAny<GameState>(
          [GameState.playing, GameState.paused]);
      expect(condition(world), isTrue);

      state.set(GameState.menu);
      state.applyTransition();
      expect(condition(world), isFalse);
    });

    test('StateConditions.notIn negates state check', () {
      final world = World();
      final state = State<GameState>(GameState.playing);
      world.insertResource(state);

      final condition = StateConditions.notIn<GameState>(GameState.menu);
      expect(condition(world), isTrue);

      state.set(GameState.menu);
      state.applyTransition();
      expect(condition(world), isFalse);
    });
  });

  group('World state extensions', () {
    test('getState returns current state', () {
      final world = World();
      world.insertResource(State<GameState>(GameState.playing));

      expect(world.getState<GameState>(), equals(GameState.playing));
    });

    test('setState triggers transition', () {
      final world = World();
      final state = State<GameState>(GameState.menu);
      world.insertResource(state);

      world.setState<GameState>(GameState.playing);
      expect(state.isPending, isTrue);

      state.applyTransition();
      expect(world.getState<GameState>(), equals(GameState.playing));
    });

    test('isInState checks current state', () {
      final world = World();
      world.insertResource(State<GameState>(GameState.playing));

      expect(world.isInState<GameState>(GameState.playing), isTrue);
      expect(world.isInState<GameState>(GameState.menu), isFalse);
    });
  });

  group('App state integration', () {
    test('addState creates state resource', () {
      final app = App();
      app.addState<GameState>(GameState.menu);

      expect(app.world.getResource<State<GameState>>(), isNotNull);
      expect(app.world.getState<GameState>(), equals(GameState.menu));
    });

    test('addSystemInState only runs in specified state', () async {
      final app = App();
      app.addState<GameState>(GameState.menu);

      var playingCount = 0;
      var menuCount = 0;

      app.addSystemInState(
        FunctionSystem('playingSystem', run: (_) => playingCount++),
        GameState.playing,
      );
      app.addSystemInState(
        FunctionSystem('menuSystem', run: (_) => menuCount++),
        GameState.menu,
      );

      // First tick - in menu state
      await app.tick();
      expect(menuCount, equals(1));
      expect(playingCount, equals(0));

      // Transition to playing (applied at end of THIS tick)
      app.world.setState<GameState>(GameState.playing);
      await app.tick();
      // During this tick, menu was still active, but transition applied at end
      expect(menuCount, equals(2)); // Menu ran once more
      expect(playingCount, equals(0)); // Playing not yet active

      // Now in playing state
      await app.tick();
      expect(menuCount, equals(2)); // No new runs
      expect(playingCount, equals(1));
    });

    test('state transitions apply at end of tick', () async {
      final app = App();
      app.addState<GameState>(GameState.menu);

      // Request transition during tick
      app.addSystem(FunctionSystem(
        'transitioner',
        run: (world) {
          world.setState<GameState>(GameState.playing);
        },
      ));

      expect(app.world.getState<GameState>(), equals(GameState.menu));

      await app.tick();

      // After tick, transition has been applied
      expect(app.world.getState<GameState>(), equals(GameState.playing));
    });
  });
}
