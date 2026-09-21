import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

/// Minimal fledge_net example.
///
/// Wires [NetworkPlugin] in host mode — that installs the
/// [NetworkConfig], [NetworkTick] and [NetworkEntityRegistry]
/// resources without opening a real UDP socket. Also shows the
/// [Transform2DNetworkState] serialize / deserialize round-trip that
/// backs the built-in transform sync (three float32s on the wire).
///
/// For a real host / client setup see `NetworkHost` and
/// `NetworkClient`; those need a runtime and a peer, which is out of
/// scope for a compile-only example.
void main() async {
  final app = App()
    ..addPlugin(NetworkPlugin(
      config: NetworkConfig(
        mode: NetworkMode.host,
        tickRate: 60,
        syncRate: 20,
      ),
    ));

  // Advance the network clock a tick — game systems read
  // `NetworkTick.serverTick` to stamp outgoing packets.
  final tick = app.world.getResource<NetworkTick>()!;
  tick.advance(60);

  // Serialize a transform onto the wire, then read it back.
  final snapshot = Transform2DNetworkState()
    ..x = 12.5
    ..y = -8.0
    ..rotation = 1.57;

  final builder = PacketBuilder();
  snapshot.serialize(builder);
  final wire = builder.build();

  final decoded = Transform2DNetworkState()..deserialize(PacketReader(wire));
  assert(decoded.x == snapshot.x);
  assert(decoded.y == snapshot.y);
  assert(decoded.rotation == snapshot.rotation);

  await app.tick();
}
