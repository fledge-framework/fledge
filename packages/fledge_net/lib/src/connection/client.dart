import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
import '../protocol/packet.dart';
import '../transport/encrypted_transport.dart';
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
/// The client connects to a host by address or hostname (retrying the
/// connect request until answered), pings it for RTT, detects a silent
/// host and exchanges datagrams with it.
///
/// Every send is a single unreliable datagram. For reliable, ordered
/// delivery layer a `ReliableChannel` over [PacketType.replication] (or
/// your own type), as the replication layer does.
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

  /// Monotonic clock used for ping timestamps, RTT, ping cadence and the
  /// connected-state timeout.
  final NetClock clock;

  /// Default for [disconnectRedundancy].
  static const int defaultDisconnectRedundancy = 3;

  /// Default for [disconnectRedundancyInterval].
  static const Duration defaultDisconnectRedundancyInterval = Duration(
    milliseconds: 5,
  );

  /// How many copies of the `disconnect` notice [disconnect] sends before
  /// closing the transport, so a single lost datagram does not leave the
  /// host waiting for its connection timeout. The host ignores the
  /// duplicates. Must be at least 1.
  final int disconnectRedundancy;

  /// Delay between the copies counted by [disconnectRedundancy] (spreads
  /// them past short loss bursts and lets a busy socket drain).
  /// [disconnect] waits at most
  /// `(disconnectRedundancy - 1) * disconnectRedundancyInterval`.
  final Duration disconnectRedundancyInterval;

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

  /// In-flight [disconnect], shared by concurrent callers.
  Future<void>? _disconnecting;

  NetworkClient({
    required this.transport,
    this.connectionTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 1),
    this.connectRetryInterval = const Duration(milliseconds: 250),
    NetClock? clock,
    this.hostResolver,
    this.disconnectRedundancy = defaultDisconnectRedundancy,
    this.disconnectRedundancyInterval = defaultDisconnectRedundancyInterval,
  }) : clock = clock ?? NetClock.system {
    if (disconnectRedundancy < 1) {
      throw ArgumentError.value(
        disconnectRedundancy,
        'disconnectRedundancy',
        'must be at least 1',
      );
    }
  }

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

  /// Reason given with the most recent state change that carried one
  /// (e.g. `Authentication failed`, `Connection timeout`, the host
  /// disconnect reason). Never contains credentials.
  String? get lastStateReason => _lastReason;
  String? _lastReason;

  /// Host address (numeric, after hostname resolution).
  NetAddress? get hostAddress => _hostAddress;

  /// Credentials to send during connection handshake.
  Uint8List? _credentials;

  /// The identity to present during the handshake.
  String _clientId = anonymousClientId;

  /// Connect to a host.
  ///
  /// [host] may be a numeric address or a hostname such as `'localhost'`;
  /// hostnames are resolved first (IPv4 preferred, see [hostResolver]).
  /// The connect request is re-sent every [connectRetryInterval] until the
  /// host accepts or rejects it, or [connectionTimeout] elapses.
  ///
  /// [clientId] is the player identity to present (see `ClientIdentity`);
  /// without one the client is anonymous. Optionally provide [credentials]
  /// for authentication (e.g., password hash, token). The host's
  /// authenticator callback receives both.
  Future<bool> connect(
    String host,
    int port, {
    String clientId = anonymousClientId,
    Uint8List? credentials,
  }) async {
    if (_state != ClientState.disconnected) {
      throw StateError('Client not disconnected');
    }
    _clientId = clientId;
    _credentials = credentials;

    _setState(ClientState.connecting);
    final completer = _connectCompleter = Completer<bool>();

    try {
      final NetAddress address;
      try {
        final resolver = _addressResolverOf(transport);
        address = resolver != null
            ? await resolver.resolve(host, port)
            : NetAddress(await _resolveHost(host), port);
      } catch (e) {
        _failConnect('Could not resolve host "$host": $e');
        return false;
      }
      if (_state != ClientState.connecting) return false;
      _hostAddress = address;

      // Bind to any available port
      await transport.bind(0);
      _transportBound = true;

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
  ///
  /// When connected, sends [disconnectRedundancy] identical `disconnect`
  /// notices (spaced by [disconnectRedundancyInterval]) and then closes
  /// the transport. Concurrent calls share one disconnect.
  Future<void> disconnect() {
    if (_state == ClientState.disconnected) return Future<void>.value();
    return _disconnecting ??= _disconnect().whenComplete(
      () => _disconnecting = null,
    );
  }

  Future<void> _disconnect() async {
    _stopConnectRetries();
    _completeConnect(false);

    final host = _hostAddress;
    if (_state == ClientState.connected && host != null) {
      final builder = PacketBuilder()..writeString('Client disconnecting');
      final data = _buildPacket(
        PacketType.disconnect,
        builder.build(),
        _nextSequence,
      );
      await transport.send(host, data);
      // Further copies are best effort.
      for (var copy = 1; copy < disconnectRedundancy; copy++) {
        if (disconnectRedundancyInterval > Duration.zero) {
          await Future<void>.delayed(disconnectRedundancyInterval);
        }
        try {
          await transport.send(host, data);
        } catch (_) {
          break; // Transport closed or failing.
        }
      }
    }

    await _closeTransport();
    _setState(ClientState.disconnected);
    _hostAddress = null;
    _localPeerId = null;
  }

  /// Whether [transport] was bound by [connect] and not closed since.
  bool _transportBound = false;

  /// Closes [transport] once, however the connection ended.
  Future<void> _closeTransport() async {
    if (!_transportBound) return;
    _transportBound = false;
    await transport.close();
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
  /// Checks the connection timeout and pings the host every
  /// [pingInterval]. Connect retries do not depend on this being called.
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
  }

  void _setState(ClientState newState, [String? reason]) {
    if (_state != newState) {
      _state = newState;
      if (reason != null) _lastReason = reason;
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

  /// The [AddressResolver] behind [t], looking through encryption, so a
  /// Steam transport wrapped in [EncryptedTransport] still resolves
  /// `steam:` hosts.
  static AddressResolver? _addressResolverOf(Transport t) => switch (t) {
    AddressResolver() => t as AddressResolver,
    EncryptedTransport(:final inner) => _addressResolverOf(inner),
    _ => null,
  };

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

    // Handle packet type
    switch (packet.header.type) {
      case PacketType.connectAccepted:
        _handleConnectAccepted(packet.payload);

      case PacketType.connectRejected:
        _handleConnectRejected(packet.payload);

      case PacketType.disconnect:
        final reader = PacketReader(packet.payload);
        final reason = reader.readString();
        _stopConnectRetries();
        _completeConnect(false);
        _setState(ClientState.disconnected, reason);
        _hostAddress = null;
        _localPeerId = null;
        // disconnect() returns early once we're disconnected, so release
        // the socket here (host kick or shutdown).
        unawaited(_closeTransport());

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
    // Duplicates (re-sent acceptances, duplicated datagrams) are expected.
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

    final data = _buildPacket(type, payload, _nextSequence);
    await transport.send(host, data);
  }

  /// Fire-and-forget send that swallows transport errors (e.g. the
  /// transport was closed concurrently).
  void _sendToHostSafely(PacketType type, Uint8List payload) {
    unawaited(_sendToHost(type, payload).catchError((Object _) {}));
  }

  Uint8List _buildConnectPacket() {
    final builder = PacketBuilder()
      ..writeString(_clientId); // Who this player is
    final credentials = _credentials;
    if (credentials != null) {
      builder.writeBytes(credentials);
    } else {
      builder.writeUint16(0); // No credentials
    }
    // Retries resend these exact bytes until the host answers.
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
    } catch (_) {
      // Transport closed while connecting (e.g. disconnect()) or a socket
      // error: the next retry (or the timeout) takes over. Retries run
      // from a Timer, so nothing may escape as an unhandled error.
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
