import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
import '../protocol/packet.dart';
import '../transport/transport.dart';
import 'peer.dart';
import 'protocol_mismatch.dart';

/// Client connection state.
enum ClientState {
  /// Not connected.
  disconnected,

  /// Attempting to connect.
  connecting,

  /// Connected to host.
  connected,

  /// Connection failed.
  failed,
}

/// Event when connection state changes.
class ConnectionStateEvent {
  final ClientState state;
  final String? reason;
  ConnectionStateEvent(this.state, [this.reason]);
}

/// Event when data is received from host.
class HostDataEvent {
  final PacketType type;
  final Uint8List data;
  HostDataEvent(this.type, this.data);
}

/// Network client for connecting to a game host.
///
/// The client:
/// - Connects to a host by address or hostname
/// - Sends inputs to the host
/// - Receives state updates from the host
/// - Predicts local state for responsiveness
class NetworkClient {
  /// Transport for network communication.
  final Transport transport;

  /// Connection timeout duration.
  ///
  /// Bounds the whole [connect] handshake and, once connected, the time
  /// without any packet from the host before the client fails.
  final Duration connectionTimeout;

  /// Ping interval. The first ping is sent on the first [update] after
  /// connecting.
  final Duration pingInterval;

  /// How often the `connect` request is re-sent while waiting for the
  /// host's answer, so a single lost datagram doesn't stall the handshake
  /// until [connectionTimeout].
  final Duration connectRetryInterval;

  /// Monotonic clock used for ping timestamps, RTT, ping cadence, the
  /// connected-state timeout and reliable retransmits.
  final NetClock clock;

  /// Resolves the `host` passed to [connect] to a numeric address.
  ///
  /// Defaults to: numeric addresses are used as-is; hostnames go through
  /// [InternetAddress.lookup], preferring an IPv4 result.
  final Future<String> Function(String host)? hostResolver;

  /// Current connection state.
  ClientState _state = ClientState.disconnected;

  /// Host address.
  NetAddress? _hostAddress;

  /// Local peer ID assigned by host.
  int? _localPeerId;

  /// Sequence tracking.
  int _lastSentSequence = 0;
  int _lastReceivedSequence = 0;
  final List<int> _recentReceivedSequences = [];

  /// Smoothed round-trip time in milliseconds (0 until the first sample).
  ///
  /// Measured from ping/pong echoes of this client's own [clock].
  double rtt = 0;

  /// Pending reliable packets waiting for acknowledgment.
  final Queue<_ClientPendingPacket> _pendingReliable = Queue();

  /// Maximum retransmit attempts before dropping.
  static const int _maxRetransmits = 10;

  /// Time of last received packet ([clock] milliseconds).
  int _lastReceiveMs = 0;

  /// Time of last sent ping ([clock] milliseconds), `null` before the
  /// first ping of a connection.
  int? _lastPingMs;

  /// Event controllers.
  final _stateController = StreamController<ConnectionStateEvent>.broadcast();
  final _dataController = StreamController<HostDataEvent>.broadcast();
  final _mismatchController =
      StreamController<ProtocolMismatchEvent>.broadcast();

  /// Completer for connect operation.
  Completer<bool>? _connectCompleter;

  /// Serialized connect request, re-sent until answered.
  Uint8List? _connectPacket;
  Timer? _connectRetryTimer;

