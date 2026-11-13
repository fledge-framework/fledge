// NetworkIdentity.hasAuthority means "the local instance owns this
// entity", on the host as on clients.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('hasAuthority is local ownership on host and client, and follows '
      'ownership changes', () async {
    final bed = NetTestbed();
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(10);

    final scene = host.world.getResource<HostScene>()!;
    final vehicle = scene.vehicle!;
    final avatar = scene.avatars.values.single;
    NetworkIdentity on(App app, Entity hostEntity) => app.world
        .get<NetworkIdentity>(entityFor(app, netIdOf(host, hostEntity))!)!;

    // Host-owned vehicle: the host has authority, the client does not.
    expect(on(host, vehicle).hasAuthority, isTrue);
    expect(on(client, vehicle).hasAuthority, isFalse);
    // Client-owned avatar: the client has authority, the host does not.
    expect(on(host, avatar).hasAuthority, isFalse);
    expect(on(host, avatar).localPeerId, 0);
    expect(on(client, avatar).hasAuthority, isTrue);

    // Host hands the vehicle to the client.
    final peerId = NetTestbed.session(client).localPeerId!;
    on(host, vehicle).ownerId = peerId;
    await bed.frames(10);
    expect(on(host, vehicle).hasAuthority, isFalse);
    expect(on(client, vehicle).hasAuthority, isTrue);

    await bed.dispose();
  });
}
