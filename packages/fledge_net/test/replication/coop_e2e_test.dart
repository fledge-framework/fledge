// Acceptance: 1 host + 3 clients over a manual LoopbackNetwork with
// 50-100 ms one-way latency (50 ms + up to 50 ms jitter) and 7% loss.
// The host owns a vehicle; each peer owns an avatar parented to it.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  NetTestbed lossyBed({int seed = 7}) => NetTestbed(
    latency: const Duration(milliseconds: 50),
    jitter: const Duration(milliseconds: 50),
    packetLoss: 0.07,
    seed: seed,
  );

  /// Every replicated host entity exists on [client] with the same
  /// position (within [tolerance]), parent and owner.
  void expectMirrors(App host, App client, {double tolerance = 0.01}) {
    final hostRegistry = host.world.getResource<NetworkEntityRegistry>()!;
    for (final hostEntity in hostRegistry.entities.toList()) {
      final netId = hostRegistry.getNetId(hostEntity)!;
      final mirror = entityFor(client, netId);
      expect(mirror, isNotNull, reason: 'netId $netId missing on client');
      final hp = host.world.get<Pos>(hostEntity)!;
      final cp = client.world.get<Pos>(mirror!)!;
      expect(
        posError(hp, cp),
        lessThan(tolerance),
        reason: 'netId $netId: host $hp client $cp',
      );

      final hostParent = host.world.getParent(hostEntity);
      final clientParent = client.world.getParent(mirror);
      if (hostParent == null) {
        expect(clientParent, isNull);
      } else {
        expect(clientParent, entityFor(client, netIdOf(host, hostParent)));
      }
      expect(
        client.world.get<NetworkIdentity>(mirror)!.ownerId,
        host.world.get<NetworkIdentity>(hostEntity)!.ownerId,
      );
      final hg = host.world.get<GlobalPos>(hostEntity)!;
      final cg = client.world.get<GlobalPos>(mirror)!;
      expect(
        (hg.x - cg.x).abs() + (hg.y - cg.y).abs(),
        lessThan(tolerance * 2),
      );
    }
  }

  test('3 clients receive vehicle + avatars, hierarchy correct, positions '
      'converge after motion stops', () async {
    final bed = lossyBed();
    final host = await bed.startHost();
    for (var i = 0; i < 3; i++) {
      await bed.addClient();
    }
    await bed.frames(40);

    final scene = host.world.getResource<HostScene>()!;
    expect(scene.avatars, hasLength(3));
    for (final client in bed.clients) {
      expect(NetTestbed.log(client).connected, hasLength(1));
    }

    // Drive: vehicle moves, every client steers its own avatar.
    scene.vehicleVx = 10;
    final moves = [const Move(1, 0), const Move(0, 1), const Move(-1, 0.5)];
    for (var i = 0; i < 3; i++) {
      bed.clients[i].world.getResource<Driving>()!.move = moves[i];
    }
    await bed.frames(150);

    // Hosts saw the inputs: every avatar moved in its own direction.
    for (var i = 0; i < 3; i++) {
      final peerId = NetTestbed.session(bed.clients[i]).localPeerId!;
      final p = host.world.get<Pos>(scene.avatars[peerId]!)!;
      final start = Pos(peerId * 2.0, 0);
      expect(p.x - start.x, closeTo(moves[i].dx * moveSpeed * 3, 30));
      expect(p.y - start.y, closeTo(moves[i].dy * moveSpeed * 3, 30));
    }

    // Stop everything and let the lossy link settle.
    scene.vehicleVx = 0;
    for (final c in bed.clients) {
      c.world.getResource<Driving>()!.move = null;
    }
    await bed.frames(150);

    expect(host.world.get<Pos>(scene.vehicle!)!.x, greaterThan(25));
    for (final client in bed.clients) {
      expectMirrors(host, client);
    }
    expect(bed.net.stats.dropped, greaterThan(0), reason: 'link was lossy');
    await bed.dispose();
  });

  test('late join receives the full current state', () async {
    final bed = lossyBed(seed: 11);
    final host = await bed.startHost();
    await bed.addClient();
    final scene = host.world.getResource<HostScene>()!;
    scene.vehicleVx = 5;
    // Extra host-owned state created before the late joiner arrives.
    for (var i = 0; i < 10; i++) {
      host.world.spawn()
        ..insert(Replicated())
        ..insert(Pos(i * 3.0, -4))
        ..insert(Health(i));
    }
    await bed.frames(100);
    scene.vehicleVx = 0;

    final late = await bed.addClient();
    await bed.frames(100);
    expectMirrors(host, late);
    expectMirrors(host, bed.clients.first);
    expect(
      late.world.getResource<NetworkEntityRegistry>()!.count,
      host.world.getResource<NetworkEntityRegistry>()!.count,
    );
    await bed.dispose();
  });
}
