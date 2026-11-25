// The per-client send budget, streaming joins, and who sees what.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// A big blob resource: many chunks of a kilobyte or so.
class Blob {
  final List<Uint8List> chunks = [
    for (var i = 0; i < 400; i++) Uint8List(1000)..fillRange(0, 1000, i % 251),
  ];
  int version = 1;
}

class BlobCodec extends ResourceCodec<Blob> {
  const BlobCodec();

  @override
  int chunkCount(Blob blob) => blob.chunks.length;

  @override
  int chunkVersion(Blob blob, int chunk) => blob.version;

  @override
  void encodeChunk(Blob blob, int chunk, PacketBuilder out) =>
      out.writeRawBytes(blob.chunks[chunk]);

  @override
  void decodeChunk(Blob blob, int chunk, PacketReader input) {
    final bytes = Uint8List(1000);
    for (var i = 0; i < 1000; i++) {
      bytes[i] = input.readByte();
    }
    blob.chunks[chunk] = bytes;
  }
}

/// Private state on a shared entity.
class Secret {
  final int code;
  const Secret(this.code);
}

final secretCodec = NetCodec<Secret>.of(
  encode: (s, out) => out.writeVarUint(s.code),
  decode: (r) => Secret(r.readVarUint()),
);

void main() {
  setUp(ComponentId.resetRegistry);

  /// Calls [add] with the size of every datagram the host sends.
  void countHostBytes(NetTestbed bed, void Function(int bytes) add) {
    bed.net.filter = (datagram) {
      if (datagram.source.port == 7777) add(datagram.data.length);
      return true;
    };
  }

  test('a big join stays within the send budget', () async {
    const budget = 16 * 1024;
    final bed = NetTestbed(
      config: () => NetworkConfig(sendBudgetBytesPerSecond: budget),
    );
    final host = await bed.startHost(vehicle: false);
    final client = await bed.addClient();
    for (var i = 0; i < 3000; i++) {
      host.world.spawn()
        ..insert(Replicated())
        ..insert(Pos(i.toDouble(), 0))
        ..insert(Health(i));
    }
    var bytes = 0;
    countHostBytes(bed, (n) => bytes += n);
    await bed.frames(bed.tickRate * 2);
    // Two seconds at 16 KiB/s, plus a little for packets started on the
    // last of the allowance.
    expect(bytes, lessThan(budget * 2 * 1.2));
    expect(bytes, greaterThan(budget));
    // And it all gets there in the end.
    bed.net.filter = null;
    await bed.runUntil(
      () => client.world.query1<NetworkIdentity>().iter().length >= 3000,
      maxFrames: bed.tickRate * 20,
      what: 'every entity spawned',
    );
    await bed.dispose();
  });

  test(
    'a join far bigger than the reliable window streams in, no kick',
    () async {
      final bed = NetTestbed();
      final host = await bed.startHost(vehicle: false);
      for (var i = 0; i < 17000; i++) {
        host.world.spawn()
          ..insert(Replicated())
          ..insert(Health(i));
      }
      await bed.frame();
      final client = await bed.addClient();
      await bed.runUntil(
        () => client.world.query1<NetworkIdentity>().iter().length >= 17000,
        maxFrames: bed.tickRate * 30,
        what: 'every entity spawned',
      );
      expect(NetTestbed.session(host).peerIds, hasLength(1));
      expect(NetTestbed.log(client).disconnected, isEmpty);
      await bed.dispose();
    },
  );

  test('owner-only entities reach their owner and nobody else', () async {
    final bed = NetTestbed();
    final host = await bed.startHost(vehicle: false);
    final a = await bed.addClient();
    final b = await bed.addClient();
    final aId = NetTestbed.session(a).localPeerId!;
    final secret =
        (host.world.spawn()
              ..insert(Replicated(owner: aId, ownerOnly: true))
              ..insert(const Health(42)))
            .entity;
    await bed.frames(20);
    final netId = netIdOf(host, secret);
    expect(entityFor(a, netId), isNotNull);
    expect(entityFor(b, netId), isNull);
    await bed.dispose();
  });

  test('a child of an owner-only parent stays private too', () async {
    final bed = NetTestbed();
    final host = await bed.startHost(vehicle: false);
    final a = await bed.addClient();
    final b = await bed.addClient();
    final aId = NetTestbed.session(a).localPeerId!;
    final chest =
        (host.world.spawn()
              ..insert(Replicated(owner: aId, ownerOnly: true))
              ..insert(const Health(1)))
            .entity;
    final item =
        (host.world.spawn()
              ..insert(Replicated())
              ..insert(const Health(2)))
            .entity;
    host.world.setParent(item, chest);
    await bed.frames(20);
    // The owner sees both; another player sees neither: the item doesn't
    // drag its private parent along.
    expect(entityFor(a, netIdOf(host, chest)), isNotNull);
    expect(entityFor(a, netIdOf(host, item)), isNotNull);
    expect(entityFor(b, netIdOf(host, chest)), isNull);
    expect(entityFor(b, netIdOf(host, item)), isNull);
    await bed.dispose();
  });

  test('an owner-only component reaches only the owner, and follows '
      'ownership', () async {
    final bed = NetTestbed(
      registry: () =>
          buildRegistry()
            ..component<Secret>('secret', secretCodec, ownerOnly: true),
    );
    final host = await bed.startHost(vehicle: false);
    final a = await bed.addClient();
    final b = await bed.addClient();
    final aId = NetTestbed.session(a).localPeerId!;
    final bId = NetTestbed.session(b).localPeerId!;
    final player =
        (host.world.spawn()
              ..insert(Replicated(owner: aId))
              ..insert(const Health(10))
              ..insert(const Secret(1234)))
            .entity;
    await bed.frames(20);
    final netId = netIdOf(host, player);
    // Both see the entity and its shared state; only the owner its secret.
    expect(a.world.get<Secret>(entityFor(a, netId)!)?.code, 1234);
    expect(b.world.get<Health>(entityFor(b, netId)!)?.hp, 10);
    expect(b.world.has<Secret>(entityFor(b, netId)!), isFalse);
    // Changes reach the owner only.
    host.world.insert(player, const Secret(99));
    await bed.frames(20);
    expect(a.world.get<Secret>(entityFor(a, netId)!)?.code, 99);
    expect(b.world.has<Secret>(entityFor(b, netId)!), isFalse);
    // Ownership moves: the secret moves with it.
    host.world.get<NetworkIdentity>(player)!.ownerId = bId;
    await bed.frames(20);
    expect(b.world.get<Secret>(entityFor(b, netId)!)?.code, 99);
    expect(a.world.has<Secret>(entityFor(a, netId)!), isFalse);
    expect(a.world.get<Health>(entityFor(a, netId)!)?.hp, 10);
    await bed.dispose();
  });

  test('a relevance rule hides entities from chosen clients', () async {
    late int hiddenFrom;
    final bed = NetTestbed(
      config: () => NetworkConfig(
        relevance: (world, entity, peer) =>
            peer != hiddenFrom || world.get<Health>(entity)?.hp != 7,
      ),
    );
    final host = await bed.startHost(vehicle: false);
    final a = await bed.addClient();
    final b = await bed.addClient();
    hiddenFrom = NetTestbed.session(b).localPeerId!;
    final seven =
        (host.world.spawn()
              ..insert(Replicated())
              ..insert(const Health(7)))
            .entity;
    await bed.frames(20);
    expect(entityFor(a, netIdOf(host, seven)), isNotNull);
    expect(entityFor(b, netIdOf(host, seven)), isNull);
    // When it stops matching, it appears.
    host.world.insert(seven, const Health(8));
    await bed.frames(20);
    expect(entityFor(b, netIdOf(host, seven)), isNotNull);
    await bed.dispose();
  });

  test('an RPC is not held up behind a resource download', () async {
    final bed = NetTestbed(
      registry: () =>
          buildRegistry()
            ..resource<Blob>('blob', const BlobCodec(), create: Blob.new),
    );
    final host = await bed.startHost(vehicle: false);
    host.world.insertResource(Blob());
    final client = await bed.addClient();
    // The 400 KB download is under way (several seconds at the budget).
    await bed.frames(5);
    NetTestbed.session(host).sendRpc(const Emote('hello'));
    await bed.frames(10);
    expect(NetTestbed.log(client).emotes.map((e) => e.value.name), ['hello']);
    final blob = client.world.getResource<Blob>();
    final complete =
        blob != null && blob.chunks.every((c) => c.isNotEmpty && c[0] != 0);
    expect(complete, isFalse, reason: 'the download was still going');
    await bed.dispose();
  });
}
