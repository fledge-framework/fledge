import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('smoke: one client sees the vehicle and its avatar', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(30);

    final hostScene = host.world.getResource<HostScene>()!;
    final peerId = NetTestbed.session(client).localPeerId!;
    expect(hostScene.avatars.keys, [peerId]);

    final vehicleNetId = netIdOf(host, hostScene.vehicle!);
    final avatarNetId = netIdOf(host, hostScene.avatars[peerId]!);
    final cVehicle = entityFor(client, vehicleNetId);
    final cAvatar = entityFor(client, avatarNetId);
    expect(cVehicle, isNotNull);
    expect(cAvatar, isNotNull);
    expect(client.world.getParent(cAvatar!), cVehicle);
    expect(client.world.get<NetworkIdentity>(cAvatar)!.ownerId, peerId);
    expect(client.world.get<Health>(cVehicle!)!.hp, 500);
    await bed.dispose();
  });
}
