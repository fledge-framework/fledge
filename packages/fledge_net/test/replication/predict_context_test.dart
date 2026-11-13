// Prediction steps that read the world (stepWith / PredictContext).
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// Static level data both sides have: nobody may pass x = [maxX].
class Wall {
  final double maxX;
  const Wall(this.maxX);
}

void main() {
  setUp(ComponentId.resetRegistry);

  final contexts = <PredictContext>[];

  ReplicationRegistry registry() =>
      buildRegistry(predict: false)..predict<Pos, Move>(
        stepWith: (s, m, context) {
          contexts.add(context);
          final wall = context.world.getResource<Wall>()!;
          final next = stepPos(s, m, context.dt);
          return Pos(next.x > wall.maxX ? wall.maxX : next.x, next.y);
        },
        error: posError,
      );

  test('a step that reads the world predicts without corrections', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 60),
      registry: registry,
    );
    final host = await bed.startHost();
    host.world.insertResource(const Wall(20));
    final client = await bed.addClient();
    client.world.insertResource(const Wall(20));
    await bed.frames(30);
    final peerId = NetTestbed.session(client).localPeerId!;
    final hostAvatar = host.world.getResource<HostScene>()!.avatars[peerId]!;
    final clientAvatar = entityFor(client, netIdOf(host, hostAvatar))!;

    client.world.getResource<Driving>()!.move = const Move(1, 0);
    await bed.frames(80); // 80 ticks at 1 unit a tick: well past the wall
    client.world.getResource<Driving>()!.move = null;
    await bed.frames(40);

    expect(NetTestbed.session(client).stats.corrections, 0);
    // Avatars are parented to the vehicle at x 0, so local x is the wall.
    expect(client.world.get<Pos>(clientAvatar)!.x, 20);
    expect(host.world.get<Pos>(hostAvatar)!.x, 20);
    expect(contexts.map((c) => c.entity).toSet(), {hostAvatar, clientAvatar});
    expect(contexts.every((c) => c.dt == 1 / bed.tickRate), isTrue);
    expect(contexts.any((c) => c.replaying), isFalse);
    await bed.dispose();
  });

  test('exactly one of step and stepWith', () {
    final r = ReplicationRegistry()
      ..component<Pos>('pos', posCodec)
      ..input<Move>(moveCodec);
    expect(() => r.predict<Pos, Move>(error: posError), throwsArgumentError);
    expect(
      () => r.predict<Pos, Move>(
        step: stepPos,
        stepWith: (s, m, c) => s,
        error: posError,
      ),
      throwsArgumentError,
    );
  });
}
