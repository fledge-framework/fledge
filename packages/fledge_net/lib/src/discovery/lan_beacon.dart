import 'dart:convert';
import 'dart:typed_data';

import '../protocol/packet.dart';
import '../transport/transport.dart';

/// One LAN discovery beacon: what a host that's accepting players over
/// direct IP says about itself, a couple of times a second, to everyone on
/// its local network (see `LanAdvertiser` and `LanBrowser`).
///
/// Wire format (little-endian, [maxBeaconBytes] at most):
///
/// | Field | Size | |
/// |---|---|---|
/// | magic | 4 | [magic], "FLDB", distinct from game packets' "FLEG" |
/// | version | 1 | [version] |
/// | flags | 1 | bit 0: the host is leaving ([leaving]) |
/// | instance | 4 | random per advertiser run, to merge one host heard on several interfaces |
/// | port | 2 | the game port to join |
/// | app id | 2 + n | UTF-8, [maxAppIdBytes] at most |
/// | payload | 2 + n | opaque, [maxPayloadBytes] at most |
///
/// Beacons are plaintext and unauthenticated: anyone on the network can
/// send one. Treat [payload] as display text only; joining still goes
/// through the normal connect handshake (and its authentication).
class LanBeacon {
  /// "FLDB" (fledge discovery beacon), little-endian.
  static const int magic = 0x4244_4C46;

  /// The beacon format's version. A browser ignores other versions.
  static const int version = 1;

  /// Longest app id, in UTF-8 bytes.
  static const int maxAppIdBytes = 64;

  /// Largest game-defined payload, in bytes.
  static const int maxPayloadBytes = 512;

  /// Largest beacon datagram: anything bigger is ignored unread.
  static const int maxBeaconBytes =
      4 + 1 + 1 + 4 + 2 + 2 + maxAppIdBytes + 2 + maxPayloadBytes;

  static const int _leavingFlag = 0x01;

  /// Which game sent it, so different games on one network (or one
  /// discovery port) never see each other's hosts.
  final String appId;

  /// The game port the host accepts players on.
  final int port;

  /// Random per advertiser run (not an identity): the same host heard
  /// through several network interfaces is listed once.
  final int instance;

  /// Whether the host stopped advertising (sent once on stop), so browsers
  /// drop it at once instead of waiting for it to expire.
  final bool leaving;

  /// The game's own description of the host (a name, a player count),
  /// [maxPayloadBytes] at most.
  final Uint8List payload;

  /// Creates a beacon. Throws [ArgumentError] when [appId] is empty or
  /// longer than [maxAppIdBytes], [port] isn't 1..65535, [instance] isn't
  /// an unsigned 32-bit value or [payload] is over [maxPayloadBytes].
  LanBeacon({
    required this.appId,
    required this.port,
    required this.instance,
    this.leaving = false,
    Uint8List? payload,
  }) : payload = payload ?? Uint8List(0) {
    checkAppId(appId);
    if (port < 1 || port > 0xFFFF) {
      throw ArgumentError.value(port, 'port', 'must be 1..65535');
    }
    if (instance < 0 || instance > 0xFFFFFFFF) {
      throw ArgumentError.value(instance, 'instance', 'must be a uint32');
    }
    checkPayload(this.payload);
  }

  /// Throws [ArgumentError] unless [appId] is a valid app id.
  static void checkAppId(String appId) {
    final length = utf8.encode(appId).length;
    if (length == 0 || length > maxAppIdBytes) {
      throw ArgumentError.value(
        appId,
        'appId',
        'must be 1..$maxAppIdBytes UTF-8 bytes',
      );
    }
  }

  /// Throws [ArgumentError] when [payload] is over [maxPayloadBytes].
  static void checkPayload(Uint8List payload) {
    if (payload.length > maxPayloadBytes) {
      throw ArgumentError.value(
        payload.length,
        'payload',
        'must be at most $maxPayloadBytes bytes',
      );
    }
  }

  /// The beacon's datagram.
  Uint8List encode() {
    final out = PacketBuilder()
      ..writeUint32(magic)
      ..writeByte(version)
      ..writeByte(leaving ? _leavingFlag : 0)
      ..writeUint32(instance)
      ..writeUint16(port)
      ..writeString(appId)
      ..writeBytes(payload);
    return out.build();
  }

  /// Reads a beacon from [data], or `null` when it isn't one: too big,
  /// another magic or version, a bad length, invalid UTF-8, a field out of
  /// range or bytes left over. Never throws.
  static LanBeacon? tryDecode(Uint8List data) {
    if (data.length < 4 + 1 + 1 + 4 + 2 + 2 + 1 + 2 ||
        data.length > maxBeaconBytes) {
      return null;
    }
    try {
      final r = PacketReader(data);
      if (r.readUint32() != magic) return null;
      if (r.readByte() != version) return null;
      final flags = r.readByte();
      final instance = r.readUint32();
      final port = r.readUint16();
      final appId = r.readString();
      final payload = r.readBytes();
      if (r.hasMore) return null;
      return LanBeacon(
        appId: appId,
        port: port,
        instance: instance,
        leaving: flags & _leavingFlag != 0,
        payload: payload,
      );
    } on Object {
      return null;
    }
  }
}

/// A host found on the local network by a `LanBrowser`.
class LanHost {
  /// Where to join: the address the beacon came from, at its game port.
  final NetAddress address;

  /// The advertiser run it came from ([LanBeacon.instance]).
  final int instance;

  /// The game's payload from its latest beacon ([LanBeacon.payload]).
  /// Untrusted: display it, never act on it.
  final Uint8List payload;

  /// When it was first heard, on the browser's `NetClock` (ms).
  final int firstSeenMs;

  /// When it was last heard, on the browser's `NetClock` (ms).
  final int lastSeenMs;

  const LanHost({
    required this.address,
    required this.instance,
    required this.payload,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  /// The host's numeric IPv4 address.
  String get host => address.host;

  /// The game port to join.
  int get port => address.port;

  /// [payload] as UTF-8 text, or `null` if it isn't valid UTF-8.
  String? get payloadText {
    try {
      return utf8.decode(payload);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'LanHost($address)';
}
