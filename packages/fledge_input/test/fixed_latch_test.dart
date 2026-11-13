import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter_test/flutter_test.dart';

const _jump = ActionId('jump');

/// Counts, in the fixed step, how often [_jump] was just pressed.
class _CountJumps implements System {
  int jumps = 0;
  int steps = 0;

  @override
  SystemMeta get meta =>
      const SystemMeta(name: 'count_jumps', resourceReads: {ActionState});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    steps++;
    if (world.getResource<ActionState>()!.fixedJustPressed(_jump)) jumps++;
    return Future.value();
  }
}

void main() {
  group('ActionState fixed latch', () {
    test('a press is held until cleared, a release too', () {
      final state = ActionState()
        ..set(_jump, const ButtonValue(ButtonPhase.justPressed));
      expect(state.fixedJustPressed(_jump), isTrue);
      // Next frame: held. The latch keeps the press for the fixed step.
      state
        ..clear()
        ..set(_jump, const ButtonValue(ButtonPhase.held));
      expect(state.justPressed(_jump), isFalse);
      expect(state.fixedJustPressed(_jump), isTrue);
      state.clearFixedLatch();
      expect(state.fixedJustPressed(_jump), isFalse);
      state.set(_jump, const ButtonValue(ButtonPhase.justReleased));
      expect(state.fixedJustReleased(_jump), isTrue);
    });
  });

  group('InputFixedLatchSystem', () {
    late App app;
    late WallTime time;
    late _CountJumps counter;
    late double step;

    setUp(() {
      time = WallTime();
      counter = _CountJumps();
      app = App()
        ..insertResource(ActionState())
        ..insertResource(time)
        ..addSystem(counter, schedule: Schedules.fixedUpdate)
        ..addSystem(InputFixedLatchSystem(), schedule: Schedules.fixedLast);
      step = app.world.getResource<FixedTimestep>()!.stepSeconds;
    });

    /// One frame lasting [steps] fixed steps, pressing jump if [press].
    Future<void> frame(double steps, {bool press = false}) async {
      final state = app.world.getResource<ActionState>()!..clear();
      state.set(
        _jump,
        ButtonValue(press ? ButtonPhase.justPressed : ButtonPhase.up),
      );
      time.delta = steps * step;
      await app.tick();
    }

    test('one fixed step per frame sees each press once', () async {
      await frame(1, press: true);
      await frame(1);
      expect(counter.steps, 2);
      expect(counter.jumps, 1);
    });

    test('a frame with no fixed step keeps the press for the next', () async {
      await frame(0, press: true);
      expect(counter.steps, 0);
      await frame(1);
      expect(counter.jumps, 1);
    });

    test('a frame with two fixed steps sees the press only once', () async {
      await frame(2, press: true);
      expect(counter.steps, 2);
      expect(counter.jumps, 1);
    });

    test('the plugin installs it, without ordering ambiguities', () {
      final app = App()
        ..addPlugin(
          InputPlugin.simple(
            context: InputContext(name: 'a', map: InputMap.builder().build()),
          ),
        );
      expect(app.checkScheduleOrdering(), isEmpty);
    });
  });
}
