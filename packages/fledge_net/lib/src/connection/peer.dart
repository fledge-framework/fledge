import 'dart:collection';
import 'dart:typed_data';

import '../transport/transport.dart';

/// Peer connection state.
enum PeerState {
  /// Peer is connecting.
  connecting,

  /// Peer is connected.
  connected,

  /// Peer is disconnecting.
  disconnecting,

  /// Peer is disconnected.
  disconnected,
}

/// Represents a connected peer in the network.
class Peer {
  /// Unique peer ID (assigned by host).
  final int id;

  /// Network address of the peer.
  final NetAddress address;

  /// Player name (optional).
  String name;

  /// Current connection state.
  PeerState state;

  /// Round-trip time in milliseconds.
  double rtt = 0;

  /// Packet loss percentage (0-100).
  double packetLoss = 0;

  /// Last received sequence number.
  int lastReceivedSequence = 0;

  /// Last sent sequence number.
  int lastSentSequence = 0;

  /// Pending reliable packets waiting for acknowledgment.
  final Queue<_PendingPacket> _pendingReliable = Queue();

  /// Recently received sequences for ack bits.
  final List<int> _recentReceivedSequences = [];

  /// Time of last received packet.
  DateTime lastReceiveTime = DateTime.now();

  /// Time of last sent packet.
  DateTime lastSendTime = DateTime.now();

  /// Custom data attached to the peer.
  final Map<String, dynamic> userData = {};

  Peer({
    required this.id,
    required this.address,
    this.name = '',
    this.state = PeerState.connecting,
  });

  /// Whether this peer is connected.
  bool get isConnected => state == PeerState.connected;

  /// Time since last packet was received.
  Duration get timeSinceLastReceive =>
      DateTime.now().difference(lastReceiveTime);

  /// Next outgoing sequence number.
  int get nextSequence {
    lastSentSequence = (lastSentSequence + 1) & 0xFFFF;
    return lastSentSequence;
  }

  /// Process an incoming sequence number.
  void processReceivedSequence(int sequence) {
    lastReceiveTime = DateTime.now();

    // Update recent sequences
    _recentReceivedSequences.add(sequence);
    if (_recentReceivedSequences.length > 32) {
      _recentReceivedSequences.removeAt(0);
    }

    // Update last received
    if (_isSequenceNewer(sequence, lastReceivedSequence)) {
      lastReceivedSequence = sequence;
    }
  }

  /// Process acknowledgment from peer.
  void processAck(int ack, int ackBits) {
    // Remove acknowledged packets from pending queue
    _pendingReliable.removeWhere((pending) {
      if (pending.sequence == ack) return true;

      // Check ack bits for earlier sequences
      final diff = (ack - pending.sequence) & 0xFFFF;
      if (diff > 0 && diff <= 32) {
        final bit = 1 << (diff - 1);
        if ((ackBits & bit) != 0) return true;
      }

      return false;
    });
  }

  /// Get ack bits for recent received sequences.
  int getAckBits() {
    int bits = 0;
    for (final seq in _recentReceivedSequences) {
      final diff = (lastReceivedSequence - seq) & 0xFFFF;
      if (diff > 0 && diff <= 32) {
        bits |= 1 << (diff - 1);
      }
    }
    return bits;
  }

  /// Add a reliable packet to the pending queue.
  void addPendingReliable(int sequence, Uint8List data) {
    _pendingReliable.add(_PendingPacket(
      sequence: sequence,
      data: data,
      sentTime: DateTime.now(),
    ));
  }

  /// Get packets that need retransmission.
  List<Uint8List> getPacketsToRetransmit(Duration timeout) {
    final now = DateTime.now();
    final result = <Uint8List>[];

    for (final pending in _pendingReliable) {
      if (now.difference(pending.sentTime) > timeout) {
        pending.sentTime = now;
        pending.retransmitCount++;
        result.add(pending.data);
      }
    }

    return result;
  }

  /// Update RTT based on ack timing.
  void updateRtt(int sentTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sample = (now - sentTimestamp).toDouble();

    // Exponential moving average
    if (rtt == 0) {
      rtt = sample;
    } else {
      rtt = rtt * 0.9 + sample * 0.1;
    }
  }

  bool _isSequenceNewer(int seq1, int seq2) {
    return ((seq1 > seq2) && (seq1 - seq2 <= 32768)) ||
        ((seq1 < seq2) && (seq2 - seq1 > 32768));
  }
}

class _PendingPacket {
  final int sequence;
  final Uint8List data;
  DateTime sentTime;
  int retransmitCount = 0;

  _PendingPacket({
    required this.sequence,
    required this.data,
    required this.sentTime,
  });
}
