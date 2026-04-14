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

  /// Congestion controller for rate limiting.
  final CongestionController congestion = CongestionController();

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

  /// Maximum number of retransmit attempts before dropping a packet.
  static const int maxRetransmits = 10;

  /// Number of reliable packets dropped (exceeded max retransmits).
  int droppedReliableCount = 0;

  /// Get packets that need retransmission.
  ///
  /// Uses RTT-based timeout: `max(100ms, rtt * 2.0)`.
  /// Packets exceeding [maxRetransmits] are dropped and counted.
  List<Uint8List> getPacketsToRetransmit(Duration fallbackTimeout) {
    final now = DateTime.now();
    final result = <Uint8List>[];

    // Use RTT-based timeout if RTT is known, otherwise fallback
    final timeout = rtt > 0
        ? Duration(milliseconds: (rtt * 2.0).clamp(100, 5000).toInt())
        : fallbackTimeout;

    _pendingReliable.removeWhere((pending) {
      if (pending.retransmitCount >= maxRetransmits) {
        droppedReliableCount++;
        _updatePacketLoss();
        return true;
      }
      return false;
    });

    for (final pending in _pendingReliable) {
      if (now.difference(pending.sentTime) > timeout) {
        pending.sentTime = now;
        pending.retransmitCount++;
        result.add(pending.data);
      }
    }

    return result;
  }

  void _updatePacketLoss() {
    // Exponential moving average of loss events
    packetLoss = packetLoss * 0.9 + 10.0;
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

/// Simple AIMD (Additive Increase, Multiplicative Decrease) congestion controller.
class CongestionController {
  /// Current congestion window in bytes.
  double congestionWindow;

  /// Bytes currently in flight (sent but not yet acknowledged).
  int bytesInFlight = 0;

  /// Minimum congestion window floor.
  static const double _minWindow = 1200; // ~1 MTU

  /// Maximum congestion window ceiling.
  static const double _maxWindow = 256000; // 256 KB

  /// Additive increase per ack (bytes).
  static const double _increaseStep = 100;

  CongestionController({this.congestionWindow = 65536}); // Default 64 KB

  /// Whether a packet of [size] bytes can be sent.
  bool canSend(int size) => bytesInFlight + size <= congestionWindow;

  /// Record that [size] bytes were sent.
  void onPacketSent(int size) {
    bytesInFlight += size;
  }

  /// Record that [size] bytes were acknowledged.
  void onPacketAcked(int size) {
    bytesInFlight = (bytesInFlight - size).clamp(0, bytesInFlight);
    // Additive increase
    congestionWindow =
        (congestionWindow + _increaseStep).clamp(_minWindow, _maxWindow);
  }

  /// React to packet loss by halving the window.
  void onPacketLost() {
    congestionWindow = (congestionWindow * 0.5).clamp(_minWindow, _maxWindow);
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
