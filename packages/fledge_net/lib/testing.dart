/// Test-only helpers for `fledge_net`.
///
/// **For tests only.** This library is not exported from
/// `package:fledge_net/fledge_net.dart`; import it explicitly from test
/// code:
///
/// ```dart
/// import 'package:fledge_net/testing.dart';
/// ```
///
/// It lets a test act like a modified (malicious or buggy) client and put
/// raw replication traffic on the wire, bypassing the client-side
/// ownership filtering of `NetLocalInputs` and `NetworkSession.sendRpc`,
/// so host-side authority checks can be asserted end to end:
///
/// ```dart
/// // On the attacking client's session: claim the victim's entity.
/// await attackerSession.sendRawInput(
///   netId: victimNetId,
///   firstTick: hostTick,
///   inputs: List.filled(10, encodeWithCodec(moveCodec, const Move(1, 0))),
/// );
/// // The host drops it, counts it in `stats.rejectedInputs` and emits
/// // a `NetRejected` event.
/// ```
///
/// Payloads produced here use the current protocol's wire formats (the
/// same encoders the session uses), so they stay in sync with the
/// library version.
library;

import 'dart:typed_data';

import 'src/protocol/packet.dart';
import 'src/replication/codec.dart';
import 'src/replication/session.dart';
import 'src/replication/wire.dart';

/// One run of consecutive inputs for one entity inside a raw input packet.
class RawInputStream {
  /// Network id of the entity the inputs claim to control.
  final int netId;

  /// Tick of the first input; the others follow one tick apart.
  final int firstTick;

  /// Input codec outputs, one per tick (see [encodeWithCodec]).
  final List<Uint8List> inputs;

  /// Creates a stream of [inputs] for [netId] starting at [firstTick].
  const RawInputStream({
    required this.netId,
    required this.firstTick,
    required this.inputs,
  });
}

/// Encode a `PacketType.input` payload (client to host) exactly as the
/// session does, but with arbitrary [streams].
///
/// [reliableAck] and [lastSnapshotTick] default to 0 ("nothing received"),
/// which the host treats as no new acknowledgement.
Uint8List encodeRawInputPacket({
  required int clientTick,
  required List<RawInputStream> streams,
  int reliableAck = 0,
  int lastSnapshotTick = 0,
}) {
  return InputPacket(
    clientTick: clientTick,
    reliableAck: reliableAck,
    lastSnapshotTick: lastSnapshotTick,
    streams: [
      for (final s in streams) InputStream(s.netId, s.firstTick, s.inputs),
    ],
  ).encode();
}

/// Encode [value] with [codec] into standalone bytes (e.g. one input for
/// a [RawInputStream]).
Uint8List encodeWithCodec<T>(NetCodec<T> codec, T value) {
  final out = PacketBuilder();
  codec.encode(value, out);
  return out.build();
}

/// Raw-traffic helpers on a joined client [NetworkSession]. For tests.
extension NetworkSessionTesting on NetworkSession {
  /// Client: send one raw input packet claiming [inputs] for [netId]
  /// from [firstTick] on, whether or not this client owns it.
  ///
  /// [clientTick] defaults to [firstTick]. Throws [StateError] unless this
  /// session is a connected client.
  Future<void> sendRawInput({
    required int netId,
    required int firstTick,
    required List<Uint8List> inputs,
    int? clientTick,
  }) {
    return sendRawInputPacket(
      encodeRawInputPacket(
        clientTick: clientTick ?? firstTick,
        streams: [
          RawInputStream(netId: netId, firstTick: firstTick, inputs: inputs),
        ],
      ),
    );
  }

  /// Client: send [payload] (see [encodeRawInputPacket]) to the host as a
  /// `PacketType.input` datagram. Throws [StateError] unless this session
  /// is a connected client.
  Future<void> sendRawInputPacket(Uint8List payload) {
    final client = networkClient;
    if (client == null) {
      throw StateError('sendRawInputPacket needs a joined client session');
    }
    return client.send(PacketType.input, payload);
  }

  /// Client: send RPC [value] (type [T] registered with
  /// `ReplicationRegistry.rpc`) naming [targetNetId] as its target
  /// verbatim (0 = no target), even if this client does not own, or has
  /// never seen, that entity. Delivered reliably with the next fixed tick,
  /// like [NetworkSession.sendRpc].
  void sendRawRpc<T>(T value, {required int targetNetId}) {
    queueRpcForNetId<T>(value, targetNetId);
  }
}
