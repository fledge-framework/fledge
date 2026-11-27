// Replicated resources: chunked, change-only, on the bulk channel.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// A 100x100 tile grid in 10x10-tile chunks, as a farm would be.
class Grid {
  static const size = 100;
  static const chunk = 10;
  static const perRow = size ~/ chunk;

  final Uint8List cells = Uint8List(size * size);
  final ChunkVersions versions = ChunkVersions();

  void set(int x, int y, int value) {
    cells[y * size + x] = value;
    versions.bump((y ~/ chunk) * perRow + x ~/ chunk);
  }

  int at(int x, int y) => cells[y * size + x];
}

class GridCodec extends ResourceCodec<Grid> {
  const GridCodec();

  @override
  int chunkCount(Grid grid) => Grid.perRow * Grid.perRow;

  @override
  int chunkVersion(Grid grid, int chunk) => grid.versions.of(chunk);

  @override
  void encodeChunk(Grid grid, int chunk, PacketBuilder out) {
    final cx = chunk % Grid.perRow * Grid.chunk;
    final cy = chunk ~/ Grid.perRow * Grid.chunk;
    for (var y = cy; y < cy + Grid.chunk; y++) {
      for (var x = cx; x < cx + Grid.chunk; x++) {
        out.writeByte(grid.at(x, y));
      }
    }
  }

  @override
  void decodeChunk(Grid grid, int chunk, PacketReader input) {
    final cx = chunk % Grid.perRow * Grid.chunk;
    final cy = chunk ~/ Grid.perRow * Grid.chunk;
    for (var y = cy; y < cy + Grid.chunk; y++) {
      for (var x = cx; x < cx + Grid.chunk; x++) {
        grid.cells[y * Grid.size + x] = input.readByte();
      }
    }
  }
}

/// A list whose length changes; each entry is its own chunk, and one entry
/// is big (several fragments).
class Notes {
  final List<String> entries = [];
  int version = 0;
}

class NotesCodec extends ResourceCodec<Notes> {
  const NotesCodec();

  @override
  int chunkCount(Notes notes) => notes.entries.length;

  @override
  int chunkVersion(Notes notes, int chunk) => notes.version;

  @override
  void encodeChunk(Notes notes, int chunk, PacketBuilder out) =>
      out.writeRawBytes(Uint8List.fromList(notes.entries[chunk].codeUnits));

  @override
  void decodeChunk(Notes notes, int chunk, PacketReader input) {
    final bytes = <int>[];
    while (input.hasMore) {
      bytes.add(input.readByte());
    }
    notes.entries[chunk] = String.fromCharCodes(bytes);
  }

  @override
  void resize(Notes notes, int chunkCount) {
    while (notes.entries.length < chunkCount) {
      notes.entries.add('');
    }
    if (notes.entries.length > chunkCount) {
      notes.entries.removeRange(chunkCount, notes.entries.length);
    }
  }
}

ReplicationRegistry registryWithResources() => buildRegistry()
  ..resource<Grid>('grid', const GridCodec(), create: Grid.new)
  ..resource<Notes>('notes', const NotesCodec(), create: Notes.new);

void main() {
  setUp(ComponentId.resetRegistry);

  Future<(NetTestbed, App)> start({double loss = 0}) async {
    final bed = NetTestbed(
      registry: registryWithResources,
      packetLoss: loss,
      latency: const Duration(milliseconds: 20),
      seed: 7,
    );
    final host = await bed.startHost();
    host.world
      ..insertResource(Grid()..set(5, 5, 9))
      ..insertResource(Notes());
    return (bed, host);
  }

  test('a joining client receives the whole resource', () async {
    final (bed, host) = await start();
    final grid = host.world.getResource<Grid>()!;
    for (var i = 0; i < Grid.size; i++) {
      grid.set(i, i, i % 7 + 1);
    }
    final client = await bed.addClient();
    await bed.frames(30);
    final mirror = client.world.getResource<Grid>()!;
    expect(mirror.cells, grid.cells);
    final updates = NetTestbed.log(client).resourceUpdates;
    expect(updates.where((u) => u.key == 'grid').length, greaterThan(0));
    await bed.dispose();
  });

  test(
    'a client has received a resource only once a chunk of it arrived',
    () async {
      final (bed, host) = await start();
      expect(NetTestbed.session(host).hasReceived('grid'), isTrue);
      final client = await bed.addClient();
      final session = NetTestbed.session(client);
      await bed.frames(30);
      expect(session.hasReceived('grid'), isTrue);
      expect(session.isClient, isTrue);
      expect(session.hasReceived('nothing_by_that_name'), isFalse);
      await bed.dispose();
    },
  );

  test('a change sends only the chunks it touched', () async {
    final (bed, host) = await start();
    final client = await bed.addClient();
    await bed.frames(30);
    final session = NetTestbed.session(host);
    final before = session.stats.resourceChunksSent;
    host.world.getResource<Grid>()!.set(42, 17, 3);
    await bed.frames(10);
    expect(session.stats.resourceChunksSent - before, 1);
    expect(client.world.getResource<Grid>()!.at(42, 17), 3);
    // Nothing changes: nothing more is sent.
    final idle = session.stats.resourceChunksSent;
    await bed.frames(20);
    expect(session.stats.resourceChunksSent, idle);
    await bed.dispose();
  });

  test('resizes and multi-fragment chunks arrive intact', () async {
    final (bed, host) = await start();
    final client = await bed.addClient();
    final notes = host.world.getResource<Notes>()!
      ..entries.addAll(['short', 'x' * 5000, 'tail'])
      ..version = 1;
    await bed.frames(30);
    expect(client.world.getResource<Notes>()!.entries, notes.entries);
    notes
      ..entries.removeLast()
      ..version = 2;
    await bed.frames(30);
    expect(client.world.getResource<Notes>()!.entries, ['short', 'x' * 5000]);
    await bed.dispose();
  });

  test('under 10% loss every client converges exactly', () async {
    final (bed, host) = await start(loss: 0.1);
    final a = await bed.addClient();
    final b = await bed.addClient();
    final grid = host.world.getResource<Grid>()!;
    for (var step = 0; step < 50; step++) {
      grid.set(step * 7 % Grid.size, step * 13 % Grid.size, step % 250 + 1);
      await bed.frame();
    }
    await bed.frames(150);
    expect(a.world.getResource<Grid>()!.cells, grid.cells);
    expect(b.world.getResource<Grid>()!.cells, grid.cells);
    await bed.dispose();
  });

  test('a 100x100 grid with 10 changes a second stays under 4 KiB/s', () async {
    final (bed, host) = await start();
    await bed.addClient();
    await bed.frames(60); // the join's full download
    final grid = host.world.getResource<Grid>()!;
    // Count every byte the host puts on the wire from here on.
    var hostBytes = 0;
    bed.net.filter = (datagram) {
      if (datagram.source.port == 7777) hostBytes += datagram.data.length;
      return true;
    };
    const seconds = 5;
    final framesPerChange = bed.tickRate ~/ 10;
    for (var f = 0; f < bed.tickRate * seconds; f++) {
      if (f % framesPerChange == 0) {
        grid.set(f * 3 % Grid.size, f * 7 % Grid.size, f % 200 + 1);
      }
      await bed.frame();
    }
    final perSecond = hostBytes / seconds;
    expect(perSecond, lessThan(4096));
    await bed.dispose();
  });
}