  NetworkClient({
    required this.transport,
    this.connectionTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 1),
    this.connectRetryInterval = const Duration(milliseconds: 250),
    NetClock? clock,
    this.hostResolver,
  }) : clock = clock ?? NetClock.system;

  /// Stream of connection state changes.
  Stream<ConnectionStateEvent> get onStateChange => _stateController.stream;

  /// Stream of data received from host.
  Stream<HostDataEvent> get onData => _dataController.stream;

  /// The host answered with a different protocol version.
  ///
  /// The client also transitions to [ClientState.failed] with a reason of
  /// the form `Protocol version mismatch: local vX, server vY`.
  Stream<ProtocolMismatchEvent> get onProtocolMismatch =>
      _mismatchController.stream;

  /// Current connection state.
  ClientState get state => _state;

  /// Whether connected to a host.
  bool get isConnected => _state == ClientState.connected;

  /// Local peer ID assigned by host.
  int? get localPeerId => _localPeerId;

  /// Host address (numeric, after hostname resolution).
  NetAddress? get hostAddress => _hostAddress;

  /// Retransmit timeout for reliable packets: `rtt * 2` clamped to
  /// `100ms..5000ms`, or 100ms before the first RTT sample.
  Duration get retransmitTimeout => rtt > 0
      ? Duration(milliseconds: (rtt * 2.0).clamp(100, 5000).toInt())
      : const Duration(milliseconds: 100);

  /// Credentials to send during connection handshake.
  Uint8List? _credentials;

  /// Connect to a host.
  ///
  /// [host] may be a numeric address or a hostname such as `'localhost'`;
  /// hostnames are resolved first (IPv4 preferred, see [hostResolver]).
  /// The connect request is re-sent every [connectRetryInterval] until the
  /// host accepts or rejects it, or [connectionTimeout] elapses.
  ///
  /// Optionally provide [credentials] for authentication (e.g., password hash,
  /// token). The host's authenticator callback receives these credentials.
  Future<bool> connect(String host, int port, {Uint8List? credentials}) async {
    if (_state != ClientState.disconnected) {
      throw StateError('Client not disconnected');
    }
    _credentials = credentials;

    _setState(ClientState.connecting);
    final completer = _connectCompleter = Completer<bool>();

    try {
      final String address;
      try {
        address = await _resolveHost(host);
      } catch (e) {
        _failConnect('Could not resolve host "$host": $e');
        return false;
      }
      if (_state != ClientState.connecting) return false;
      _hostAddress = NetAddress(address, port);

      // Bind to any available port
      await transport.bind(0);

      // Start listening for packets
      transport.onReceive.listen(_handlePacket);
      _lastReceiveMs = clock.nowMs;

      // Send connect request, then keep retrying until answered.
      _connectPacket = _buildConnectPacket();
      await _sendConnectAttempt();
      _connectRetryTimer = Timer.periodic(
        connectRetryInterval,
        (_) => _sendConnectAttempt(),
      );

      // Wait for response or timeout
      return await completer.future.timeout(
        connectionTimeout,
        onTimeout: () {
          _failConnect('Connection timeout');
          return false;
        },
      );
    } catch (e) {
      _failConnect(e.toString());
      return false;
    } finally {
      _stopConnectRetries();
    }
  }

  /// Disconnect from host.
  Future<void> disconnect() async {
    if (_state == ClientState.disconnected) return;
    _stopConnectRetries();
    _completeConnect(false);

    if (_state == ClientState.connected && _hostAddress != null) {
      // Send disconnect packet
      final builder = PacketBuilder()..writeString('Client disconnecting');
      await _sendToHost(PacketType.disconnect, builder.build());
    }

    await transport.close();
    _setState(ClientState.disconnected);
    _hostAddress = null;
    _localPeerId = null;
  }

  /// Send data to the host.
  ///
  /// Throws [StateError] when not connected and [ArgumentError] if [data]
  /// exceeds [Packet.maxPayloadBytes].
  Future<void> send(PacketType type, Uint8List data) async {
    if (!isConnected || _hostAddress == null) {
      throw StateError('Not connected');
    }
    Packet.checkPayloadSize(data);

    await _sendToHost(type, data);
  }

  /// Update client (call every frame).
  ///
  /// Checks the connection timeout, pings the host every [pingInterval]
  /// and retransmits unacknowledged reliable packets. Connect retries do
  /// not depend on this being called.
  void update() {
    if (_state != ClientState.connected) return;

    final now = clock.nowMs;

    // Check for timeout
    if (now - _lastReceiveMs > connectionTimeout.inMilliseconds) {
      _setState(ClientState.failed, 'Connection timeout');
      return;
    }

    // Send periodic pings
    final lastPing = _lastPingMs;
    if (lastPing == null || now - lastPing >= pingInterval.inMilliseconds) {
      _lastPingMs = now;
      _sendPing();
    }

    // Retransmit reliable packets
    _retransmitReliable(now);
  }

  void _setState(ClientState newState, [String? reason]) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(ConnectionStateEvent(newState, reason));
    }
  }

  void _completeConnect(bool result) {
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _failConnect(String reason) {
    _stopConnectRetries();
    _setState(ClientState.failed, reason);
    _completeConnect(false);
  }

  void _stopConnectRetries() {
    _connectRetryTimer?.cancel();
    _connectRetryTimer = null;
  }

  Future<String> _resolveHost(String host) async {
    final resolver = hostResolver;
    if (resolver != null) return resolver(host);
    if (InternetAddress.tryParse(host) != null) return host;

    final results = await InternetAddress.lookup(host);
    if (results.isEmpty) {
      throw SocketException('No addresses found', osError: null);
    }
    final ipv4 = results.where((a) => a.type == InternetAddressType.IPv4);
    return (ipv4.isNotEmpty ? ipv4.first : results.first).address;
  }

  void _handlePacket(ReceivedPacket received) {
    // Verify packet is from host
    if (_hostAddress != null && received.source != _hostAddress) {
      return;
    }

    try {
      _handleHostPacket(received);
    } on RangeError {
      // Truncated / malformed payload: drop it.
    } on FormatException {
      // Invalid UTF-8 or similar in a payload: drop it.
    }
  }

  void _handleHostPacket(ReceivedPacket received) {
    final packet = Packet.fromBytes(received.data);
    if (packet == null) {
      // If the packet has our magic but a mismatched protocol version, the
      // peer is speaking an incompatible dialect. Surface a clear error to
      // the caller instead of silently dropping-and-timing-out.
      final peerVersion = PacketHeader.peekVersion(received.data);
      if (peerVersion != null && peerVersion != PacketHeader.version) {
        _mismatchController.add(
          ProtocolMismatchEvent(
            source: received.source,
            localVersion: PacketHeader.version,
            remoteVersion: peerVersion,
          ),
        );
        _failConnect(
          'Protocol version mismatch: local v${PacketHeader.version}, '
          'server v$peerVersion',
        );
      }
      return;
    }

    _lastReceiveMs = clock.nowMs;

    // Update sequence tracking
    _processReceivedSequence(packet.header.sequence);
    _processAck(packet.header.ack, packet.header.ackBits);

    // Handle packet type
    switch (packet.header.type) {
      case PacketType.connectAccepted:
        _handleConnectAccepted(packet.payload);

      case PacketType.connectRejected:
        _handleConnectRejected(packet.payload);

      case PacketType.disconnect:
        final reader = PacketReader(packet.payload);
        final reason = reader.readString();
        _setState(ClientState.disconnected, reason);

      case PacketType.ping:
        // Host is measuring its RTT to us: echo its timestamp back.
        final echoed = packet.payload.length >= 4
            ? PacketReader(packet.payload).readUint32()
            : packet.header.timestamp;
        _sendToHostSafely(
          PacketType.pong,
          (PacketBuilder()..writeUint32(echoed)).build(),
        );

      case PacketType.pong:
        if (packet.payload.length >= 4) {
          _updateRtt(PacketReader(packet.payload).readUint32());
        }

      default:
        // Forward to game logic
        _dataController.add(HostDataEvent(packet.header.type, packet.payload));
    }
  }

  void _handleConnectAccepted(Uint8List payload) {
    // Duplicates (retransmits, re-sent acceptances) are expected.
    if (_state != ClientState.connecting) return;
    final reader = PacketReader(payload);
    _localPeerId = reader.readInt32();
    _stopConnectRetries();
    _lastPingMs = null; // ping on the first update()
    _setState(ClientState.connected);
    _completeConnect(true);
  }

  void _handleConnectRejected(Uint8List payload) {
    if (_state != ClientState.connecting) return;
    final reader = PacketReader(payload);
    final reason = reader.readString();
    _failConnect(reason);
  }

  void _processReceivedSequence(int sequence) {
    _recentReceivedSequences.add(sequence);
    if (_recentReceivedSequences.length > 32) {
      _recentReceivedSequences.removeAt(0);
    }

    if (_isSequenceNewer(sequence, _lastReceivedSequence)) {
      _lastReceivedSequence = sequence;
    }
  }

  int _getAckBits() {
    int bits = 0;
    for (final seq in _recentReceivedSequences) {
      final diff = (_lastReceivedSequence - seq) & 0xFFFF;
      if (diff > 0 && diff <= 32) {
        bits |= 1 << (diff - 1);
      }
    }
    return bits;
  }

  int get _nextSequence {
    _lastSentSequence = (_lastSentSequence + 1) & 0xFFFF;
    return _lastSentSequence;
  }

  Uint8List _buildPacket(PacketType type, Uint8List payload, int sequence) {
    final header = PacketHeader(
      type: type,
      sequence: sequence,
      ack: _lastReceivedSequence,
      ackBits: _getAckBits(),
      timestamp: clock.nowMs32,
    );
    return Packet(header: header, payload: payload).toBytes();
  }

  Future<void> _sendToHost(PacketType type, Uint8List payload) async {
    final host = _hostAddress;
    if (host == null) return;

    final sequence = _nextSequence;
    final data = _buildPacket(type, payload, sequence);
    await transport.send(host, data);

    // Queue reliable packets for retransmission
    if (type.isReliable) {
      _pendingReliable.add(
        _ClientPendingPacket(
          sequence: sequence,
          data: data,
          sentMs: clock.nowMs,
        ),
      );
    }
  }

  /// Fire-and-forget send that swallows transport errors (e.g. the
  /// transport was closed concurrently).
  void _sendToHostSafely(PacketType type, Uint8List payload) {
    unawaited(_sendToHost(type, payload).catchError((Object _) {}));
  }

  void _processAck(int ack, int ackBits) {
    _pendingReliable.removeWhere((pending) {
      if (pending.sequence == ack) return true;
      final diff = (ack - pending.sequence) & 0xFFFF;
      if (diff > 0 && diff <= 32) {
        final bit = 1 << (diff - 1);
        if ((ackBits & bit) != 0) return true;
      }
      return false;
    });
  }

  void _retransmitReliable(int nowMs) {
    final timeoutMs = retransmitTimeout.inMilliseconds;

    _pendingReliable.removeWhere((p) => p.retransmitCount >= _maxRetransmits);

    final host = _hostAddress;
    if (host == null) return;
    for (final pending in _pendingReliable) {
      if (nowMs - pending.sentMs > timeoutMs) {
        pending.sentMs = nowMs;
        pending.retransmitCount++;
        unawaited(transport.send(host, pending.data).catchError((Object _) {}));
      }
    }
  }

  Uint8List _buildConnectPacket() {
    final builder = PacketBuilder()
      ..writeString('FledgeClient'); // Client identifier
    final credentials = _credentials;
    if (credentials != null) {
      builder.writeBytes(credentials);
    } else {
      builder.writeUint16(0); // No credentials
    }
    // Retries resend these exact bytes; the connect handshake has its own
    // retry loop, so it is not queued with the other reliable packets.
    return _buildPacket(PacketType.connect, builder.build(), _nextSequence);
  }

  Future<void> _sendConnectAttempt() async {
    final host = _hostAddress;
    final packet = _connectPacket;
    if (_state != ClientState.connecting || host == null || packet == null) {
      return;
    }
    try {
      await transport.send(host, packet);
    } on StateError {
      // Transport closed while connecting (e.g. disconnect()); ignore.
    }
  }

  void _sendPing() {
    final builder = PacketBuilder()..writeUint32(clock.nowMs32);
    _sendToHostSafely(PacketType.ping, builder.build());
  }

  void _updateRtt(int echoedTimestamp) {
    final sample = NetClock.elapsed32(clock.nowMs32, echoedTimestamp);
    if (sample < 0 || sample > Peer.maxRttSampleMs) return;

    if (rtt == 0) {
      rtt = sample < 1 ? 1 : sample.toDouble();
    } else {
      rtt = rtt * 0.9 + sample * 0.1;
    }
  }

  bool _isSequenceNewer(int seq1, int seq2) {
    return ((seq1 > seq2) && (seq1 - seq2 <= 32768)) ||
        ((seq1 < seq2) && (seq2 - seq1 > 32768));
  }
}

class _ClientPendingPacket {
  final int sequence;
  final Uint8List data;
  int sentMs;
  int retransmitCount = 0;

  _ClientPendingPacket({
    required this.sequence,
    required this.data,
    required this.sentMs,
  });
}
