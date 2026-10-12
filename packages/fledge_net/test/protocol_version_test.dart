import 'dart:async';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Build a packet, then overwrite its version byte with [version].
Uint8List _packetWithVersion(
  PacketType type,
  int version, [
  Uint8List? payload,
]) {
  final bytes = Packet(
    header: PacketHeader(type: type, sequence: 1, timestamp: 0),
    payload: payload ?? (PacketBuilder()..writeString('OldClient')).build(),
  ).toBytes();
  bytes[4] = version;
  return bytes;
}

void main() {
  const hostAddr = NetAddress('127.0.0.1', 7777);
  const oldVersion = PacketHeader.version - 1;

  group('Host protocol version handling', () {
    late LoopbackNetwork net;
    late NetworkHost host;
    late LoopbackTransport raw;
    late List<ReceivedPacket> replies;

    setUp(() async {
      net = LoopbackNetwork();
      host = NetworkHost(transport: net.createTransport());
      await host.start(hostAddr.port);
      raw = net.createTransport(host: '10.0.0.2');
      await raw.bind(5000);
      replies = [];
      raw.onReceive.listen(replies.add);
    });

    tearDown(() => host.stop());

    test('rejects a mismatched-version connect with a clear reason', () async {
      await raw.send(
        hostAddr,
        _packetWithVersion(PacketType.connect, oldVersion),
      );
      await Future<void>.delayed(Duration.zero);

      expect(host.peerCount, 0);
      final reject = Packet.fromBytes(replies.single.data)!;
      expect(reject.header.type, PacketType.connectRejected);
      final reason = PacketReader(reject.payload).readString();
      expect(reason, contains('Protocol version mismatch'));
      expect(reason, contains('v$oldVersion'));
    });

    test('emits a structured ProtocolMismatchEvent', () async {
      final events = <ProtocolMismatchEvent>[];
      host.onProtocolMismatch.listen(events.add);

      await raw.send(
        hostAddr,
        _packetWithVersion(PacketType.connect, oldVersion),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.source, const NetAddress('10.0.0.2', 5000));
      expect(events.single.localVersion, PacketHeader.version);
      expect(events.single.remoteVersion, oldVersion);
      expect(events.single.remoteIsNewer, isFalse);
    });

    test('does not reply to mismatched non-connect packets', () async {
      final events = <ProtocolMismatchEvent>[];
      host.onProtocolMismatch.listen(events.add);
      await raw.send(hostAddr, _packetWithVersion(PacketType.input, 1));
      await Future<void>.delayed(Duration.zero);
      expect(replies, isEmpty);
      expect(events.single.remoteVersion, 1);
    });

    test('a v2 client gets a reject it can recognise as a mismatch', () async {
      await raw.send(hostAddr, _packetWithVersion(PacketType.connect, 2));
      await Future<void>.delayed(Duration.zero);
      // A v2 peer runs PacketHeader.peekVersion on this reply: magic
      // matches, version byte differs, so it reports a version mismatch.
      expect(PacketHeader.peekVersion(replies.single.data), 3);
    });

    test('ignores non-protocol garbage without replying', () async {
      await raw.send(hostAddr, Uint8List.fromList(List.filled(30, 7)));
      await Future<void>.delayed(Duration.zero);
      expect(replies, isEmpty);
      expect(host.peerCount, 0);
    });
  });

  group('Client protocol version handling', () {
    test('fails fast with a clear reason when the host speaks another '
        'version', () async {
      final net = LoopbackNetwork();
      final fakeHost = net.createTransport();
      await fakeHost.bind(hostAddr.port);
      fakeHost.onReceive.listen((p) {
        fakeHost.send(
          p.source,
          _packetWithVersion(
            PacketType.connectAccepted,
            PacketHeader.version + 1,
            (PacketBuilder()..writeInt32(1)).build(),
          ),
        );
      });

      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
      );
      final states = <ConnectionStateEvent>[];
      client.onStateChange.listen(states.add);
      final mismatches = <ProtocolMismatchEvent>[];
      client.onProtocolMismatch.listen(mismatches.add);

      final sw = Stopwatch()..start();
      expect(await client.connect('127.0.0.1', hostAddr.port), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
      expect(client.state, ClientState.failed);
      await Future<void>.delayed(Duration.zero);
      expect(
        states.last.reason,
        'Protocol version mismatch: local v${PacketHeader.version}, '
        'server v${PacketHeader.version + 1}',
      );
      expect(mismatches.single.remoteVersion, PacketHeader.version + 1);
      expect(mismatches.single.remoteIsNewer, isTrue);
    });

    test('surfaces the host reject reason for an old client', () async {
      // Real host, but the client's connect is rewritten to an older
      // version on the wire.
      final net = LoopbackNetwork();
      final host = NetworkHost(transport: net.createTransport());
      await host.start(hostAddr.port);
      net.filter = (d) {
        if (d.destination == hostAddr) d.data[4] = oldVersion;
        return true;
      };

      final client = NetworkClient(
        transport: net.createTransport(),
        connectionTimeout: const Duration(seconds: 3),
      );
      final states = <ConnectionStateEvent>[];
      client.onStateChange.listen(states.add);

      expect(await client.connect('127.0.0.1', hostAddr.port), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(
        states.last.reason,
        'Protocol version mismatch: host v${PacketHeader.version}, '
        'client v$oldVersion',
      );
      await host.stop();
    });
  });

  test('protocol version is 3', () {
    expect(PacketHeader.version, 3);
  });
}
