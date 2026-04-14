import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../protocol/packet.dart';
import '../transport/transport.dart';

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
/// - Connects to a host by address
/// - Sends inputs to the host
/// - Receives state updates from the host
/// - Predicts local state for responsiveness
class NetworkClient {
  /// Transport for network communication.
  final Transport transport;

  /// Connection timeout duration.
  final Duration connectionTimeout;

  /// Ping interval.
  final Duration pingInterval;

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

  /// Round-trip time in milliseconds.
  double rtt = 0;

  /// Pending reliable packets waiting for acknowledgment.
  final Queue<_ClientPendingPacket> _pendingReliable = Queue();

  /// Maximum retransmit attempts before dropping.
  static const int _maxRetransmits = 10;

  /// Time of last received packet.
  DateTime _lastReceiveTime = DateTime.now();

  /// Time of last sent ping.
  DateTime _lastPingTime = DateTime.now();

  /// Event controllers.
  final _stateController = StreamController<ConnectionStateEvent>.broadcast();
  final _dataController = StreamController<HostDataEvent>.broadcast();

  /// Completer for connect operation.
  Completer<bool>? _connectCompleter;

  NetworkClient({
    required this.transport,
    this.connectionTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 1),
  });

  /// Stream of connection state changes.
  Stream<ConnectionStateEvent> get onStateChange => _stateController.stream;

  /// Stream of data received from host.
  Stream<HostDataEvent> get onData => _dataController.stream;

  /// Current connection state.
  ClientState get state => _state;

  /// Whether connected to a host.
  bool get isConnected => _state == ClientState.connected;

  /// Local peer ID assigned by host.
  int? get localPeerId => _localPeerId;

  /// Host address.
  NetAddress? get hostAddress => _hostAddress;

  /// Credentials to send during connection handshake.
  Uint8List? _credentials;

  /// Connect to a host.
  ///
  /// Optionally provide [credentials] for authentication (e.g., password hash,
  /// token). The host's authenticator callback receives these credentials.
  Future<bool> connect(String host, int port, {Uint8List? credentials}) async {
    _credentials = credentials;
    if (_state != ClientState.disconnected) {
      throw StateError('Client not disconnected');
    }

    _setState(ClientState.connecting);
    _hostAddress = NetAddress(host, port);

    try {
      // Bind to any available port
      await transport.bind(0);

      // Start listening for packets
      transport.onReceive.listen(_handlePacket);

      // Send connect request
      _connectCompleter = Completer<bool>();
      await _sendConnect();

      // Wait for response or timeout
      final result = await _connectCompleter!.future.timeout(connectionTimeout,
          onTimeout: () {
        _setState(ClientState.failed, 'Connection timeout');
        return false;
      });

      return result;
    } catch (e) {
      _setState(ClientState.failed, e.toString());
      return false;
    }
  }

  /// Disconnect from host.
  Future<void> disconnect() async {
    if (_state == ClientState.disconnected) return;

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
  Future<void> send(PacketType type, Uint8List data) async {
    if (!isConnected || _hostAddress == null) {
      throw StateError('Not connected');
    }

    await _sendToHost(type, data);
  }

  /// Update client (call every frame).
  void update() {
    if (_state != ClientState.connected) return;

    final now = DateTime.now();

    // Check for timeout
    if (now.difference(_lastReceiveTime) > connectionTimeout) {
      _setState(ClientState.failed, 'Connection timeout');
      return;
    }

    // Send periodic pings
    if (now.difference(_lastPingTime) > pingInterval) {
      _sendPing();
      _lastPingTime = now;
    }

    // Retransmit reliable packets
    _retransmitReliable();
  }

  void _setState(ClientState newState, [String? reason]) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(ConnectionStateEvent(newState, reason));
    }
  }

  void _handlePacket(ReceivedPacket received) {
    // Verify packet is from host
    if (_hostAddress != null && received.source != _hostAddress) {
      return;
    }

    final packet = Packet.fromBytes(received.data);
    if (packet == null) return;

    _lastReceiveTime = DateTime.now();

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

      case PacketType.pong:
        final reader = PacketReader(packet.payload);
        final pingTimestamp = reader.readInt32();
        _updateRtt(pingTimestamp);

      default:
        // Forward to game logic
        _dataController.add(HostDataEvent(
          packet.header.type,
          packet.payload,
        ));
    }
  }

  void _handleConnectAccepted(Uint8List payload) {
    final reader = PacketReader(payload);
    _localPeerId = reader.readInt32();
    _setState(ClientState.connected);
    _connectCompleter?.complete(true);
  }

  void _handleConnectRejected(Uint8List payload) {
    final reader = PacketReader(payload);
    final reason = reader.readString();
    _setState(ClientState.failed, reason);
    _connectCompleter?.complete(false);
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

  Future<void> _sendToHost(PacketType type, Uint8List payload) async {
    if (_hostAddress == null) return;

    final header = PacketHeader(
      type: type,
      sequence: _nextSequence,
      ack: _lastReceivedSequence,
      ackBits: _getAckBits(),
    );

    final packet = Packet(header: header, payload: payload);
    final data = packet.toBytes();
    await transport.send(_hostAddress!, data);

    // Queue reliable packets for retransmission
    if (type.isReliable) {
      _pendingReliable.add(_ClientPendingPacket(
        sequence: header.sequence,
        data: data,
        sentTime: DateTime.now(),
      ));
    }
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

  void _retransmitReliable() {
    final now = DateTime.now();
    final timeout = rtt > 0
        ? Duration(milliseconds: (rtt * 2.0).clamp(100, 5000).toInt())
        : const Duration(milliseconds: 100);

    _pendingReliable.removeWhere((p) => p.retransmitCount >= _maxRetransmits);

    for (final pending in _pendingReliable) {
      if (now.difference(pending.sentTime) > timeout) {
        pending.sentTime = now;
        pending.retransmitCount++;
        if (_hostAddress != null) {
          transport.send(_hostAddress!, pending.data);
        }
      }
    }
  }

  Future<void> _sendConnect() async {
    final builder = PacketBuilder()
      ..writeString('FledgeClient'); // Client identifier
    if (_credentials != null) {
      builder.writeBytes(_credentials!);
    } else {
      builder.writeInt16(0); // No credentials
    }
    await _sendToHost(PacketType.connect, builder.build());
  }

  Future<void> _sendPing() async {
    final builder = PacketBuilder()
      ..writeInt32(DateTime.now().millisecondsSinceEpoch);
    await _sendToHost(PacketType.ping, builder.build());
  }

  void _updateRtt(int sentTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sample = (now - sentTimestamp).toDouble();

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

class _ClientPendingPacket {
  final int sequence;
  final Uint8List data;
  DateTime sentTime;
  int retransmitCount = 0;

  _ClientPendingPacket({
    required this.sequence,
    required this.data,
    required this.sentTime,
  });
}
