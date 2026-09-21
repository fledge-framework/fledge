import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TransitionFadeSystem emits TransitionCompleted when fade in ends', () {
    final world = World()
      ..registerEvent<TransitionCompleted>()
      ..insertResource(WallTime())
      ..insertResource(
        TransitionState(fadeDuration: 0.1)
          ..targetScene = 'level2'
          ..metadata = {'spawnX': 100}
          ..phase = TransitionPhase.fadeIn
          ..fadeProgress = 0.05,
      );

    world.getResource<WallTime>()!.delta = 0.2;

    const TransitionFadeSystem().run(world);
    world.updateEvents();

    final events = world.eventReader<TransitionCompleted>().read().toList();
    expect(events, hasLength(1));
    expect(events.single.scene, 'level2');
    expect(events.single.metadata, {'spawnX': 100});
    expect(world.getResource<TransitionState>()!.phase, TransitionPhase.idle);
  });

  test('TransitionFadeSystem does not emit while fade in is still running', () {
    final world = World()
      ..registerEvent<TransitionCompleted>()
      ..insertResource(WallTime())
      ..insertResource(
        TransitionState(fadeDuration: 1.0)
          ..targetScene = 'level2'
          ..phase = TransitionPhase.fadeIn
          ..fadeProgress = 1.0,
      );

    world.getResource<WallTime>()!.delta = 0.1;

    const TransitionFadeSystem().run(world);
    world.updateEvents();

    expect(world.eventReader<TransitionCompleted>().read(), isEmpty);
    expect(world.getResource<TransitionState>()!.phase, TransitionPhase.fadeIn);
  });
}
