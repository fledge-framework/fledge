import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
import '../protocol/packet.dart';
import '../transport/transport.dart';
import 'peer.dart';
import 'protocol_mismatch.dart';

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
  ///
  /// While a connect from an address is being authenticated, further
  /// connects from that address are ignored, so a retransmitted or
  /// duplicated connect never creates a second peer.
  final Future<bool> Function(String clientId, Uint8List credentials)?
  authenticator;

  /// How often [update] pings each peer to measure [Peer.rtt].
  ///
  /// A newly connected peer is pinged on the first [update] after it
  /// connects.
  final Duration pingInterval;

  /// Monotonic clock used for ping timestamps, RTT, peer timeouts and
  /// reliable retransmits.
  final NetClock clock;

  /// Default for [disconnectRedundancy].
  static const int defaultDisconnectRedundancy = 3;

  /// Default for [disconnectRedundancyInterval].
  static const Duration defaultDisconnectRedundancyInterval = Duration(
    milliseconds: 5,
  );

  /// How many copies of a `disconnect` notice [disconnectPeer] and [stop]
  /// send to each peer, so a single lost datagram does not leave the
  /// client waiting for its connection timeout. Clients ignore the
  /// duplicates. Must be at least 1.
  final int disconnectRedundancy;

  /// Delay between the copies counted by [disconnectRedundancy] (spreads
  /// them past short loss bursts). [disconnectPeer] and [stop] wait at most
  /// `(disconnectRedundancy - 1) * disconnectRedundancyInterval`.
  final Duration disconnectRedundancyInterval;

  /// Room code for joining (generated on creation).
  late final String roomCode;

  /// Whether the host is running.
  bool _running = false;

  /// Set while [stop] sends its final disconnect notices; inbound traffic
  /// is ignored meanwhile.
  bool _stopping = false;

  /// Connected peers by ID.
  final Map<int, Peer> _peers = {};

  /// Address to peer mapping.
  final Map<NetAddress, Peer> _peersByAddress = {};

  /// Addresses whose connect request is awaiting the [authenticator].
  final Set<NetAddress> _pendingConnects = {};

  /// Last ping time per peer ID ([clock] milliseconds).
  final Map<int, int> _lastPingMs = {};

  /// Next peer ID to assign.
  int _nextPeerId = 1;

  /// Event controllers.
  final _connectController = StreamController<PeerConnectedEvent>.broadcast();
  final _disconnectController =
      StreamController<PeerDisconnectedEvent>.broadcast();
  final _dataController = StreamController<PeerDataEvent>.broadcast();
  final _mismatchController =
      StreamController<ProtocolMismatchEvent>.broadcast();

  NetworkHost({
    required this.transport,
    this.maxPeers = 8,
    this.connectionTimeout = const Duration(seconds: 10),
    this.retransmitTimeout = const Duration(milliseconds: 100),
    this.authenticator,
    this.pingInterval = const Duration(seconds: 1),
    NetClock? clock,
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

  /// Datagrams from senders speaking a different protocol version.
  ///
  /// A mismatched `connect` is also answered with a `connectRejected`
  /// whose reason reads `Protocol version mismatch: host vX, client vY`.
  Stream<ProtocolMismatchEvent> get onProtocolMismatch =>
      _mismatchController.stream;

  /// All connected peers.
  Iterable<Peer> get peers => _peers.values;

  /// Number of connected peers.
  int get peerCount => _peers.length;

  /// The connected peer with [id], or `null`.
  Peer? getPeer(int id) => _peers[id];

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
  ///
  /// Every peer is sent [disconnectRedundancy] copies of a disconnect
  /// notice (reason `Host shutting down`) before the transport closes.
  Future<void> stop() async {
    if (!_running || _stopping) return;
    _stopping = true;
    try {
      await _disconnectPeers(_peers.values.toList(), 'Host shutting down');
    } finally {
      _stopping = false;
      _running = false;
      _pendingConnects.clear();
      _lastPingMs.clear();
      await transport.close();
    }
  }

  /// Disconnect a specific peer.
  ///
  /// The peer is removed (and [onPeerDisconnected] fires) right after the
  /// first of [disconnectRedundancy] notice copies is sent.
  Future<void> disconnectPeer(int peerId, String reason) async {
    final peer = _peers[peerId];
    if (peer == null) return;
    await _disconnectPeers([peer], reason);
  }

  /// Send each of [peers] [disconnectRedundancy] identical `disconnect`
  /// datagrams carrying [reason], removing them after the first round.
  Future<void> _disconnectPeers(List<Peer> peers, String reason) async {
    if (peers.isEmpty) return;
    final payload = (PacketBuilder()..writeString(reason)).build();
    final notices = <(NetAddress, Uint8List)>[];
    for (final peer in peers) {
      peer.state = PeerState.disconnecting;
      notices.add((
        peer.address,
        _buildPacket(peer, PacketType.disconnect, payload),
      ));
    }

    for (final (address, data) in notices) {
      await transport.send(address, data);
    }
    for (final peer in peers) {
      peer.markSent();
      if (identical(_peers[peer.id], peer)) _removePeer(peer, reason);
    }

    // Further copies are best effort: the peers are already gone.
    for (var copy = 1; copy < disconnectRedundancy; copy++) {
      if (disconnectRedundancyInterval > Duration.zero) {
        await Future<void>.delayed(disconnectRedundancyInterval);
      }
      for (final (address, data) in notices) {
        try {
          await transport.send(address, data);
        } catch (_) {
          // Transport closed or failing: nothing more to do.
        }
      }
    }
  }

  /// Send data to a specific peer.
  ///
  /// Throws [ArgumentError] if [data] exceeds [Packet.maxPayloadBytes].
  Future<void> sendTo(int peerId, PacketType type, Uint8List data) async {
    Packet.checkPayloadSize(data);
    final peer = _peers[peerId];
    if (peer == null || !peer.isConnected) return;

    await _sendToPeer(peer, type, data);
  }

  /// Broadcast data to all connected peers.
  ///
  /// Throws [ArgumentError] (before sending anything) if [data] exceeds
  /// [Packet.maxPayloadBytes].
  Future<void> broadcast(PacketType type, Uint8List data) async {
    Packet.checkPayloadSize(data);
    for (final peer in _peers.values.toList()) {
      if (peer.isConnected) {
        await _sendToPeer(peer, type, data);
      }
    }
  }

  /// Broadcast data to all peers except one.
  ///
  /// Throws [ArgumentError] (before sending anything) if [data] exceeds
  /// [Packet.maxPayloadBytes].
  Future<void> broadcastExcept(
    int excludeId,
    PacketType type,
    Uint8List data,
  ) async {
    Packet.checkPayloadSize(data);
    for (final peer in _peers.values.toList()) {
      if (peer.isConnected && peer.id != excludeId) {
        await _sendToPeer(peer, type, data);
      }
    }
  }

  /// Update host (call every frame).
  ///
  /// Times out silent peers, pings peers every [pingInterval] (for
  /// [Peer.rtt]) and retransmits unacknowledged reliable packets.
  void update() {
    if (!_running || _stopping) return;

    final nowMs = clock.nowMs;

    for (final peer in _peers.values.toList()) {
      // Check for timeouts
      if (peer.timeSinceLastReceive > connectionTimeout) {
        _removePeer(peer, 'Connection timeout');
        continue;
      }

      // Periodic ping for RTT measurement
      final lastPing = _lastPingMs[peer.id];
      if (lastPing == null || nowMs - lastPing >= pingInterval.inMilliseconds) {
        _lastPingMs[peer.id] = nowMs;
        _sendPing(peer);
      }

      // Retransmit reliable packets
      final retransmits = peer.getPacketsToRetransmit(retransmitTimeout);
      for (final data in retransmits) {
        transport.send(peer.address, data);
      }
    }
  }

  void _handlePacket(ReceivedPacket received) {
    try {
      _handlePacketUnchecked(received);
    } on RangeError {
      // Truncated / malformed payload from the network: drop it.
    } on FormatException {
      // Invalid UTF-8 or similar in a payload: drop it.
    }
  }

  void _handlePacketUnchecked(ReceivedPacket received) {
    if (_stopping) return;
    final packet = Packet.fromBytes(received.data);
    if (packet == null) {
      _handleUnparseable(received);
      return;
    }

    // Find or create peer
    final peer = _peersByAddress[received.source];

    // A duplicate `disconnect` (clients send several copies) from an
    // address that has already left lands in the `peer == null` branch
    // below and is ignored.
    if (packet.header.type == PacketType.connect) {
      _handleConnect(received.source, packet, peer);
      return;
    }

    if (peer == null) {
      // Unknown peer, ignore
      return;
    }

    // Update peer state
    peer.processReceivedSequence(packet.header.sequence);
    peer.processAck(packet.header.ack, packet.header.ackBits);

    // Handle packet type
    switch (packet.header.type) {
      case PacketType.disconnect:
        _removePeer(peer, 'Client disconnected');

      case PacketType.ping:
        _sendPong(peer, packet);

      case PacketType.pong:
        // The payload echoes the timestamp from our own ping.
        if (packet.payload.length >= 4) {
          final echoed = PacketReader(packet.payload).readUint32();
          peer.updateRtt(echoed, nowTimestamp: clock.nowMs32);
        }

      default:
        // Forward to game logic
        _dataController.add(
          PeerDataEvent(peer, packet.header.type, packet.payload),
        );
    }
  }

  /// A datagram that isn't a valid packet for this protocol version.
  void _handleUnparseable(ReceivedPacket received) {
    final remoteVersion = PacketHeader.peekVersion(received.data);
    if (remoteVersion == null || remoteVersion == PacketHeader.version) {
      return; // Not our protocol at all (or merely malformed): drop.
    }

    _mismatchController.add(
      ProtocolMismatchEvent(
        source: received.source,
        localVersion: PacketHeader.version,
        remoteVersion: remoteVersion,
      ),
    );

    // Only answer connect attempts, so we never reply to arbitrary
    // traffic. The type byte sits at a fixed offset in every version.
    final isConnect =
        received.data.length > 5 &&
        received.data[5] == PacketType.connect.value;
    if (isConnect) {
      _sendReject(
        received.source,
        'Protocol version mismatch: host v${PacketHeader.version}, '
        'client v$remoteVersion',
      );
    }
  }

  void _handleConnect(NetAddress source, Packet packet, Peer? existing) {
    if (existing != null) {
      // The client is still retrying, so it never saw our acceptance.
      // Re-send it; peers are created once per address.
      if (existing.isConnected) _sendAccept(existing);
      return;
    }

    // A connect from this address is already being authenticated.
    if (_pendingConnects.contains(source)) return;

    if (_peers.length >= maxPeers) {
      _sendReject(source, 'Server full');
      return;
    }

    // Extract client identifier and credentials
    final reader = PacketReader(packet.payload);
    final clientId = reader.readString();
    final credentials = reader.hasMore ? reader.readBytes() : Uint8List(0);
    final sequence = packet.header.sequence;

    final auth = authenticator;
    if (auth == null) {
      // Accept new connection (no authentication configured)
      _sendAccept(_createPeer(source, sequence));
      return;
    }

    _pendingConnects.add(source);
    Future<bool>.sync(() => auth(clientId, credentials)).then(
      (accepted) => _finishConnect(source, sequence, accepted),
      onError: (Object _) => _finishConnect(source, sequence, false),
    );
  }

  void _finishConnect(NetAddress source, int sequence, bool accepted) {
    _pendingConnects.remove(source);
    if (!_running || _peersByAddress.containsKey(source)) return;

    if (!accepted) {
      _sendReject(source, 'Authentication failed');
      return;
    }
    // Capacity may have filled up while authentication was in flight.
    if (_peers.length >= maxPeers) {
      _sendReject(source, 'Server full');
      return;
    }
    _sendAccept(_createPeer(source, sequence));
  }

  Peer _createPeer(NetAddress address, int connectSequence) {
    final peer = Peer(
      id: _nextPeerId++,
      address: address,
      state: PeerState.connected,
      clock: clock,
    );
    // Acknowledge the connect packet in our first reply.
    peer.processReceivedSequence(connectSequence);

    _peers[peer.id] = peer;
    _peersByAddress[address] = peer;
    _connectController.add(PeerConnectedEvent(peer));

    return peer;
  }

  void _removePeer(Peer peer, String reason) {
    peer.state = PeerState.disconnected;
    _peers.remove(peer.id);
    _peersByAddress.remove(peer.address);
    _lastPingMs.remove(peer.id);
    _disconnectController.add(PeerDisconnectedEvent(peer, reason));
  }

  Future<void> _sendToPeer(
    Peer peer,
    PacketType type,
    Uint8List payload,
  ) async {
    final data = _buildPacket(peer, type, payload);
    final sequence = peer.lastSentSequence;

    await transport.send(peer.address, data);
    peer.markSent();

    // Queue reliable packets for retransmission
    if (type.isReliable) {
      peer.addPendingReliable(sequence, data);
    }
  }

  /// Serialize a packet to [peer], consuming its next sequence number.
  Uint8List _buildPacket(Peer peer, PacketType type, Uint8List payload) {
    Packet.checkPayloadSize(payload);
    final header = PacketHeader(
      type: type,
      sequence: peer.nextSequence,
      ack: peer.lastReceivedSequence,
      ackBits: peer.getAckBits(),
      timestamp: clock.nowMs32,
    );
    return Packet(header: header, payload: payload).toBytes();
  }

  Future<void> _sendReject(NetAddress address, String reason) async {
    final builder = PacketBuilder()..writeString(reason);
    final header = PacketHeader(
      type: PacketType.connectRejected,
      sequence: 0,
      timestamp: clock.nowMs32,
    );
    final packet = Packet(header: header, payload: builder.build());
    await transport.send(address, packet.toBytes());
  }

  Future<void> _sendAccept(Peer peer) async {
    final builder = PacketBuilder()..writeInt32(peer.id);
    await _sendToPeer(peer, PacketType.connectAccepted, builder.build());
  }

  Future<void> _sendPing(Peer peer) async {
    final builder = PacketBuilder()..writeUint32(clock.nowMs32);
    await _sendToPeer(peer, PacketType.ping, builder.build());
  }

  /// Echo the sender's ping timestamp back unchanged.
  Future<void> _sendPong(Peer peer, Packet ping) async {
    final echoed = ping.payload.length >= 4
        ? PacketReader(ping.payload).readUint32()
        : ping.header.timestamp;
    final builder = PacketBuilder()..writeUint32(echoed);
    await _sendToPeer(peer, PacketType.pong, builder.build());
  }
}
