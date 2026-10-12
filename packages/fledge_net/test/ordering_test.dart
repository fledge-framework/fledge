import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import 'support/replication_harness.dart';

/// Velocity stand-in for fledge_physics.
class _Velocity {}

/// A system with an explicit meta (stand-in for a real plugin system).
class _StandIn implements System {
  @override
  final SystemMeta meta;

  _StandIn(this.meta);

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) => Future.value();
}

/// Mirrors the metas of PhysicsPlugin(PhysicsMode.fixed), RenderPlugin
/// extraction and TransformPropagateSystem (in Schedules.preUpdate), with
/// Pos / GlobalPos standing in for Transform2D / GlobalTransform2D.
///
/// fledge_net is pure Dart and cannot depend on those Flutter packages;
/// the same composition with the real plugins (and a replicated
/// Transform2D) is covered by integration/all_plugins.
void _addEngineStandIns(App app) {
  final pos = ComponentId.of<Pos>();
  final vel = ComponentId.of<_Velocity>();
  app
    ..addSystem(
      _StandIn(
        SystemMeta(name: 'collision_resolution', reads: {pos}, writes: {vel}),
      ),
      schedule: Schedules.fixedUpdate,
    )
    ..addSystem(
      _StandIn(
        SystemMeta(
          name: 'velocity_integration',
          reads: {vel},
          writes: {pos},
          after: const ['collision_resolution'],
        ),
      ),
      schedule: Schedules.fixedUpdate,
    )
    ..addSystem(
      _StandIn(
        SystemMeta(
          name: 'collision_detection',
          reads: {pos},
          after: const ['collision_resolution', 'velocity_integration'],
        ),
      ),
      schedule: Schedules.fixedUpdate,
    )
    ..addSystem(GlobalPosPropagateSystem(), schedule: Schedules.preUpdate)
    ..addSystem(
      _StandIn(
        SystemMeta(
          name: 'render_extract',
          reads: {ComponentId.of<GlobalPos>()},
        ),
      ),
      schedule: Schedules.extract,
    );
}

void main() {
  setUp(ComponentId.resetRegistry);

  void expectNoAmbiguities(App app) {
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  }

  // The plugin registers its systems in every mode (they are no-ops while
  // no session is active), so every mode must be ambiguity-free.
  for (final mode in NetworkMode.values) {
    test('NetworkPlugin (${mode.name}) has no ordering ambiguities', () {
      expectNoAmbiguities(
        App()..addPlugin(NetworkPlugin(config: NetworkConfig(mode: mode))),
      );
    });

    test('NetworkPlugin (${mode.name}) with a full registry', () {
      expectNoAmbiguities(
        App()..addPlugin(
          NetworkPlugin(
            config: NetworkConfig(mode: mode),
            replication: buildRegistry(),
          ),
        ),
      );
    });

    for (final reversed in [false, true]) {
      test('NetworkPlugin (${mode.name}) composed with physics/render/'
          'propagate stand-ins (${reversed ? 'net last' : 'net first'})', () {
        final app = App();
        void net() => app.addPlugin(
          NetworkPlugin(
            config: NetworkConfig(mode: mode),
            replication: buildRegistry(),
          ),
        );
        if (!reversed) net();
        _addEngineStandIns(app);
        if (reversed) net();
        // A game system submitting local input joins NetSets.localInput.
        app.addSystem(SubmitInputSystem(), schedule: Schedules.fixedPreUpdate);
        expectNoAmbiguities(app);
      });
    }
  }

  test('systems are registered and no-ops offline', () async {
    final app = App()
      ..insertResource(WallTime()..delta = 0.02)
      ..insertResource(NetworkConfig(tickRate: 50).fixedTimestep())
      ..addPlugin(
        NetworkPlugin(
          config: NetworkConfig(tickRate: 50),
          replication: buildRegistry(),
        ),
      );
    final replicated = app.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(1, 2));
    for (var i = 0; i < 5; i++) {
      await app.tick();
    }
    expect(app.scheduler.systemCount, 7);
    expect(app.world.has<NetworkIdentity>(replicated.entity), isFalse);
    expect(app.world.getResource<NetworkTick>()!.serverTick, 0);
    expect(app.world.getResource<NetworkSession>()!.role, NetworkRole.offline);
  });
}
