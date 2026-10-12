import 'dart:collection';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
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

  /// Smoothed round-trip time in milliseconds (0 until the first sample).
  ///
  /// Measured by the host from ping/pong echoes of its own clock; see
  /// [updateRtt].
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

  /// Monotonic clock for [timeSinceLastReceive] and reliable retransmits
  /// (defaults to [NetClock.system]; `NetworkHost` passes its own clock).
  final NetClock clock;

  /// [clock] time (ms) of the last received packet.
  ///
  /// Drives [timeSinceLastReceive] and therefore the host's peer timeout.
  int lastReceiveMs;

  /// [clock] time (ms) of the last sent packet.
  int lastSendMs;

  DateTime _lastReceiveTime = DateTime.now();
  DateTime _lastSendTime = DateTime.now();

  /// Wall-clock time of the last received packet (informational).
  ///
  /// Timeouts use [lastReceiveMs] on [clock]. Assigning this shifts
  /// [lastReceiveMs] by the same offset from now, so back-dating it still
  /// makes the peer look stale.
  DateTime get lastReceiveTime => _lastReceiveTime;
  set lastReceiveTime(DateTime value) {
    _lastReceiveTime = value;
    lastReceiveMs =
        clock.nowMs - DateTime.now().difference(value).inMilliseconds;
  }

  /// Wall-clock time of the last sent packet (informational; see
  /// [lastSendMs]). Assigning it shifts [lastSendMs] like
  /// [lastReceiveTime] does.
  DateTime get lastSendTime => _lastSendTime;
  set lastSendTime(DateTime value) {
    _lastSendTime = value;
    lastSendMs = clock.nowMs - DateTime.now().difference(value).inMilliseconds;
  }

  /// Custom data attached to the peer.
  final Map<String, dynamic> userData = {};

  /// Congestion controller for rate limiting.
  final CongestionController congestion = CongestionController();

  Peer({
    required this.id,
    required this.address,
    this.name = '',
    this.state = PeerState.connecting,
    NetClock? clock,
  }) : clock = clock ?? NetClock.system,
       lastReceiveMs = (clock ?? NetClock.system).nowMs,
       lastSendMs = (clock ?? NetClock.system).nowMs;

  /// Whether this peer is connected.
  bool get isConnected => state == PeerState.connected;

  /// Time since last packet was received, measured on [clock].
  Duration get timeSinceLastReceive =>
      Duration(milliseconds: clock.nowMs - lastReceiveMs);

  /// Record that a packet was just sent to this peer (updates [lastSendMs]
  /// and [lastSendTime]).
  void markSent() {
    lastSendMs = clock.nowMs;
    _lastSendTime = DateTime.now();
  }

  /// Next outgoing sequence number.
  int get nextSequence {
    lastSentSequence = (lastSentSequence + 1) & 0xFFFF;
    return lastSentSequence;
  }

  /// Process an incoming sequence number.
  void processReceivedSequence(int sequence) {
    lastReceiveMs = clock.nowMs;
    _lastReceiveTime = DateTime.now();

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
    _pendingReliable.add(
      _PendingPacket(sequence: sequence, data: data, sentMs: clock.nowMs),
    );
  }

  /// Maximum number of retransmit attempts before dropping a packet.
  static const int maxRetransmits = 10;

  /// Number of reliable packets dropped (exceeded max retransmits).
  int droppedReliableCount = 0;

  /// Retransmit timeout for reliable packets.
  ///
  /// `rtt * 2` clamped to `100ms..5000ms` once an RTT sample exists,
  /// otherwise [fallbackTimeout].
  Duration retransmitTimeout(Duration fallbackTimeout) => rtt > 0
      ? Duration(milliseconds: (rtt * 2.0).clamp(100, 5000).toInt())
      : fallbackTimeout;

  /// Get packets that need retransmission.
  ///
  /// Uses [retransmitTimeout]: `rtt * 2` clamped to `100ms..5000ms`.
  /// Packets exceeding [maxRetransmits] are dropped and counted.
  /// Timing uses [clock].
  List<Uint8List> getPacketsToRetransmit(Duration fallbackTimeout) {
    final now = clock.nowMs;
    final result = <Uint8List>[];

    final timeoutMs = retransmitTimeout(fallbackTimeout).inMilliseconds;

    _pendingReliable.removeWhere((pending) {
      if (pending.retransmitCount >= maxRetransmits) {
        droppedReliableCount++;
        _updatePacketLoss();
        return true;
      }
      return false;
    });

    for (final pending in _pendingReliable) {
      if (now - pending.sentMs > timeoutMs) {
        pending.sentMs = now;
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

  /// Largest RTT sample accepted, in ms. Larger (or negative) samples come
  /// from stale, corrupt or forged echoes and are ignored.
  static const int maxRttSampleMs = 60000;

  /// Update RTT from a pong that echoed [sentTimestamp].
  ///
  /// [sentTimestamp] is the 32-bit [NetClock] value this side put in the
  /// ping; [nowTimestamp] is the same clock's current 32-bit value
  /// (defaults to [clock]). The difference is computed
  /// wrap-safely. Both values must come from the **local** clock — never
  /// pass a timestamp generated by the remote peer.
  ///
  /// Returns `false` (and leaves [rtt] unchanged) for out-of-range samples.
  bool updateRtt(int sentTimestamp, {int? nowTimestamp}) {
    final now = nowTimestamp ?? clock.nowMs32;
    final sample = NetClock.elapsed32(now, sentTimestamp);
    if (sample < 0 || sample > maxRttSampleMs) return false;
    addRttSample(sample.toDouble());
    return true;
  }

  /// Fold an RTT measurement (ms) into the smoothed [rtt]
  /// (exponential moving average, alpha 0.1).
  void addRttSample(double sampleMs) {
    if (rtt == 0) {
      // A 0ms sample would leave rtt "unknown"; floor at 1ms.
      rtt = sampleMs < 1 ? 1 : sampleMs;
    } else {
      rtt = rtt * 0.9 + sampleMs * 0.1;
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
    congestionWindow = (congestionWindow + _increaseStep).clamp(
      _minWindow,
      _maxWindow,
    );
  }

  /// React to packet loss by halving the window.
  void onPacketLost() {
    congestionWindow = (congestionWindow * 0.5).clamp(_minWindow, _maxWindow);
  }
}

class _PendingPacket {
  final int sequence;
  final Uint8List data;
  int sentMs;
  int retransmitCount = 0;

  _PendingPacket({
    required this.sequence,
    required this.data,
    required this.sentMs,
  });
}
