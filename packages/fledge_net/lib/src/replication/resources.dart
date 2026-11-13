import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:meta/meta.dart';

import '../protocol/packet.dart';

/// How a replicated resource is split into chunks, and how each chunk is
/// written and read.
///
/// The host sends each client only the chunks whose [chunkVersion] changed
/// since it last sent them, reliably and in order on a channel of their
/// own (so a big world never delays RPCs); a joining client gets every
/// chunk once. Clients apply chunks into their own instance of the
/// resource. Versions are counters the resource bumps whenever a chunk
/// changes ([ChunkVersions] keeps them); only inequality matters.
///
/// A 100x100 tile map might use 10x10-tile chunks: a planted seed bumps one
/// chunk's version, and only that chunk (a few hundred bytes) is sent.
abstract class ResourceCodec<T> {
  const ResourceCodec();

  /// A resource sent as one chunk, whenever [version] changes. For small
  /// resources (weather, the calendar, a wallet).
  const factory ResourceCodec.whole({
    required void Function(T resource, PacketBuilder out) encode,
    required void Function(T resource, PacketReader input) decode,
    required int Function(T resource) version,
  }) = _WholeResourceCodec<T>;

  /// How many chunks [resource] has now.
  int chunkCount(T resource);

  /// [chunk]'s version: changes whenever the chunk does.
  int chunkVersion(T resource, int chunk);

  /// Writes [chunk] of [resource].
  void encodeChunk(T resource, int chunk, PacketBuilder out);

  /// Reads [chunk] into [resource] (client).
  void decodeChunk(T resource, int chunk, PacketReader input);

  /// Called on a client before a chunk is decoded, with the host's chunk
  /// count, for resources whose size varies. Does nothing by default.
  void resize(T resource, int chunkCount) {}
}

class _WholeResourceCodec<T> extends ResourceCodec<T> {
  const _WholeResourceCodec({
    required void Function(T resource, PacketBuilder out) encode,
    required void Function(T resource, PacketReader input) decode,
    required int Function(T resource) version,
  }) : _encode = encode,
       _decode = decode,
       _version = version;

  final void Function(T, PacketBuilder) _encode;
  final void Function(T, PacketReader) _decode;
  final int Function(T) _version;

  @override
  int chunkCount(T resource) => 1;

  @override
  int chunkVersion(T resource, int chunk) => _version(resource);

  @override
  void encodeChunk(T resource, int chunk, PacketBuilder out) =>
      _encode(resource, out);

  @override
  void decodeChunk(T resource, int chunk, PacketReader input) =>
      _decode(resource, input);
}

/// Per-chunk version counters for a replicated resource: [bump] a chunk
/// whenever it changes, and hand [of] to `ResourceCodec.chunkVersion`.
class ChunkVersions {
  final List<int> _versions = [];

  /// [chunk]'s version (0 until first bumped).
  int of(int chunk) => chunk < _versions.length ? _versions[chunk] : 0;

  /// Marks [chunk] as changed.
  void bump(int chunk) {
    while (_versions.length <= chunk) {
      _versions.add(0);
    }
    _versions[chunk]++;
  }

  /// Marks every chunk below [count] as changed.
  void bumpAll(int count) {
    for (var i = 0; i < count; i++) {
      bump(i);
    }
  }
}

/// Client: [chunk] of the replicated resource registered as [key] was
/// just updated from the host.
class NetResourceUpdated {
  /// The resource's registry key.
  final String key;

  /// The chunk that changed.
  final int chunk;

  const NetResourceUpdated(this.key, this.chunk);
}

/// Type-erased resource registration.
@internal
class ResourceReplicator<T> {
  ResourceReplicator({
    required this.index,
    required this.key,
    required this.codec,
    this.create,
  });

  final int index;
  final String key;
  final ResourceCodec<T> codec;
  final T Function()? create;

  Type get type => T;

  /// The world's instance, or null.
  T? of(World world) => world.getResource<T>();

  /// The world's instance, created with [create] if missing (client).
  T? obtain(World world) {
    final current = world.getResource<T>();
    if (current != null) return current;
    final made = create?.call();
    if (made != null) world.insertResource<T>(made);
    return made;
  }

  int chunkCount(Object resource) => codec.chunkCount(resource as T);

  int chunkVersion(Object resource, int chunk) =>
      codec.chunkVersion(resource as T, chunk);

  Uint8List encodeChunk(Object resource, int chunk, PacketBuilder out) {
    out.clear();
    codec.encodeChunk(resource as T, chunk, out);
    return out.build();
  }

  void apply(Object resource, int chunkCount, int chunk, PacketReader input) {
    final typed = resource as T;
    codec
      ..resize(typed, chunkCount)
      ..decodeChunk(typed, chunk, input);
  }
}
