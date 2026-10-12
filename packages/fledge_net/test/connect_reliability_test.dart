import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Packet type byte of a raw datagram (offset 5 in the plaintext header).
PacketType? _typeOf(Uint8List data) =>
    data.length > 5 ? PacketType.fromValue(data[5]) : null;

/// A filter that drops the first [count] datagrams of [type].
bool Function(LoopbackDatagram) _dropFirst(PacketType type, [int count = 1]) {
  var dropped = 0;
  return (d) {
    if (_typeOf(d.data) == type && dropped < count) {
      dropped++;
      return false;
    }
    return true;
  };
}

Uint8List _connectPacket() {
  final builder = PacketBuilder()..writeString('TestClient');
  return Packet(
    header: PacketHeader(type: PacketType.connect, sequence: 1, timestamp: 0),
    payload: builder.build(),
  ).toBytes();
}

void main() {
  group('Connect handshake reliability', () {
    test('client retransmits connect when the first one is lost', () async {
      final net = LoopbackNetwork(filter: _dropFirst(PacketType.connect));
      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
      );
      await host.start(7777);

      final sw = Stopwatch()..start();
      expect(await client.connect('127.0.0.1', 7777), isTrue);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });

    test('connectRetryInterval controls the retry cadence', () async {
      final net = LoopbackNetwork(filter: _dropFirst(PacketType.connect, 3));
      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
        connectRetryInterval: const Duration(milliseconds: 20),
      );
      await host.start(7777);

      final sw = Stopwatch()..start();
      expect(await client.connect('127.0.0.1', 7777), isTrue);
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 1000)));
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });

    test('retries stop once connected', () async {
      final net = LoopbackNetwork();
      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectRetryInterval: const Duration(milliseconds: 10),
      );
      await host.start(7777);
      var connects = 0;
      net.filter = (d) {
        if (_typeOf(d.data) == PacketType.connect) connects++;
        return true;
      };

      expect(await client.connect('127.0.0.1', 7777), isTrue);
      final afterConnect = connects;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(connects, afterConnect);

      await client.disconnect();
      await host.stop();
    });

    test('disconnect while connecting resolves connect() with false', () async {
      final net = LoopbackNetwork(packetLoss: 1);
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 10),
      );
      final connecting = client.connect('127.0.0.1', 7777);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await client.disconnect();
      expect(await connecting.timeout(const Duration(seconds: 1)), isFalse);
      expect(client.state, ClientState.disconnected);
    });

    test('client still connects when connectAccepted is lost', () async {
      final net = LoopbackNetwork(
        filter: _dropFirst(PacketType.connectAccepted),
      );
      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
      );
      await host.start(7777);

      // Nobody calls host.update(): recovery must come from the client's
      // connect retry prompting the host to re-send the acceptance.
      expect(await client.connect('127.0.0.1', 7777), isTrue);
      expect(host.peerCount, 1);
      expect(client.localPeerId, host.peers.single.id);

      await client.disconnect();
      await host.stop();
    });

    test('duplicated datagrams do not break the handshake', () async {
      final net = LoopbackNetwork(duplication: 1);
      final host = NetworkHost(transport: net.createTransport());
      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
      );
      await host.start(7777);

      expect(await client.connect('127.0.0.1', 7777), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });

    test(
      'host with async authenticator creates one peer for duplicate connects',
      () async {
        final net = LoopbackNetwork();
        final gate = Completer<bool>();
        var authCalls = 0;
        final host = NetworkHost(
          transport: net.createTransport(),
          authenticator: (_, _) {
            authCalls++;
            return gate.future;
          },
        );
        await host.start(7777);
        final connected = <PeerConnectedEvent>[];
        host.onPeerConnected.listen(connected.add);

        final raw = net.createTransport(host: '10.0.0.2');
        await raw.bind(5000);
        final hostAddr = const NetAddress('127.0.0.1', 7777);
        await raw.send(hostAddr, _connectPacket());
        await raw.send(hostAddr, _connectPacket());
        await Future<void>.delayed(Duration.zero);

        gate.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(authCalls, 1);
        expect(host.peerCount, 1);
        expect(connected, hasLength(1));

        await host.stop();
      },
    );

    test('rejected client may retry after authentication fails', () async {
      final net = LoopbackNetwork();
      var allow = false;
      final host = NetworkHost(
        transport: net.createTransport(),
        authenticator: (_, _) async => allow,
      );
      await host.start(7777);

      final raw = net.createTransport(host: '10.0.0.2');
      await raw.bind(5000);
      final hostAddr = const NetAddress('127.0.0.1', 7777);
      await raw.send(hostAddr, _connectPacket());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(host.peerCount, 0);

      allow = true;
      await raw.send(hostAddr, _connectPacket());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(host.peerCount, 1);

      await host.stop();
    });

    test('lossy link with many clients eventually connects all', () async {
      final net = LoopbackNetwork(
        latency: const Duration(milliseconds: 5),
        jitter: const Duration(milliseconds: 5),
        packetLoss: 0.3,
        random: Random(1234), // reproducible loss pattern
      );
      final host = NetworkHost(transport: net.createTransport());
      await host.start(7777);

      final clients = List.generate(
        4,
        (_) => NetworkClient(
          transport: net.createTransport(),
          connectionTimeout: const Duration(seconds: 5),
        ),
      );
      final pump = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => host.update(),
      );
      final results = await Future.wait(
        clients.map((c) => c.connect('127.0.0.1', 7777)),
      );
      pump.cancel();

      expect(results, everyElement(isTrue));
      expect(host.peerCount, 4);
      final ids = clients.map((c) => c.localPeerId).toSet();
      expect(ids, hasLength(4));

      await host.stop();
    });
  });
}
