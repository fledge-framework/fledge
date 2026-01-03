import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:advanced_ecs_example/components.dart';

/// Game states
enum GameState { loading, playing, paused, gameOver }

/// Advanced ECS example demonstrating new Fledge features.
///
/// This example shows:
/// - Game states and state transitions
/// - Observers for component lifecycle events
/// - Parent-child entity hierarchies
/// - Change detection
/// - Run conditions
/// - System sets and ordering
void main() async {
  print('=== Fledge ECS Advanced Example ===\n');

  // ============================================
  // 1. OBSERVERS - React to component changes
  // ============================================
  print('--- 1. Observers Demo ---\n');

  final world = World();

  // Register observers before spawning entities
  world.observers.register(Observer<Spaceship>.onAdd((w, entity, ship) {
    print('  [Observer] Spaceship "${ship.name}" spawned!');
  }));

  world.observers.register(Observer<Turret>.onAdd((w, entity, turret) {
    print('  [Observer] Turret "${turret.type}" attached!');
  }));

  world.observers.register(Observer<Health>.onRemove((w, entity, health) {
    print(
        '  [Observer] Entity $entity lost Health component (was ${health.current}/${health.max})');
  }));

  world.observers.register(Observer<Health>.onChange((w, entity, health) {
    print('  [Observer] Health changed to ${health.current}/${health.max}');
  }));

  // Spawn a spaceship - triggers onAdd observer
  print('Spawning spaceship...');
  final ship = world.spawn()
    ..insert(Spaceship('Falcon', shields: 100))
    ..insert(Position(0, 0))
    ..insert(Velocity(1, 0))
    ..insert(Health(100));

  print('');

  // ============================================
  // 2. HIERARCHIES - Parent-child relationships
  // ============================================
  print('--- 2. Hierarchies Demo ---\n');

  // Spawn turrets as children of the spaceship
  print('Attaching turrets to spaceship...');

  final leftTurret = world.spawnChild(ship.entity)
    ..insert(Turret('Laser', ammo: 100))
    ..insert(Position(-10, 0)); // Local offset from parent

  final rightTurret = world.spawnChild(ship.entity)
    ..insert(Turret('Missile', ammo: 20))
    ..insert(Position(10, 0));

  print('');

  // Query the hierarchy
  print('Ship children:');
  for (final child in world.getChildren(ship.entity)) {
    final turret = world.get<Turret>(child);
    final pos = world.get<Position>(child);
    print('  - ${turret?.type} at local position $pos');
  }

  print('\nTurret parent check:');
  print('  Left turret parent: ${world.getParent(leftTurret.entity)}');
  print('  Right turret parent: ${world.getParent(rightTurret.entity)}');
  print('  Ship is root: ${world.root(leftTurret.entity) == ship.entity}');

  print('');

  // ============================================
  // 3. CHANGE DETECTION - Track modifications
  // ============================================
  print('--- 3. Change Detection Demo ---\n');

  // Advance tick to start fresh
  world.advanceTick();

  // Modify the ship's health - triggers onChange observer
  print('Damaging spaceship...');
  final health = world.get<Health>(ship.entity)!;
  health.damage(25);
  world.insert(ship.entity, health); // Re-insert to trigger change detection

  print('');

  // Query for changed health components
  print('Entities with changed Health this tick:');
  for (final (entity, h)
      in world.query1<Health>(filter: Changed<Health>()).iter()) {
    print('  Entity $entity: ${h.current}/${h.max}');
  }

  print('');

  // ============================================
  // 4. STATES - Game state management
  // ============================================
  print('--- 4. States Demo ---\n');

  // Create app with states
  final app = App()
      .addState<GameState>(GameState.loading)
      .insertResource(Score(0))
      .insertResource(GameTime(0.0));

  // Add state transition handlers
  app.addSystem(FunctionSystem(
    'onEnterPlaying',
    runIf: OnEnterState<GameState>(GameState.playing).condition,
    run: (w) {
      print('  [State] Entered PLAYING state - game started!');
      w.insertResource(GameTime(0.0));
    },
  ));

  app.addSystem(FunctionSystem(
    'onEnterPaused',
    runIf: OnEnterState<GameState>(GameState.paused).condition,
    run: (w) {
      print('  [State] Entered PAUSED state');
    },
  ));

  app.addSystem(FunctionSystem(
    'onExitPaused',
    runIf: OnExitState<GameState>(GameState.paused).condition,
    run: (w) {
      print('  [State] Exited PAUSED state - resuming!');
    },
  ));

  // Systems that only run in playing state
  app.addSystemInState(
    FunctionSystem('gameTime', run: (w) {
      final time = w.getResource<GameTime>()!;
      time.elapsed += 0.016; // ~60 FPS
    }),
    GameState.playing,
  );

  app.addSystemInState(
    FunctionSystem('scoreSystem', run: (w) {
      final score = w.getResource<Score>()!;
      score.value += 10;
    }),
    GameState.playing,
  );

  print('Current state: ${app.world.getResource<State<GameState>>()?.current}');

  // Transition to playing
  print('\nTransitioning to PLAYING...');
  app.world.getResource<State<GameState>>()?.set(GameState.playing);
  await app.tick();

  print('Running 3 ticks in PLAYING state...');
  for (var i = 0; i < 3; i++) {
    await app.tick();
  }
  print('  Score: ${app.world.getResource<Score>()?.value}');
  print(
      '  Time: ${app.world.getResource<GameTime>()?.elapsed.toStringAsFixed(3)}s');

  // Pause
  print('\nTransitioning to PAUSED...');
  app.world.getResource<State<GameState>>()?.set(GameState.paused);
  await app.tick();

  print('Running 3 ticks in PAUSED state (score should NOT change)...');
  final scoreBefore = app.world.getResource<Score>()?.value;
  for (var i = 0; i < 3; i++) {
    await app.tick();
  }
  print(
      '  Score before: $scoreBefore, after: ${app.world.getResource<Score>()?.value}');

  // Resume
  print('\nTransitioning back to PLAYING...');
  app.world.getResource<State<GameState>>()?.set(GameState.playing);
  await app.tick();

  print('');

  // ============================================
  // 5. SYSTEM SETS - Group and configure systems
  // ============================================
  print('--- 5. System Sets Demo ---\n');

  final app2 = App();
  final executionOrder = <String>[];

  // Configure system sets with ordering
  app2
      .configureSet('input', (set) => set)
      .configureSet('physics', (set) => set.after('input').before('render'))
      .configureSet('render', (set) => set);

  // Add systems to sets
  app2.addSystemToSet(
    FunctionSystem('inputHandler', run: (w) {
      executionOrder.add('input');
    }),
    'input',
  );

  app2.addSystemToSet(
    FunctionSystem('movement', run: (w) {
      executionOrder.add('physics:movement');
    }),
    'physics',
  );

  app2.addSystemToSet(
    FunctionSystem('collision', run: (w) {
      executionOrder.add('physics:collision');
    }),
    'physics',
  );

  app2.addSystemToSet(
    FunctionSystem('draw', run: (w) {
      executionOrder.add('render');
    }),
    'render',
  );

  await app2.tick();

  print('System execution order:');
  for (var i = 0; i < executionOrder.length; i++) {
    print('  ${i + 1}. ${executionOrder[i]}');
  }

  print('');

  // ============================================
  // 6. RUN CONDITIONS - Conditional execution
  // ============================================
  print('--- 6. Run Conditions Demo ---\n');

  final app3 = App().insertResource(Score(0));

  var conditionalRuns = 0;

  // System that only runs when score > 50
  app3.addSystem(FunctionSystem(
    'incrementScore',
    run: (w) {
      final score = w.getResource<Score>()!;
      score.value += 20;
    },
  ));

  app3.addSystem(FunctionSystem(
    'highScoreBonus',
    runIf: RunConditions.resource<Score>((s) => s.value > 50),
    run: (w) {
      conditionalRuns++;
      print('  [Condition] High score bonus triggered! (score > 50)');
    },
  ));

  print('Running ticks with conditional system...');
  for (var i = 1; i <= 5; i++) {
    final score = app3.world.getResource<Score>()!.value;
    print('  Tick $i: score = $score');
    await app3.tick();
  }
  print('Conditional system ran $conditionalRuns times');

  print('');

  // ============================================
  // 7. HIERARCHY DESPAWN - Recursive cleanup
  // ============================================
  print('--- 7. Recursive Despawn Demo ---\n');

  print('Entity count before despawn: ${world.entityCount}');
  print('Despawning spaceship (and all attached turrets)...');

  world.despawnRecursive(ship.entity);

  print('Entity count after despawn: ${world.entityCount}');

  print('\n=== Advanced Example Complete ===');
}
