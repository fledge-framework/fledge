import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../protocol/packet.dart';

/// Ordered, reliable, de-duplicated message channel with cumulative acks,
/// layered over unreliable [PacketType.replication] packets.
///
/// Each side of a connection owns one [ReliableChannel]: the *sending*
/// half numbers messages (`1, 2, 3, ...`) and resends every unacked message
/// once it has been in flight for the resend timeout; the *receiving* half
/// buffers out-of-order messages and releases them strictly in order,
/// dropping duplicates. The receiver acknowledges cumulatively ("I have
/// everything up to N"). The ack rides on every replication packet and on
/// every snapshot / input packet, so a lost ack is repaired by the next
/// packet, with no 32-packet ack window to fall out of.
///
/// ## Large messages
///
/// A message up to [maxMessageBytes] (1 MiB) is accepted: anything bigger
/// than one packet's worth ([maxFragmentBytes]) is split into fragments,
/// each sent, acknowledged and resent like a message of its own, and
/// joined back together by the receiver. The stream is ordered, so the
/// fragments of a message are consecutive and need no ids.
///
/// The channel never gives up on a message: a peer that stops acking is
/// eventually removed by the connection timeout, or once [maxUnacked]
/// messages are waiting (see [isFull]).
///
/// ## Bounds
///
/// - Sending: at most [maxUnacked] fragments are buffered until acked
///   (default [defaultMaxUnacked]). [enqueue] throws once [isFull]; the
///   owner must then drop the connection, because the ordered stream can
///   no longer be completed. The replication layer disconnects the peer
///   (host) or ends the session (client).
/// - Receiving: at most [maxReceiveWindow] out-of-order fragments are
///   buffered (default [defaultMaxReceiveWindow]); one further ahead than
///   that is dropped and arrives again with the sender's resend. Memory is
///   bounded by `maxReceiveWindow * maxFragmentBytes`, plus one message
///   being reassembled (at most [maxMessageBytes]).
///
/// ## Packet format
///
/// ```
/// uint32  ack            cumulative ack of the *other* direction
/// varuint count          number of messages in this packet
/// count x {
///   uint32  seq
///   varuint length
///   uint8   part           0 whole message, 1 fragment (more follow),
///                          2 last fragment
///   bytes   message (or fragment)
/// }
/// ```
///
/// `length` counts the part byte too.
class ReliableChannel {
  /// Largest packet payload produced by [takePackets]
  /// ([Packet.maxPayloadBytes]).
  static const int maxPacketBytes = Packet.maxPayloadBytes;

  /// Bytes of fixed packet overhead (ack + count varint upper bound).
  static const int packetOverheadBytes = 4 + 5;

  /// Bytes of per-message overhead (seq + length varint upper bound + part
  /// byte).
  static const int messageOverheadBytes = 4 + 5 + 1;

  /// Largest fragment (1133 bytes): one fragment always fits one packet. A
  /// message up to this size goes as a single fragment.
  static const int maxFragmentBytes =
      maxPacketBytes - packetOverheadBytes - messageOverheadBytes;

  /// Largest message [enqueue] accepts: 1 MiB, sent as fragments.
  static const int maxMessageBytes = 1 << 20;

  static const int _whole = 0;
  static const int _more = 1;
  static const int _last = 2;

  /// Default [maxUnacked]: 16384 messages (at most ~18 MiB of buffered
  /// messages per channel).
  static const int defaultMaxUnacked = 16384;

  /// Default [maxReceiveWindow]: 1024 messages (at most ~1.1 MiB of
  /// buffered out-of-order messages per channel).
  static const int defaultMaxReceiveWindow = 1024;

  /// Upper bound on fragments sent but not yet acknowledged.
  final int maxUnacked;

  /// Upper bound on out-of-order messages buffered by the receiver; a
  /// message further ahead than this is dropped (it will be resent).
  final int maxReceiveWindow;

