// Test fixtures for `fledge_ecs_generator`'s query intent inference.
//
// These `@system` functions are not used at runtime by `basic_ecs`; they exist
// so that `melos run build_runner` produces a golden `.g.dart` that the
// generator tests over in `packages/fledge_ecs_generator/test/` can read from
// disk and assert against.
//
// Why here? The generator package itself intentionally does not depend on
// `fledge_ecs` (see `packages/fledge_ecs_generator/CLAUDE.md`), which means it
// cannot host a fixture that references real `QueryN` / `QueryMutN` types.
// `basic_ecs` is already wired into the workspace's build_runner pipeline and
// depends on `fledge_ecs`, so we piggy-back on its regeneration.

import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';

part 'query_marker_fixtures.g.dart';

/// Query1<Position> — the generator should mark Position as a READ and set
/// up the parameter using `world.query1<Position>()`.
@system
void readOnePositions(Query1<Position> q) {
  for (final _ in q.iter()) {}
}

/// Query2<Position, Velocity> — both components should land in `reads`.
@system
void readPositionsAndVelocities(Query2<Position, Velocity> q) {
  for (final _ in q.iter()) {}
}

/// QueryMut2<Position, Velocity> — both components should land in `writes`.
@system
void writePositionsAndVelocities(QueryMut2<Position, Velocity> q) {
  for (final _ in q.iter()) {}
}

/// Mixed reads/writes are supported across parameters (never within one
/// parameter). Here Position is read while Velocity is written.
@system
void readPositionsWriteVelocities(Query1<Position> r, QueryMut1<Velocity> w) {
  for (final _ in r.iter()) {}
  for (final _ in w.iter()) {}
}
