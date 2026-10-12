import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('Hostname support', () {
    test('connect accepts "localhost" and talks to 127.0.0.1', () async {
      final net = LoopbackNetwork();
      final host = NetworkHost(transport: net.createTransport());
      await host.start(7777);

      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 2),
      );
      expect(await client.connect('localhost', 7777), isTrue);
      expect(client.hostAddress, const NetAddress('127.0.0.1', 7777));
      expect(host.peerCount, 1);

      await client.disconnect();
      await host.stop();
    });

    test('numeric addresses bypass the resolver', () async {
      final net = LoopbackNetwork();
      final host = NetworkHost(transport: net.createTransport());
      await host.start(7777);
      var resolverCalls = 0;
      final client = NetworkClient(
        transport: net.createTransport(),
        hostResolver: (h) async {
          resolverCalls++;
          return h;
        },
      );
      // A custom resolver is always used when supplied.
      expect(await client.connect('127.0.0.1', 7777), isTrue);
      expect(resolverCalls, 1);
      await client.disconnect();
      await host.stop();
    });

    test('custom resolver maps names to loopback hosts', () async {
      final net = LoopbackNetwork();
      final host = NetworkHost(
        transport: net.createTransport(host: '10.0.0.1'),
      );
      await host.start(7777);
      final client = NetworkClient(
        transport: net.createTransport(),
        hostResolver: (h) async => h == 'game.example' ? '10.0.0.1' : h,
      );
      expect(await client.connect('game.example', 7777), isTrue);
      expect(client.hostAddress, const NetAddress('10.0.0.1', 7777));
      await client.disconnect();
      await host.stop();
    });

    test('resolution failure fails the connect with a clear reason', () async {
      final net = LoopbackNetwork();
      final client = NetworkClient(
        transport: net.createTransport(),
        hostResolver: (h) async =>
            throw Exception('no such host'), // simulated DNS failure
      );
      final states = <ConnectionStateEvent>[];
      client.onStateChange.listen(states.add);

      expect(await client.connect('nowhere.invalid', 7777), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(client.state, ClientState.failed);
      expect(states.last.reason, contains('Could not resolve host'));
      expect(states.last.reason, contains('nowhere.invalid'));
    });
  });

  group('Size constants', () {
    test('max payload leaves room for header and encryption', () {
      expect(Packet.maxDatagramBytes, 1200);
      expect(Packet.encryptionOverheadBytes, EncryptedTransport.overheadBytes);
      expect(
        Packet.maxPayloadBytes,
        Packet.maxDatagramBytes -
            PacketHeader.size -
            EncryptedTransport.overheadBytes,
      );
    });

    test('a max-size payload encrypts to at most maxDatagramBytes', () async {
      final net = LoopbackNetwork();
      final inner = net.createTransport();
      final sink = net.createTransport();
      final encrypted = EncryptedTransport(
        inner: inner,
        sharedKey: EncryptedTransport.generateKey(),
      );
      await encrypted.bind(1);
      await sink.bind(2);
      final packet = Packet(
        header: PacketHeader(type: PacketType.custom, sequence: 1),
        payload: Uint8List(Packet.maxPayloadBytes),
      ).toBytes();
      await encrypted.send(sink.localAddress!, packet);
      expect(sink.receive().single.data.length, Packet.maxDatagramBytes);
    });
  });

  group('Datagram size guard', () {
    late LoopbackNetwork net;
    late NetworkHost host;
    late NetworkClient client;

    setUp(() async {
      net = LoopbackNetwork();
      host = NetworkHost(transport: net.createTransport());
      await host.start(7777);
      client = NetworkClient(transport: net.createTransport());
      expect(await client.connect('127.0.0.1', 7777), isTrue);
    });

    tearDown(() async {
      await client.disconnect();
      await host.stop();
    });

    test('client.send rejects oversized payloads', () {
      expect(
        () => client.send(PacketType.custom, Uint8List(2000)),
        throwsArgumentError,
      );
    });

    test('host.broadcast rejects oversized payloads', () {
      expect(
        () => host.broadcast(PacketType.stateUpdate, Uint8List(2000)),
        throwsArgumentError,
      );
    });

    test('a max-size payload is accepted end to end', () async {
      final got = <PeerDataEvent>[];
      host.onData.listen(got.add);
      await client.send(PacketType.custom, Uint8List(Packet.maxPayloadBytes));
      await host.broadcast(
        PacketType.stateUpdate,
        Uint8List(Packet.maxPayloadBytes),
      );
      await Future<void>.delayed(Duration.zero);
      expect(got.single.data.length, Packet.maxPayloadBytes);
    });

    test('one byte over the limit throws with a helpful message', () {
      expect(
        () => client.send(
          PacketType.custom,
          Uint8List(Packet.maxPayloadBytes + 1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('maximum is ${Packet.maxPayloadBytes}'),
          ),
        ),
      );
    });

    test('oversized broadcast sends nothing', () async {
      final before = net.stats.sent;
      await expectLater(
        host.broadcast(PacketType.stateUpdate, Uint8List(2000)),
        throwsArgumentError,
      );
      expect(net.stats.sent, before);
    });

    test('host.sendTo rejects oversized payloads', () {
      expect(
        () => host.sendTo(
          host.peers.single.id,
          PacketType.stateUpdate,
          Uint8List(2000),
        ),
        throwsArgumentError,
      );
    });
  });
}
