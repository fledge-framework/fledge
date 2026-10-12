import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

/// Replicated position.
class Position {
  final double x, y;
  const Position(this.x, this.y);
}

/// Movement input.
class Move {
  final double dx, dy;
  const Move(this.dx, this.dy);
}

/// Host and client must build identical registries.
ReplicationRegistry buildReplication() => ReplicationRegistry()
  ..component<Position>(
    'position',
    NetCodec<Position>.of(
      encode: (p, out) => out
        ..writeFloat32(p.x)
        ..writeFloat32(p.y),
      decode: (r) => Position(r.readFloat32(), r.readFloat32()),
    ),
    interpolate: (a, b, t) =>
        Position(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t),
  )
  ..input<Move>(
    NetCodec<Move>.of(
      encode: (m, out) => out
        ..writeFloat32(m.dx)
        ..writeFloat32(m.dy),
      decode: (r) => Move(r.readFloat32(), r.readFloat32()),
    ),
  )
  ..predict<Position, Move>(
    step: (s, m, dt) => Position(s.x + m.dx * 100 * dt, s.y + m.dy * 100 * dt),
    error: (a, b) => (a.x - b.x).abs() + (a.y - b.y).abs(),
  );

/// A host and a client in one process over an in-memory network. Swap
/// `transportFactory` for the default (`UdpTransport`) to play over UDP.
Future<void> main() async {
  final net = LoopbackNetwork();

  App makeApp() {
    final config = NetworkConfig(tickRate: 60, syncRate: 20);
    return App()
      ..insertResource(config.fixedTimestep())
      ..addPlugin(
        NetworkPlugin(
          config: config,
          replication: buildReplication(),
          transportFactory: net.createTransport,
        ),
      );
  }

  final host = makeApp();
  final client = makeApp();
  final hostSession = host.world.getResource<NetworkSession>()!;
  final clientSession = client.world.getResource<NetworkSession>()!;

  await hostSession.host(port: 7777);
  final crate = host.world.spawn()
    ..insert(Replicated())
    ..insert(const Position(10, 20));

  final joining = clientSession.join('127.0.0.1', 7777);
  for (var frame = 0; frame < 60; frame++) {
    await host.tick();
    await client.tick();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  print('joined: ${await joining}, ready: ${clientSession.isReady}');

  final netId = host.world.getResource<NetworkEntityRegistry>()!.getNetId(
    crate.entity,
  )!;
  final mirror = client.world.getResource<NetworkEntityRegistry>()!.getEntity(
    netId,
  );
  final p = mirror == null ? null : client.world.get<Position>(mirror);
  print('client sees crate $netId at (${p?.x}, ${p?.y})');

  await clientSession.close();
  await hostSession.close();
}
