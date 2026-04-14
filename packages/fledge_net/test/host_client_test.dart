import 'dart:async';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// In-memory transport for testing without real sockets.
class MockTransport extends Transport {
  ConnectionState _state = ConnectionState.disconnected;
  NetAddress? _localAddress;
  final _receiveController = StreamController<ReceivedPacket>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final List<ReceivedPacket> _pending = [];

  /// Sent packets, for inspection.
  final List<({NetAddress address, Uint8List data})> sentPackets = [];

  /// Paired transport (for simulating network).
  MockTransport? remote;

  @override
  ConnectionState get state => _state;

  @override
  NetAddress? get localAddress => _localAddress;

  @override
  Stream<ReceivedPacket> get onReceive => _receiveController.stream;

  @override
  Stream<ConnectionState> get onStateChange => _stateController.stream;

  @override
  Future<void> bind(int port) async {
    _localAddress = NetAddress('127.0.0.1', port == 0 ? 9999 : port);
    _state = ConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  Future<void> close() async {
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    sentPackets.add((address: address, data: Uint8List.fromList(data)));

    // Deliver to remote transport if paired
    if (remote != null) {
      final packet = ReceivedPacket(
        source: _localAddress!,
        data: Uint8List.fromList(data),
      );
      remote!._receiveController.add(packet);
      remote!._pending.add(packet);
    }
  }

  @override
  List<ReceivedPacket> receive() {
    final packets = List<ReceivedPacket>.from(_pending);
    _pending.clear();
    return packets;
  }

  /// Inject a packet as if received from the network.
  void injectPacket(NetAddress source, Uint8List data) {
    final packet = ReceivedPacket(source: source, data: data);
    _receiveController.add(packet);
    _pending.add(packet);
  }
}

/// Create a pair of linked mock transports.
(MockTransport, MockTransport) createLinkedTransports() {
  final a = MockTransport();
  final b = MockTransport();
  a.remote = b;
  b.remote = a;
  return (a, b);
}

void main() {
  group('NetworkHost', () {
    late MockTransport hostTransport;
    late NetworkHost host;

    setUp(() {
      hostTransport = MockTransport();
      host = NetworkHost(transport: hostTransport, maxPeers: 4);
    });

    test('generates a 6-character room code', () {
      expect(host.roomCode.length, 6);
      expect(host.roomCode, matches(RegExp(r'^[A-Z]{6}$')));
    });

    test('starts not running', () {
      expect(host.isRunning, false);
      expect(host.peerCount, 0);
    });

    test('start binds transport', () async {
      await host.start(7777);
      expect(host.isRunning, true);
      expect(hostTransport.state, ConnectionState.connected);
    });

    test('start throws if already running', () async {
      await host.start(7777);
      expect(() => host.start(7778), throwsStateError);
    });

    test('stop closes transport', () async {
      await host.start(7777);
      await host.stop();
      expect(host.isRunning, false);
    });

    test('accepts connection from client', () async {
      await host.start(7777);

      final events = <PeerConnectedEvent>[];
      host.onPeerConnected.listen(events.add);

      // Simulate connect packet from a client
      final builder = PacketBuilder()..writeString('TestClient');
      final header = PacketHeader(
        type: PacketType.connect,
        sequence: 0,
        timestamp: 0,
      );
      final packet = Packet(header: header, payload: builder.build());

      final clientAddr = const NetAddress('10.0.0.2', 5000);
      hostTransport.injectPacket(clientAddr, packet.toBytes());

      // Allow stream event to process
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 1);
      expect(events.length, 1);
      expect(events[0].peer.address, clientAddr);
      expect(events[0].peer.isConnected, true);
    });

    test('rejects connection when full', () async {
      host = NetworkHost(transport: hostTransport, maxPeers: 1);
      await host.start(7777);

      // Connect first client
      final connectPacket = _makeConnectPacket();
      hostTransport.injectPacket(
        const NetAddress('10.0.0.2', 5000),
        connectPacket,
      );
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 1);

      // Try to connect second client — should be rejected
      hostTransport.injectPacket(
        const NetAddress('10.0.0.3', 5001),
        connectPacket,
      );
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 1);

      // A reject packet should have been sent
      final rejectSent = hostTransport.sentPackets.where((s) {
        final p = Packet.fromBytes(s.data);
        return p?.header.type == PacketType.connectRejected;
      });
      expect(rejectSent, isNotEmpty);
    });