  int _nextSeq = 1;
  final SplayTreeMap<int, _Outgoing> _unacked = SplayTreeMap();

  int _expected = 1;
  final Map<int, Uint8List> _outOfOrder = {};
  final List<Uint8List> _ready = [];
  final BytesBuilder _partial = BytesBuilder(copy: false);

  final PacketBuilder _out = PacketBuilder(maxPacketBytes);

  ReliableChannel({
    this.maxUnacked = defaultMaxUnacked,
    this.maxReceiveWindow = defaultMaxReceiveWindow,
  }) {
    if (maxUnacked < 1) {
      throw ArgumentError.value(maxUnacked, 'maxUnacked', 'must be >= 1');
    }
    if (maxReceiveWindow < 1) {
      throw ArgumentError.value(
        maxReceiveWindow,
        'maxReceiveWindow',
        'must be >= 1',
      );
    }
  }

  // Sending ------------------------------------------------------------------

  /// Number of fragments sent but not yet acknowledged.
  int get unackedCount => _unacked.length;

  /// Bytes waiting to be sent for the first time or acknowledged.
  int get unackedBytes => _unackedBytes;
  int _unackedBytes = 0;

  /// Whether [maxUnacked] fragments are waiting for an ack, so [enqueue]
  /// would throw.
  bool get isFull => _unacked.length >= maxUnacked;

  /// Whether a message of [length] bytes can be queued now.
  bool canEnqueue(int length) =>
      length <= maxMessageBytes &&
      _unacked.length + fragmentsFor(length) <= maxUnacked;

  /// How many fragments a message of [length] bytes is sent as.
  static int fragmentsFor(int length) =>
      length <= maxFragmentBytes ? 1 : (length / maxFragmentBytes).ceil();

  /// Sequence number the next [enqueue]d message will get.
  int get nextSequence => _nextSeq;

  /// Queue [message] for reliable, ordered delivery, as fragments if it's
  /// bigger than [maxFragmentBytes]. Returns the sequence number of its
  /// last fragment.
  ///
  /// Throws [ArgumentError] if it exceeds [maxMessageBytes] and
  /// [StateError] if its fragments don't fit under [maxUnacked].
  int enqueue(Uint8List message) {
    if (message.length > maxMessageBytes) {
      throw ArgumentError.value(
        message.length,
        'message.length',
        'Reliable message is ${message.length} bytes; the maximum is '
            '$maxMessageBytes bytes',
      );
    }
    if (!canEnqueue(message.length)) {
      throw StateError(
        'Reliable channel overflow: $maxUnacked fragments are '
        'unacknowledged',
      );
    }
    if (message.length <= maxFragmentBytes) return _add(_whole, message);
    var seq = 0;
    for (var at = 0; at < message.length; at += maxFragmentBytes) {
      final end = math.min(at + maxFragmentBytes, message.length);
      seq = _add(
        end == message.length ? _last : _more,
        Uint8List.sublistView(message, at, end),
      );
    }
    return seq;
  }

  int _add(int part, Uint8List bytes) {
    final seq = _nextSeq++;
    _unacked[seq] = _Outgoing(part, bytes);
    _unackedBytes += bytes.length;
    return seq;
  }

  /// Process a cumulative ack from the remote receiver.
  void onAck(int cumulativeAck) {
    while (_unacked.isNotEmpty && _unacked.firstKey()! <= cumulativeAck) {
      _unackedBytes -= _unacked.remove(_unacked.firstKey())!.message.length;
    }
  }

