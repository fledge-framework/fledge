import 'dart:async';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// A bare transport on the loopback network that records what it receives,
/// standing in for a client so tests can hand-craft packets.
class _RawPeer {
  final LoopbackTransport transport;
  final List<Packet> received = [];

  _RawPeer(this.transport) {
    transport.onReceive.listen((p) {
      final packet = Packet.fromBytes(p.data);
      if (packet != null) received.add(packet);
    });
  }

  static Future<_RawPeer> bind(LoopbackNetwork net, NetAddress address) async {
    final transport = net.createTransport(host: address.host);
    await transport.bind(address.port);
    return _RawPeer(transport);
  }

  NetAddress get address => transport.localAddress!;

  Future<void> send(NetAddress to, Uint8List data) => transport.send(to, data);

  Iterable<Packet> ofType(PacketType type) =>
      received.where((p) => p.header.type == type);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  const hostAddr = NetAddress('127.0.0.1', 7777);

  group('NetworkHost', () {
    late LoopbackNetwork net;
    late LoopbackTransport hostTransport;
    late NetworkHost host;

    setUp(() {
      net = LoopbackNetwork();
      hostTransport = net.createTransport();
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
      expect(hostTransport.localAddress, hostAddr);
    });

    test('start throws if already running', () async {
      await host.start(7777);
      expect(() => host.start(7778), throwsStateError);
    });

    test('stop closes transport', () async {
      await host.start(7777);
      await host.stop();
      expect(host.isRunning, false);
      expect(hostTransport.state, ConnectionState.disconnected);
    });

    test('accepts connection from client', () async {
      await host.start(7777);

      final events = <PeerConnectedEvent>[];
      host.onPeerConnected.listen(events.add);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      expect(host.peerCount, 1);
      expect(events.length, 1);
      expect(events[0].peer.address, client.address);
      expect(events[0].peer.isConnected, true);

      final accept = client.ofType(PacketType.connectAccepted).single;
      expect(PacketReader(accept.payload).readInt32(), events[0].peer.id);
      // The acceptance acknowledges the connect packet's sequence.
      expect(accept.header.ack, 1);
    });

    test('rejects connection when full', () async {
      host = NetworkHost(transport: hostTransport, maxPeers: 1);
      await host.start(7777);

      // Connect first client
      final first = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await first.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 1);

      // Try to connect second client — should be rejected
      final second = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.3', 5001),
      );
      await second.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 1);

      final reject = second.ofType(PacketType.connectRejected).single;
      expect(PacketReader(reject.payload).readString(), 'Server full');
    });

    test('ignores duplicate connect from same address', () async {
      await host.start(7777);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 1);

      // Same address connects again (e.g. a retry after a lost accept)
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 1); // no duplicate

      // ...and is told its (unchanged) peer id again.
      final accepts = client.ofType(PacketType.connectAccepted).toList();
      expect(accepts, hasLength(2));
      expect(accepts.map((p) => PacketReader(p.payload).readInt32()).toSet(), {
        host.peers.single.id,
      });
    });

    test('disconnect peer removes and notifies', () async {
      await host.start(7777);

      final disconnectEvents = <PeerDisconnectedEvent>[];
      host.onPeerDisconnected.listen(disconnectEvents.add);

      // Connect a peer
      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 1);

      final peerId = host.peers.first.id;
      await host.disconnectPeer(peerId, 'Kicked');
      await _settle();

      expect(host.peerCount, 0);
      expect(disconnectEvents.length, 1);
      expect(disconnectEvents[0].reason, 'Kicked');
      final notice = client.ofType(PacketType.disconnect).single;
      expect(PacketReader(notice.payload).readString(), 'Kicked');
    });

    test('handles disconnect packet from peer', () async {
      await host.start(7777);

      final disconnectEvents = <PeerDisconnectedEvent>[];
      host.onPeerDisconnected.listen(disconnectEvents.add);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      // Send disconnect from same address
      final builder = PacketBuilder()..writeString('Leaving');
      final header = PacketHeader(
        type: PacketType.disconnect,
        sequence: 2,
        timestamp: 0,
      );
      final disconnectPacket = Packet(header: header, payload: builder.build());
      await client.send(hostAddr, disconnectPacket.toBytes());
      await _settle();

      expect(host.peerCount, 0);
      expect(disconnectEvents.length, 1);
      expect(disconnectEvents[0].reason, 'Client disconnected');
    });

    test('forwards game data packets to onData', () async {
      await host.start(7777);

      final dataEvents = <PeerDataEvent>[];
      host.onData.listen(dataEvents.add);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      // Send input data from same address
      final payload = Uint8List.fromList([1, 2, 3]);
      final header = PacketHeader(
        type: PacketType.input,
        sequence: 2,
        timestamp: 0,
      );
      final dataPacket = Packet(header: header, payload: payload);
      await client.send(hostAddr, dataPacket.toBytes());
      await _settle();

      expect(dataEvents.length, 1);
      expect(dataEvents[0].type, PacketType.input);
      expect(dataEvents[0].data, payload);
    });

    test('responds to ping with pong echoing the ping timestamp', () async {
      await host.start(7777);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      // Send ping carrying the client's own clock value
      final header = PacketHeader(
        type: PacketType.ping,
        sequence: 2,
        timestamp: 0,
      );
      final pingPacket = Packet(
        header: header,
        payload: (PacketBuilder()..writeUint32(0xCAFEBABE)).build(),
      );
      await client.send(hostAddr, pingPacket.toBytes());
      await _settle();

      final pong = client.ofType(PacketType.pong).single;
      expect(PacketReader(pong.payload).readUint32(), 0xCAFEBABE);
    });

    test('pings peers from update() and measures RTT from the pong', () async {
      final clock = ManualNetClock(1000);
      host = NetworkHost(transport: hostTransport, clock: clock);
      await host.start(7777);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      host.update();
      await _settle();
      final ping = client.ofType(PacketType.ping).single;
      final stamp = PacketReader(ping.payload).readUint32();
      expect(stamp, 1000);

      clock.advance(const Duration(milliseconds: 42));
      final pong = Packet(
        header: PacketHeader(type: PacketType.pong, sequence: 2, timestamp: 0),
        payload: (PacketBuilder()..writeUint32(stamp)).build(),
      );
      await client.send(hostAddr, pong.toBytes());
      await _settle();

      expect(host.peers.single.rtt, 42);
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
      hostTransport.inject(
        const NetAddress('10.0.0.99', 9999),
        packet.toBytes(),
      );
      await _settle();

      expect(host.peerCount, 0);
    });

    test('ignores invalid packets', () async {
      await host.start(7777);

      // Send garbage data
      hostTransport.inject(
        const NetAddress('10.0.0.2', 5000),
        Uint8List.fromList([0, 1, 2, 3]),
      );
      await _settle();

      expect(host.peerCount, 0);
    });

    test('ignores connect packets with a malformed payload', () async {
      await host.start(7777);

      final header = PacketHeader(
        type: PacketType.connect,
        sequence: 1,
        timestamp: 0,
      );
      // Length prefix claims 50 bytes but only 2 follow.
      final packet = Packet(
        header: header,
        payload: Uint8List.fromList([50, 0, 65, 66]),
      );
      hostTransport.inject(
        const NetAddress('10.0.0.2', 5000),
        packet.toBytes(),
      );
      await _settle();

      expect(host.peerCount, 0);
    });

    test('update does nothing when not running', () {
      // Should not throw
      host.update();
    });

    test('broadcast sends to all connected peers', () async {
      await host.start(7777);

      // Connect two peers
      final a = await _RawPeer.bind(net, const NetAddress('10.0.0.2', 5000));
      final b = await _RawPeer.bind(net, const NetAddress('10.0.0.3', 5001));
      await a.send(hostAddr, _makeConnectPacket());
      await b.send(hostAddr, _makeConnectPacket());
      await _settle();
      expect(host.peerCount, 2);

      await host.broadcast(PacketType.stateUpdate, Uint8List.fromList([42]));
      await _settle();

      // Should have sent to both peers
      expect(a.ofType(PacketType.stateUpdate).single.payload, [42]);
      expect(b.ofType(PacketType.stateUpdate).single.payload, [42]);
    });

    test('broadcastExcept skips excluded peer', () async {
      await host.start(7777);

      final a = await _RawPeer.bind(net, const NetAddress('10.0.0.2', 5000));
      final b = await _RawPeer.bind(net, const NetAddress('10.0.0.3', 5001));
      await a.send(hostAddr, _makeConnectPacket());
      await b.send(hostAddr, _makeConnectPacket());
      await _settle();

      final excluded = host.peers.firstWhere((p) => p.address == a.address);

      await host.broadcastExcept(
        excluded.id,
        PacketType.stateUpdate,
        Uint8List.fromList([42]),
      );
      await _settle();

      expect(a.ofType(PacketType.stateUpdate), isEmpty);
      expect(b.ofType(PacketType.stateUpdate), hasLength(1));
    });

    test('sendTo sends to specific peer', () async {
      await host.start(7777);

      final client = await _RawPeer.bind(
        net,
        const NetAddress('10.0.0.2', 5000),
      );
      await client.send(hostAddr, _makeConnectPacket());
      await _settle();

      final peerId = host.peers.first.id;

      await host.sendTo(
        peerId,
        PacketType.stateUpdate,
        Uint8List.fromList([1]),
      );
      await _settle();
      expect(client.ofType(PacketType.stateUpdate), hasLength(1));
    });

    test('sendTo ignores unknown peer id', () async {
      await host.start(7777);
      final before = net.stats.sent;
      await host.sendTo(999, PacketType.stateUpdate, Uint8List(0));
      expect(net.stats.sent, before);
    });
  });

  group('NetworkClient', () {
    test('starts disconnected', () {
      final client = NetworkClient(
        transport: LoopbackNetwork().createTransport(),
      );

      expect(client.state, ClientState.disconnected);
      expect(client.isConnected, false);
      expect(client.localPeerId, isNull);
      expect(client.hostAddress, isNull);
    });

    test('send throws when not connected', () {
      final client = NetworkClient(
        transport: LoopbackNetwork().createTransport(),
      );

      expect(
        () => client.send(PacketType.input, Uint8List(0)),
        throwsStateError,
      );
    });

    test('connect throws when not disconnected', () async {
      final client = NetworkClient(
        transport: LoopbackNetwork().createTransport(),
        connectionTimeout: const Duration(milliseconds: 100),
      );

      // Start connecting to nobody; it will time out.
      final pending = client.connect('10.0.0.1', 7777);
      await _settle();

      expect(() => client.connect('10.0.0.1', 7778), throwsStateError);
      expect(await pending, isFalse);
    });

    test('disconnect when already disconnected is safe', () async {
      final client = NetworkClient(
        transport: LoopbackNetwork().createTransport(),
      );

      await client.disconnect(); // should not throw
    });
  });

  group('Host-Client integration', () {
    test('client connects to host via loopback transport', () async {
      final net = LoopbackNetwork();

      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 5),
      );

      await host.start(7777);

      final connected = await client.connect('127.0.0.1', 7777);
      expect(connected, true);
      expect(client.isConnected, true);
      expect(client.localPeerId, isNotNull);
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });

    test('one host and several clients exchange data', () async {
      final net = LoopbackNetwork(latency: const Duration(milliseconds: 2));
      final host = NetworkHost(transport: net.createTransport());
      await host.start(7777);

      final clients = List.generate(
        3,
        (_) => NetworkClient(transport: net.createTransport()),
      );
      for (final c in clients) {
        expect(await c.connect('127.0.0.1', 7777), isTrue);
      }
      expect(host.peerCount, 3);

      final hostGot = <PeerDataEvent>[];
      host.onData.listen(hostGot.add);
      final clientGot = [for (final _ in clients) <HostDataEvent>[]];
      for (var i = 0; i < clients.length; i++) {
        clients[i].onData.listen(clientGot[i].add);
      }

      for (final c in clients) {
        await c.send(PacketType.input, Uint8List.fromList([c.localPeerId!]));
      }
      await host.broadcast(PacketType.stateUpdate, Uint8List.fromList([7]));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        hostGot.map((e) => e.data.single).toSet(),
        clients.map((c) => c.localPeerId).toSet(),
      );
      for (final got in clientGot) {
        expect(got.single.data, [7]);
      }

      for (final c in clients) {
        await c.disconnect();
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(host.peerCount, 0);
      await host.stop();
    });

    test('client and host exchange text with non-ASCII characters', () async {
      final net = LoopbackNetwork();
      final host = NetworkHost(transport: net.createTransport());
      await host.start(7777);
      final client = NetworkClient(transport: net.createTransport());
      expect(await client.connect('127.0.0.1', 7777), isTrue);

      final got = Completer<String>();
      host.onData.listen(
        (e) => got.complete(PacketReader(e.data).readString()),
      );
      await client.send(
        PacketType.custom,
        (PacketBuilder()..writeString('Zoë 🦆')).build(),
      );
      expect(await got.future, 'Zoë 🦆');

      await client.disconnect();
      await host.stop();
    });
  });
}

Uint8List _makeConnectPacket() {
  final builder = PacketBuilder()..writeString('TestClient');
  final header = PacketHeader(
    type: PacketType.connect,
    sequence: 1,
    timestamp: 0,
  );
  return Packet(header: header, payload: builder.build()).toBytes();
}
