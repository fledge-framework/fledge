import 'package:fledge_ecs/fledge_ecs.dart';

import '../context/context_registry.dart';

/// System that updates the active input context based on game state.
///
/// This is a generic system factory - you create one for each state type
/// you want to track.
class ContextUpdateSystem<S extends Enum> implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'contextUpdate<$S>',
        resourceReads: {State<S>},
        resourceWrites: {InputContextRegistry},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final state = world.getResource<State<S>>();
    final registry = world.getResource<InputContextRegistry>();

    if (state != null && registry != null) {
      registry.updateFromState(state.current);
    }

    return Future.value();
  }
}
