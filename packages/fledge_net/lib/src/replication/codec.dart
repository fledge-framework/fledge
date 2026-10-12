import '../protocol/packet.dart';

/// Encodes and decodes one replicated value (component, input or RPC
/// payload) to and from the wire.
///
/// Codecs must be **deterministic and symmetric**: `decode(encode(v))`
/// must reproduce `v` (up to the precision the codec chooses, e.g.
/// float32), and the same value must always encode to the same bytes.
/// Host and clients must register the same codecs under the same keys in
/// the same order (a schema hash is checked during the handshake).
///
/// ```dart
/// final positionCodec = NetCodec<Position>.of(
///   encode: (p, out) => out..writeFloat32(p.x)..writeFloat32(p.y),
///   decode: (r) => Position(r.readFloat32(), r.readFloat32()),
/// );
/// ```
abstract class NetCodec<T> {
  /// Const constructor for subclasses.
  const NetCodec();

  /// Build a codec from two functions.
  const factory NetCodec.of({
    required void Function(T value, PacketBuilder out) encode,
    required T Function(PacketReader input) decode,
  }) = _FunctionCodec<T>;

  /// Write [value] to [out].
  void encode(T value, PacketBuilder out);

  /// Read a value written by [encode].
  T decode(PacketReader input);
}

class _FunctionCodec<T> extends NetCodec<T> {
  final void Function(T value, PacketBuilder out) _encode;
  final T Function(PacketReader input) _decode;

  const _FunctionCodec({
    required void Function(T value, PacketBuilder out) encode,
    required T Function(PacketReader input) decode,
  }) : _encode = encode,
       _decode = decode;

  @override
  void encode(T value, PacketBuilder out) => _encode(value, out);

  @override
  T decode(PacketReader input) => _decode(input);
}
