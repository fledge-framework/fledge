import 'dart:collection';
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
/// The channel never gives up: a peer that stops acking is eventually
/// removed by the connection timeout.
///
/// ## Packet format
///
/// ```
/// uint32  ack            cumulative ack of the *other* direction
/// varuint count          number of messages in this packet
/// count x {
///   uint32  seq
///   varuint length
///   bytes   message
/// }
/// ```
class ReliableChannel {
  /// Largest packet payload produced by [takePackets].
  final int maxPacketBytes;

  /// Upper bound on out-of-order messages buffered by the receiver; a
  /// message further ahead than this is dropped (it will be resent).
  final int maxReceiveWindow;

  int _nextSeq = 1;
  final SplayTreeMap<int, _Outgoing> _unacked = SplayTreeMap();

  int _expected = 1;
  final Map<int, Uint8List> _outOfOrder = {};
  final List<Uint8List> _ready = [];

  /// Bytes of fixed packet overhead (ack + count varint upper bound).
  static const int packetOverheadBytes = 4 + 5;

  /// Bytes of per-message overhead (seq + length varint upper bound).
  static const int messageOverheadBytes = 4 + 5;

  ReliableChannel({
    this.maxPacketBytes = Packet.maxPayloadBytes,
    this.maxReceiveWindow = 8192,
  });

  /// Largest message [enqueue] accepts.
  int get maxMessageBytes =>
      maxPacketBytes - packetOverheadBytes - messageOverheadBytes;

  // Sending ------------------------------------------------------------------

  /// Number of messages sent but not yet acknowledged.
  int get unackedCount => _unacked.length;

  /// Sequence number the next [enqueue]d message will get.
  int get nextSequence => _nextSeq;

  /// Queue [message] for reliable, ordered delivery. Returns its sequence
  /// number.
  ///
  /// Throws [ArgumentError] if it exceeds [maxMessageBytes].
  int enqueue(Uint8List message) {
    if (message.length > maxMessageBytes) {
      throw ArgumentError.value(
        message.length,
        'message.length',
        'Reliable message is ${message.length} bytes; the maximum is '
            '$maxMessageBytes bytes',
      );
    }
    final seq = _nextSeq++;
    _unacked[seq] = _Outgoing(message);
    return seq;
  }

  /// Process a cumulative ack from the remote receiver.
  void onAck(int cumulativeAck) {
    while (_unacked.isNotEmpty && _unacked.firstKey()! <= cumulativeAck) {
      _unacked.remove(_unacked.firstKey());
    }
  }

  /// Build the packets to put on the wire now: every message never sent,
  /// plus every unacked message last sent at least [resendAfterMs] ago.
  ///
  /// [ack] is this side's cumulative ack ([receivedAck]) to piggyback.
  /// At most [maxPackets] packets are produced per call; the remainder go
  /// out on the next call.
  List<Uint8List> takePackets({
    required int nowMs,
    required int resendAfterMs,
    required int ack,
    int maxPackets = 32,
  }) {
    final packets = <Uint8List>[];
    final seqs = <int>[];
    final messages = <Uint8List>[];
    var size = packetOverheadBytes;

    void finish() {
      if (seqs.isEmpty) return;
      final builder = PacketBuilder()
        ..writeUint32(ack)
        ..writeVarUint(seqs.length);
      for (var i = 0; i < seqs.length; i++) {
        builder
          ..writeUint32(seqs[i])
          ..writeVarBytes(messages[i]);
      }
      packets.add(builder.build());
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
      }
      out.lastSentMs = nowMs;
      seqs.add(entry.key);
      messages.add(out.message);
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
      received.add((seq, reader.readVarBytes()));
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
      _ready.add(message);
      _expected++;
      while (true) {
        final next = _outOfOrder.remove(_expected);
        if (next == null) break;
        _ready.add(next);
        _expected++;
      }
    } else {
      _outOfOrder.putIfAbsent(seq, () => message);
    }
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
  final Uint8List message;
  int? lastSentMs;

  _Outgoing(this.message);
}
