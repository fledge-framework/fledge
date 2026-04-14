import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/packet.dart';
import '../transport/transport.dart';
import 'peer.dart';

/// Event when a peer connects.
class PeerConnectedEvent {
  final Peer peer;
  PeerConnectedEvent(this.peer);
}

/// Event when a peer disconnects.
class PeerDisconnectedEvent {
  final Peer peer;
  final String reason;
  PeerDisconnectedEvent(this.peer, this.reason);
}

/// Event when data is received from a peer.
class PeerDataEvent {
  final Peer peer;
  final PacketType type;
  final Uint8List data;
  PeerDataEvent(this.peer, this.type, this.data);
}

/// Network host for authoritative game sessions.
///
/// The host:
/// - Accepts client connections
/// - Runs authoritative game simulation
/// - Broadcasts state updates to all clients
/// - Validates client inputs
class NetworkHost {
  /// Transport for network communication.
  final Transport transport;

  /// Maximum number of connected peers.
  final int maxPeers;

  /// Connection timeout duration.
  final Duration connectionTimeout;

  /// Retransmit timeout for reliable packets.
  final Duration retransmitTimeout;

  /// Optional authenticator for validating client connections.
  final Future<bool> Function(String clientId, Uint8List credentials)?
      authenticator;

  /// Room code for joining (generated on creation).
  late final String roomCode;

  /// Whether the host is running.
  bool _running = false;

  /// Connected peers by ID.
  final Map<int, Peer> _peers = {};

  /// Address to peer mapping.
  final Map<NetAddress, Peer> _peersByAddress = {};

  /// Next peer ID to assign.
  int _nextPeerId = 1;

  /// Event controllers.
  final _connectController = StreamController<PeerConnectedEvent>.broadcast();
  final _disconnectController =
      StreamController<PeerDisconnectedEvent>.broadcast();
  final _dataController = StreamController<PeerDataEvent>.broadcast();

  NetworkHost({
    required this.transport,
    this.maxPeers = 8,
    this.connectionTimeout = const Duration(seconds: 10),
    this.retransmitTimeout = const Duration(milliseconds: 100),
    this.authenticator,
  }) {
    // Generate random room code
    final random = Random.secure();
    roomCode = String.fromCharCodes(
      List.generate(6, (_) => random.nextInt(26) + 65),
    );
  }

  /// Stream of peer connect events.
  Stream<PeerConnectedEvent> get onPeerConnected => _connectController.stream;

  /// Stream of peer disconnect events.
  Stream<PeerDisconnectedEvent> get onPeerDisconnected =>
      _disconnectController.stream;

  /// Stream of data received from peers.
  Stream<PeerDataEvent> get onData => _dataController.stream;

  /// All connected peers.
  Iterable<Peer> get peers => _peers.values;

  /// Number of connected peers.
  int get peerCount => _peers.length;

  /// Whether the host is running.
  bool get isRunning => _running;

  /// Start hosting a session.
  Future<void> start(int port) async {
    if (_running) throw StateError('Host already running');

    await transport.bind(port);
    _running = true;

    // Start listening for packets
    transport.onReceive.listen(_handlePacket);
  }

  /// Stop hosting.
  Future<void> stop() async {
    if (!_running) return;

    // Disconnect all peers
    for (final peer in _peers.values.toList()) {
      await disconnectPeer(peer.id, 'Host shutting down');
    }

    await transport.close();
    _running = false;
  }

  /// Disconnect a specific peer.
  Future<void> disconnectPeer(int peerId, String reason) async {
    final peer = _peers[peerId];
    if (peer == null) return;

    peer.state = PeerState.disconnecting;

    // Send disconnect packet
    final builder = PacketBuilder()..writeString(reason);
    await _sendToPeer(peer, PacketType.disconnect, builder.build());

    _removePeer(peer, reason);
  }

  /// Send data to a specific peer.
  Future<void> sendTo(int peerId, PacketType type, Uint8List data) async {
    final peer = _peers[peerId];
    if (peer == null || !peer.isConnected) return;

    await _sendToPeer(peer, type, data);
  }

  /// Broadcast data to all connected peers.
  Future<void> broadcast(PacketType type, Uint8List data) async {
    for (final peer in _peers.values) {
      if (peer.isConnected) {
        await _sendToPeer(peer, type, data);
      }
    }
  }

