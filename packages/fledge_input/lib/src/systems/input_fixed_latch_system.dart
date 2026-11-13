import 'package:fledge_ecs/fledge_ecs.dart';

import '../action/action_state.dart';

/// Clears the presses and releases held for the fixed step
/// ([ActionState.fixedJustPressed]) once a fixed step has run, so each one
/// is seen by exactly one fixed step.
///
/// Runs in `Schedules.fixedLast`. Fixed-step systems that read
/// `fixedJustPressed` run earlier in the same fixed step (`fixedFirst` to
/// `fixedPostUpdate`), so they need no ordering against it.
class InputFixedLatchSystem implements System {
  /// The `SystemMeta.name` of [InputFixedLatchSystem]. Systems in
  /// `Schedules.fixedLast` that read `fixedJustPressed` order `before:` it.
  static const String systemName = 'inputFixedLatch';

  @override
  SystemMeta get meta =>
      const SystemMeta(name: systemName, resourceWrites: {ActionState});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<ActionState>()?.clearFixedLatch();
    return Future.value();
  }
}
