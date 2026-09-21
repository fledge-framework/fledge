import 'package:fledge_ecs/fledge_ecs.dart';

import 'previous_transform.dart';
import 'transform2d.dart';

/// Copies `Transform2D` into `PreviousTransform2D` at the start of
/// every fixed step so extraction can interpolate the render position
/// between the previous and current tick.
///
/// Register in `Schedules.fixedFirst` — before physics resolution and
/// velocity integration — so the snapshot captures the *pre-move*
/// transform for the step.
class SnapshotPreviousTransformSystem implements System {
  const SnapshotPreviousTransformSystem();

  @override
  SystemMeta get meta => SystemMeta(
    name: 'snapshot_previous_transform',
    reads: {ComponentId.of<Transform2D>()},
    writes: {ComponentId.of<PreviousTransform2D>()},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    for (final (_, transform, previous)
        in world.query2<Transform2D, PreviousTransform2D>().iter()) {
      previous.copyFrom(transform);
    }
  }
}