  /// Build the packets to put on the wire now: every message never sent,
  /// plus every unacked message last sent at least [resendAfterMs] ago.
  ///
  /// [ack] is this side's cumulative ack ([receivedAck]) to piggyback.
  /// At most [maxPackets] packets and about [maxBytes] bytes (a packet
  /// always goes once started) are produced per call; the remainder go out
  /// on the next call.
  List<Uint8List> takePackets({
    required int nowMs,
    required int resendAfterMs,
    required int ack,
    int maxPackets = 32,
    int? maxBytes,
  }) {
    final packets = <Uint8List>[];
    final seqs = <int>[];
    final messages = <_Outgoing>[];
    var spent = 0;
    var size = packetOverheadBytes;

    void finish() {
      if (seqs.isEmpty) return;
      final builder = _out
        ..clear()
        ..writeUint32(ack)
        ..writeVarUint(seqs.length);
      for (var i = 0; i < seqs.length; i++) {
        final out = messages[i];
        builder
          ..writeUint32(seqs[i])
          ..writeVarUint(out.message.length + 1)
          ..writeByte(out.part)
          ..writeRawBytes(out.message);
      }
      final packet = builder.build();
      spent += packet.length;
      packets.add(packet);
      seqs.clear();
      messages.clear();
      size = packetOverheadBytes;
    }

    for (final entry in _unacked.entries) {
      final out = entry.value;
      final last = out.lastSentMs;
      if (last != null && nowMs - last < resendAfterMs) continue;
      final cost = messageOverheadBytes + out.message.length;
      if (size + cost > maxPacketBytes) {
        finish();
        if (packets.length >= maxPackets) break;
        if (maxBytes != null && spent >= maxBytes) break;
      }
      out.lastSentMs = nowMs;
      seqs.add(entry.key);
      messages.add(out);
      size += cost;
    }
    if (packets.length < maxPackets) finish();
    return packets;
  }

  // Receiving ----------------------------------------------------------------

  /// Cumulative ack to send back: every message up to this sequence number
  /// has been received.
  int get receivedAck => _expected - 1;

  /// Parse a channel packet: returns the remote's cumulative ack and
  /// buffers the contained messages (call [drain] for in-order delivery).
  ///
  /// Throws [RangeError] / [FormatException] on malformed input.
  int receivePacket(Uint8List payload) {
    final reader = PacketReader(payload);
    final ack = reader.readUint32();
    final count = reader.readVarUint();
    final received = <(int, Uint8List)>[];
    for (var i = 0; i < count; i++) {
      final seq = reader.readUint32();
      final entry = reader.readVarBytes();
      if (entry.isEmpty || entry[0] > _last) {
        throw const FormatException('bad reliable message part');
      }
      received.add((seq, entry));
    }
    // Only accept once the whole packet parsed cleanly.
    for (final (seq, message) in received) {
      _accept(seq, message);
    }
    return ack;
  }

  void _accept(int seq, Uint8List message) {
    if (seq < _expected) return; // duplicate
    if (seq - _expected >= maxReceiveWindow) return; // too far ahead
    if (seq == _expected) {
      _deliver(message);
      _expected++;
      while (true) {
        final next = _outOfOrder.remove(_expected);
        if (next == null) break;
        _deliver(next);
        _expected++;
      }
    } else {
      _outOfOrder.putIfAbsent(seq, () => message);
    }
  }

  /// Delivers one in-order [entry] (part byte, then bytes): a whole message,
  /// or a fragment of one being reassembled.
  void _deliver(Uint8List entry) {
    final part = entry[0];
    final bytes = Uint8List.sublistView(entry, 1);
    if (part == _whole && _partial.isEmpty) {
      _ready.add(bytes);
      return;
    }
    if (_partial.length + bytes.length > maxMessageBytes) {
      // A peer sending more than any message may hold: drop what we have.
      _partial.clear();
      return;
    }
    _partial.add(bytes);
    if (part != _more) _ready.add(_partial.takeBytes());
  }

  /// Messages received in order since the last call.
  List<Uint8List> drain() {
    if (_ready.isEmpty) return const [];
    final out = List<Uint8List>.of(_ready);
    _ready.clear();
    return out;
  }
}

class _Outgoing {
  final int part;
  final Uint8List message;
  int? lastSentMs;

  _Outgoing(this.part, this.message);
}
