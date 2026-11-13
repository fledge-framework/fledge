// Snapshots carry only what changed since each client's acknowledged copy.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  /// Counts the host's bytes on the wire while [run] runs.
  Future<int> hostBytesDuring(
    NetTestbed bed,
    Future<void> Function() run,
  ) async {
    var bytes = 0;
    bed.net.filter = (datagram) {
      if (datagram.source.port == 7777) bytes += datagram.data.length;
      return true;
    };
    await run();
    bed.net.filter = null;
    return bytes;
  }

  test('2000 static entities cost next to nothing once acknowledged', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    final host = await bed.startHost(vehicle: false);
    final client = await bed.addClient();
    for (var i = 0; i < 2000; i++) {
      host.world.spawn()
        ..insert(Replicated())
        ..insert(Pos(i.toDouble(), 0))
        ..insert(Health(i));
    }
    await bed.frames(150); // the join streams in
    expect(
      client.world.query1<NetworkIdentity>().iter().length,
      greaterThanOrEqualTo(2000),
    );
    final bytes = await hostBytesDuring(
      bed,
      () => bed.frames(bed.tickRate * 2),
    );
    // About one tiny chunk per snapshot: well under 1 KiB/s.
    expect(bytes / 2, lessThan(1024));
    await bed.dispose();
  });

  test('a removed component is removed on the client', () async {
    final bed = NetTestbed();
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(20);
    final vehicle = host.world.getResource<HostScene>()!.vehicle!;
    final mirror = entityFor(client, netIdOf(host, vehicle))!;
    expect(client.world.has<Health>(mirror), isTrue);
    host.world.remove<Health>(vehicle);
    await bed.frames(20);
    expect(client.world.has<Health>(mirror), isFalse);
    expect(client.world.has<Pos>(mirror), isTrue);
    await bed.dispose();
  });

  test('a mover that stops comes to rest where it stopped', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    final host = await bed.startHost(vehicle: false);
    final client = await bed.addClient();
    final mover =
        (host.world.spawn()
              ..insert(Replicated())
              ..insert(const Pos(0, 0)))
            .entity;
    await bed.frames(20);
    for (var i = 1; i <= 30; i++) {
      host.world.insert(mover, Pos(i * 2.0, 0));
      await bed.frame();
    }
    // Stopped at x = 60; give interpolation time to catch up and settle.
    await bed.frames(bed.tickRate);
    final mirror = entityFor(client, netIdOf(host, mover))!;
    expect(client.world.get<Pos>(mirror)!.x, closeTo(60, 0.001));
    await bed.dispose();
  });

  test('values converge under loss and jitter', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 30),
      jitter: const Duration(milliseconds: 20),
      packetLoss: 0.15,
      seed: 3,
    );
    final host = await bed.startHost(vehicle: false);
    final client = await bed.addClient();
    final things = [
      for (var i = 0; i < 50; i++)
        (host.world.spawn()
              ..insert(Replicated())
              ..insert(Health(i)))
            .entity,
    ];
    for (var round = 0; round < 10; round++) {
      for (var i = 0; i < things.length; i++) {
        if ((i + round) % 3 == 0) {
          host.world.insert(things[i], Health(round * 100 + i));
        }
      }
      await bed.frames(5);
    }
    await bed.frames(200);
    for (final thing in things) {
      final mirror = entityFor(client, netIdOf(host, thing))!;
      expect(
        client.world.get<Health>(mirror)!.hp,
        host.world.get<Health>(thing)!.hp,
      );
    }
    await bed.dispose();
  });
}
