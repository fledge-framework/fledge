// An entity whose replicated state does not fit one message must not
// stop replication of everything else.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/src/replication/wire.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// Replicated component of adjustable encoded size.
class Blob {
  final int size;

  const Blob(this.size);
}

final blobCodec = NetCodec<Blob>.of(
  encode: (b, out) => out.writeVarBytes(Uint8List(b.size)),
  decode: (r) => Blob(r.readVarBytes().length),
);

ReplicationRegistry _registry() =>
    buildRegistry()..component<Blob>('blob', blobCodec);

void main() {
  setUp(ComponentId.resetRegistry);

  test('maxEntityStateBytes fits a spawn message and a snapshot entry', () {
    // Spawn: kind + 3 varints + uint32 tick before the state.
    expect(
      20 + NetworkSession.maxEntityStateBytes,
      lessThanOrEqualTo(ReliableChannel.maxMessageBytes),
    );
    // Snapshot entry: netId varint + state, after header and count.
    expect(
      5 + NetworkSession.maxEntityStateBytes,
      lessThanOrEqualTo(Packet.maxPayloadBytes - SnapshotHeader.maxBytes - 5),
    );
  });

  test('an oversized entity is skipped; the rest keeps replicating, and it '
      'replicates once it fits', () async {
    final bed = NetTestbed(registry: _registry);
    final host = await bed.startHost();
    final client = await bed.addClient();
    final hostSession = NetTestbed.session(host);

    final big = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(1, 1))
      ..insert(const Blob(NetworkSession.maxEntityStateBytes * 2));
    await bed.frames(5);
    final small = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(2, 2));
    await bed.frames(20);

    final bigId = netIdOf(host, big.entity);
    final smallId = netIdOf(host, small.entity);
    expect(entityFor(client, bigId), isNull, reason: 'too big to replicate');
    final mirror = entityFor(client, smallId);
    expect(mirror, isNotNull, reason: 'replication is not wedged');
    expect(hostSession.stats.oversizedEntities, 1);

    // Snapshots keep flowing.
    host.world.insert(small.entity, const Pos(7, 7));
    await bed.frames(20);
    expect(client.world.get<Pos>(mirror!)!.x, closeTo(7, 1e-6));

    // Shrinks: replicated.
    host.world.insert(big.entity, const Blob(16));
    await bed.frames(20);
    final bigMirror = entityFor(client, bigId);
    expect(bigMirror, isNotNull);
    expect(client.world.get<Blob>(bigMirror!)!.size, 16);

    // Grows past the limit again: despawned on the client, still reported
    // only once.
    host.world.insert(
      big.entity,
      const Blob(NetworkSession.maxEntityStateBytes + 1),
    );
    await bed.frames(20);
    expect(entityFor(client, bigId), isNull);
    expect(entityFor(client, smallId), isNotNull);
    expect(hostSession.stats.oversizedEntities, 1);

    // The largest allowed state replicates.
    host.world.insert(
      big.entity,
      // varint length prefix (2 bytes) + mask/length framing (~4 bytes).
      const Blob(NetworkSession.maxEntityStateBytes - 16),
    );
    await bed.frames(20);
    expect(entityFor(client, bigId), isNotNull);

    await bed.dispose();
  });
}
