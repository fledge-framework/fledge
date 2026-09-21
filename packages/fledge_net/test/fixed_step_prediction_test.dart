import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Records the number of times [_PredictionSpy] ran during a tick.
class _RunCounter {
  int value = 0;
}

/// Stand-in for a game's own prediction system, registered onto
/// [Schedules.fixedUpdate] to confirm the netcode tick cadence.
class _PredictionSpy implements System {
  @override
  final SystemMeta meta = SystemMeta(
    name: 'net:predictionSpy',
    resourceWrites: {_RunCounter},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    world.getResource<_RunCounter>()!.value++;
  }
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Prediction runs on Schedules.fixedUpdate', () {
    test(
      'a ~300ms tick with a 100ms step yields exactly 3 fixed-update runs',
      () async {
        final counter = _RunCounter();

        final app = App()
          ..insertResource(
            FixedTimestep(
              stepDuration: const Duration(milliseconds: 100),
              maxCatchupSteps: 10,
            ),
          )
          ..insertResource(counter)
          // Pin the frame delta at just over 300ms — App.tick prefers
          // WallTime.delta when the WallTime resource is present, so this
          // is deterministic and does not depend on wall-clock timing.
          // The extra millisecond guards against IEEE-754 rounding:
          // repeated subtraction of 0.1 from exactly 0.3 leaves a
          // slightly-negative residual, which would give only 2
          // iterations instead of 3.
          ..insertResource(WallTime()..delta = 0.301)
          ..addPlugin(
            NetworkPlugin(config: NetworkConfig(mode: NetworkMode.client)),
          )
          ..addSystem(_PredictionSpy(), schedule: Schedules.fixedUpdate);

        await app.tick();

        expect(
          counter.value,
          equals(3),
          reason:
              '~300ms of frame delta / 100ms fixed step should drive '
              'exactly 3 fixed iterations, so the prediction system '
              'should have run 3 times.',
        );
      },
    );

    test('prediction on Schedules.update runs once per frame regardless of '
        'FixedTimestep — sanity check that fixedUpdate is the correct '
        'schedule for prediction', () async {
      final fixedCounter = _RunCounter();
      final updateCounter = _RunCounter();

      final app = App()
        ..insertResource(
          FixedTimestep(
            stepDuration: const Duration(milliseconds: 100),
            maxCatchupSteps: 10,
          ),
        )
        ..insertResource(WallTime()..delta = 0.301)
        ..addPlugin(
          NetworkPlugin(config: NetworkConfig(mode: NetworkMode.client)),
        );

      // Two counter resources, each with a dedicated spy so their
      // resource writes don't conflict.
      app.world.insertResource<_FixedCounter>(_FixedCounter(fixedCounter));
      app.world.insertResource<_UpdateCounter>(_UpdateCounter(updateCounter));

      app
        ..addSystem(_FixedSpy(), schedule: Schedules.fixedUpdate)
        ..addSystem(_UpdateSpy(), schedule: Schedules.update);

      await app.tick();

      // fixedUpdate fires per fixed step (3 times), while update fires
      // once per App.tick — this is exactly the reason prediction lives
      // on fixedUpdate rather than update.
      expect(fixedCounter.value, equals(3));
      expect(updateCounter.value, equals(1));
    });
  });
}

class _FixedCounter {
  final _RunCounter counter;
  _FixedCounter(this.counter);
}

class _UpdateCounter {
  final _RunCounter counter;
  _UpdateCounter(this.counter);
}

class _FixedSpy implements System {
  @override
  final SystemMeta meta = SystemMeta(
    name: 'net:fixedSpy',
    resourceWrites: {_FixedCounter},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    world.getResource<_FixedCounter>()!.counter.value++;
  }
}

class _UpdateSpy implements System {
  @override
  final SystemMeta meta = SystemMeta(
    name: 'net:updateSpy',
    resourceWrites: {_UpdateCounter},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    world.getResource<_UpdateCounter>()!.counter.value++;
  }
}