    test('ignores duplicate connect from same address', () async {
      await host.start(7777);

      final connectPacket = _makeConnectPacket();
      const addr = NetAddress('10.0.0.2', 5000);

      hostTransport.injectPacket(addr, connectPacket);
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 1);

      // Same address connects again
      hostTransport.injectPacket(addr, connectPacket);
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 1); // no duplicate
    });

    test('disconnect peer removes and notifies', () async {
      await host.start(7777);

      final disconnectEvents = <PeerDisconnectedEvent>[];
      host.onPeerDisconnected.listen(disconnectEvents.add);

      // Connect a peer
      const addr = NetAddress('10.0.0.2', 5000);
      hostTransport.injectPacket(addr, _makeConnectPacket());
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 1);

      final peerId = host.peers.first.id;
      await host.disconnectPeer(peerId, 'Kicked');
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 0);
      expect(disconnectEvents.length, 1);
      expect(disconnectEvents[0].reason, 'Kicked');
    });

    test('handles disconnect packet from peer', () async {
      await host.start(7777);

      final disconnectEvents = <PeerDisconnectedEvent>[];
      host.onPeerDisconnected.listen(disconnectEvents.add);

      const addr = NetAddress('10.0.0.2', 5000);
      hostTransport.injectPacket(addr, _makeConnectPacket());
      await Future<void>.delayed(Duration.zero);

      // Send disconnect from same address
      final builder = PacketBuilder()..writeString('Leaving');
      final header = PacketHeader(
        type: PacketType.disconnect,
        sequence: 1,
        timestamp: 0,
      );
      final disconnectPacket = Packet(header: header, payload: builder.build());
      hostTransport.injectPacket(addr, disconnectPacket.toBytes());
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 0);
      expect(disconnectEvents.length, 1);
      expect(disconnectEvents[0].reason, 'Client disconnected');
    });

    test('forwards game data packets to onData', () async {
      await host.start(7777);

      final dataEvents = <PeerDataEvent>[];
      host.onData.listen(dataEvents.add);

      const addr = NetAddress('10.0.0.2', 5000);
      hostTransport.injectPacket(addr, _makeConnectPacket());
      await Future<void>.delayed(Duration.zero);

      // Send input data from same address
      final payload = Uint8List.fromList([1, 2, 3]);
      final header = PacketHeader(
        type: PacketType.input,
        sequence: 1,
        timestamp: 0,
      );
      final dataPacket = Packet(header: header, payload: payload);
      hostTransport.injectPacket(addr, dataPacket.toBytes());
      await Future<void>.delayed(Duration.zero);

      expect(dataEvents.length, 1);
      expect(dataEvents[0].type, PacketType.input);
      expect(dataEvents[0].data, payload);
    });

    test('responds to ping with pong', () async {
      await host.start(7777);

      const addr = NetAddress('10.0.0.2', 5000);
      hostTransport.injectPacket(addr, _makeConnectPacket());
      await Future<void>.delayed(Duration.zero);

      hostTransport.sentPackets.clear();

      // Send ping
      final header = PacketHeader(
        type: PacketType.ping,
        sequence: 1,
        timestamp: 12345,
      );
      final pingPacket = Packet(header: header, payload: Uint8List(0));
      hostTransport.injectPacket(addr, pingPacket.toBytes());
      await Future<void>.delayed(Duration.zero);

      // Should have sent a pong
      final pongSent = hostTransport.sentPackets.where((s) {
        final p = Packet.fromBytes(s.data);
        return p?.header.type == PacketType.pong;
      });
      expect(pongSent, isNotEmpty);
    });

    test('ignores packets from unknown peers', () async {
      await host.start(7777);

      final header = PacketHeader(
        type: PacketType.input,
        sequence: 1,
        timestamp: 0,
      );
      final packet = Packet(header: header, payload: Uint8List(0));

      // Send from unknown address
      hostTransport.injectPacket(
        const NetAddress('10.0.0.99', 9999),
        packet.toBytes(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 0);
    });

    test('ignores invalid packets', () async {
      await host.start(7777);

      // Send garbage data
      hostTransport.injectPacket(
        const NetAddress('10.0.0.2', 5000),
        Uint8List.fromList([0, 1, 2, 3]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 0);
    });

    test('update does nothing when not running', () {
      // Should not throw
      host.update();
    });

    test('broadcast sends to all connected peers', () async {
      await host.start(7777);

      // Connect two peers
      hostTransport.injectPacket(
        const NetAddress('10.0.0.2', 5000),
        _makeConnectPacket(),
      );
      hostTransport.injectPacket(
        const NetAddress('10.0.0.3', 5001),
        _makeConnectPacket(),
      );
      await Future<void>.delayed(Duration.zero);
      expect(host.peerCount, 2);

      hostTransport.sentPackets.clear();

      await host.broadcast(
        PacketType.stateUpdate,
        Uint8List.fromList([42]),
      );

      // Should have sent to both peers
      expect(hostTransport.sentPackets.length, 2);
      final addresses = hostTransport.sentPackets.map((s) => s.address).toSet();
      expect(addresses, contains(const NetAddress('10.0.0.2', 5000)));
      expect(addresses, contains(const NetAddress('10.0.0.3', 5001)));
    });

    test('broadcastExcept skips excluded peer', () async {
      await host.start(7777);

      hostTransport.injectPacket(
        const NetAddress('10.0.0.2', 5000),
        _makeConnectPacket(),
      );
      hostTransport.injectPacket(
        const NetAddress('10.0.0.3', 5001),
        _makeConnectPacket(),
      );
      await Future<void>.delayed(Duration.zero);

      final peers = host.peers.toList();
      hostTransport.sentPackets.clear();

      await host.broadcastExcept(
        peers[0].id,
        PacketType.stateUpdate,
        Uint8List.fromList([42]),
      );

      expect(hostTransport.sentPackets.length, 1);
      expect(hostTransport.sentPackets[0].address, peers[1].address);
    });

    test('sendTo sends to specific peer', () async {
      await host.start(7777);

      hostTransport.injectPacket(
        const NetAddress('10.0.0.2', 5000),
        _makeConnectPacket(),
      );
      await Future<void>.delayed(Duration.zero);

      final peerId = host.peers.first.id;
      hostTransport.sentPackets.clear();

      await host.sendTo(peerId, PacketType.stateUpdate, Uint8List.fromList([1]));
      expect(hostTransport.sentPackets.length, 1);
    });

    test('sendTo ignores unknown peer id', () async {
      await host.start(7777);
      await host.sendTo(999, PacketType.stateUpdate, Uint8List(0));
      // No packets sent (only bind packets)
    });
  });

  group('NetworkClient', () {
    test('starts disconnected', () {
      final transport = MockTransport();
      final client = NetworkClient(transport: transport);

      expect(client.state, ClientState.disconnected);
      expect(client.isConnected, false);
      expect(client.localPeerId, isNull);
      expect(client.hostAddress, isNull);
    });

    test('send throws when not connected', () {
      final transport = MockTransport();
      final client = NetworkClient(transport: transport);

      expect(
        () => client.send(PacketType.input, Uint8List(0)),
        throwsStateError,
      );
    });

    test('connect throws when not disconnected', () async {
      final transport = MockTransport();
      final client = NetworkClient(transport: transport);

      // Start connecting (don't await, it will timeout)
      unawaited(client.connect('10.0.0.1', 7777).catchError((_) => false));
      await Future<void>.delayed(Duration.zero);

      expect(
        () => client.connect('10.0.0.1', 7778),
        throwsStateError,
      );
    });

    test('disconnect when already disconnected is safe', () async {
      final transport = MockTransport();
      final client = NetworkClient(transport: transport);

      await client.disconnect(); // should not throw
    });
  });

  group('Host-Client integration', () {
    test('client connects to host via mock transport', () async {
      final (hostTransport, clientTransport) = createLinkedTransports();

      final host = NetworkHost(transport: hostTransport);
      final client = NetworkClient(
        transport: clientTransport,
        connectionTimeout: const Duration(seconds: 5),
      );

      await host.start(7777);

      final connectFuture = client.connect('127.0.0.1', 7777);
      await Future<void>.delayed(Duration.zero); // let packets flow
      await Future<void>.delayed(Duration.zero); // response

      final connected = await connectFuture;
      expect(connected, true);
      expect(client.isConnected, true);
      expect(client.localPeerId, isNotNull);
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });
  });
}

Uint8List _makeConnectPacket() {
  final builder = PacketBuilder()..writeString('TestClient');
  final header = PacketHeader(
    type: PacketType.connect,
    sequence: 0,
    timestamp: 0,
  );
  return Packet(header: header, payload: builder.build()).toBytes();
}