  /// Broadcast data to all peers except one.
  Future<void> broadcastExcept(
      int excludeId, PacketType type, Uint8List data) async {
    for (final peer in _peers.values) {
      if (peer.isConnected && peer.id != excludeId) {
        await _sendToPeer(peer, type, data);
      }
    }
  }

  /// Update host (call every frame).
  void update() {
    if (!_running) return;

    // Check for timeouts
    for (final peer in _peers.values.toList()) {
      if (peer.timeSinceLastReceive > connectionTimeout) {
        _removePeer(peer, 'Connection timeout');
        continue;
      }

      // Retransmit reliable packets
      final retransmits = peer.getPacketsToRetransmit(retransmitTimeout);
      for (final data in retransmits) {
        transport.send(peer.address, data);
      }
    }
  }

  void _handlePacket(ReceivedPacket received) {
    final packet = Packet.fromBytes(received.data);
    if (packet == null) return;

    // Find or create peer
    var peer = _peersByAddress[received.source];

    if (packet.header.type == PacketType.connect) {
      if (peer != null) {
        // Already connecting/connected
        return;
      }

      if (_peers.length >= maxPeers) {
        _sendReject(received.source, 'Server full');
        return;
      }

      // Extract client identifier and credentials
      final reader = PacketReader(packet.payload);
      final clientId = reader.readString();
      final credentials = reader.hasMore ? reader.readBytes() : Uint8List(0);

      // Authenticate if authenticator is set
      if (authenticator != null) {
        authenticator!(clientId, credentials).then((accepted) {
          if (accepted) {
            final newPeer = _createPeer(received.source);
            _sendAccept(newPeer);
          } else {
            _sendReject(received.source, 'Authentication failed');
          }
        });
        return;
      }

      // Accept new connection (no authentication configured)
      peer = _createPeer(received.source);
      _sendAccept(peer);
      return;
    }

    if (peer == null) {
      // Unknown peer, ignore
      return;
    }

    // Update peer state
    peer.processReceivedSequence(packet.header.sequence);
    peer.processAck(packet.header.ack, packet.header.ackBits);
    peer.updateRtt(packet.header.timestamp);

    // Handle packet type
    switch (packet.header.type) {
      case PacketType.disconnect:
        _removePeer(peer, 'Client disconnected');

      case PacketType.ping:
        _sendPong(peer, packet.header.timestamp);

      case PacketType.pong:
      // RTT already updated above

      default:
        // Forward to game logic
        _dataController.add(PeerDataEvent(
          peer,
          packet.header.type,
          packet.payload,
        ));
    }
  }

  Peer _createPeer(NetAddress address) {
    final peer = Peer(
      id: _nextPeerId++,
      address: address,
      state: PeerState.connected,
    );

    _peers[peer.id] = peer;
    _peersByAddress[address] = peer;
    _connectController.add(PeerConnectedEvent(peer));

    return peer;
  }

  void _removePeer(Peer peer, String reason) {
    peer.state = PeerState.disconnected;
    _peers.remove(peer.id);
    _peersByAddress.remove(peer.address);
    _disconnectController.add(PeerDisconnectedEvent(peer, reason));
  }

  Future<void> _sendToPeer(
      Peer peer, PacketType type, Uint8List payload) async {
    final header = PacketHeader(
      type: type,
      sequence: peer.nextSequence,
      ack: peer.lastReceivedSequence,
      ackBits: peer.getAckBits(),
    );

    final packet = Packet(header: header, payload: payload);
    final data = packet.toBytes();

    await transport.send(peer.address, data);
    peer.lastSendTime = DateTime.now();

    // Queue reliable packets for retransmission
    if (type.isReliable) {
      peer.addPendingReliable(header.sequence, data);
    }
  }

  Future<void> _sendReject(NetAddress address, String reason) async {
    final builder = PacketBuilder()..writeString(reason);
    final header = PacketHeader(
      type: PacketType.connectRejected,
      sequence: 0,
    );
    final packet = Packet(header: header, payload: builder.build());
    await transport.send(address, packet.toBytes());
  }

  Future<void> _sendAccept(Peer peer) async {
    final builder = PacketBuilder()..writeInt32(peer.id);
    await _sendToPeer(peer, PacketType.connectAccepted, builder.build());
  }

  Future<void> _sendPong(Peer peer, int pingTimestamp) async {
    final builder = PacketBuilder()..writeInt32(pingTimestamp);
    await _sendToPeer(peer, PacketType.pong, builder.build());
  }
}
