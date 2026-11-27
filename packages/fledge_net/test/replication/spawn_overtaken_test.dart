// A snapshot chunk can overtake the reliable spawn of an entity it lists
// (the spawn lost and resent). The client must not acknowledge state it
// dropped, or the host takes it as delivered and never sends it again.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('a change made just after a spawn reaches a lossy client', () async {
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final bed = NetTestbed(
        latency: const Duration(milliseconds: 30),
        jitter: const Duration(milliseconds: 60),
        packetLoss: 0.3,
        seed: seed,
      );
      final host = await bed.startHost();
      final client = await bed.addClient();
      await bed.frames(60);
      final entities = [
        for (var i = 0; i < 6; i++)
          host.world.spawn()
            ..insert(Replicated())
            ..insert(Pos(i * 3.0, 9))
            ..insert(const Health(1)),
      ].map((e) => e.entity).toList();
      await bed.frames(2);
      for (final e in entities) {
        host.world.insert(e, const Health(2));
      }
      await bed.frames(300);
      for (final e in entities) {
        final mirror = entityFor(client, netIdOf(host, e));
        expect(mirror, isNotNull, reason: 'seed $seed');
        expect(client.world.get<Health>(mirror!)!.hp, 2, reason: 'seed $seed');
      }
      await bed.dispose();
    }
  });
}
