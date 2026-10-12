// Disconnect notices are sent redundantly (one lost datagram must not leave
// the other side waiting for connectionTimeout), and host peer timing runs
// on the injectable NetClock.
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Packet type byte of a raw datagram (offset 5 in the plaintext header).
PacketType? _typeOf(Uint8List data) =>
    data.length > 5 ? PacketType.fromValue(data[5]) : null;

/// A filter that drops the first [count] datagrams of [type] and counts
/// how many of that type were sent in total.
class _DropFirst {
  final PacketType type;
  final int count;
  int seen = 0;

  _DropFirst(this.type, this.count);

  bool call(LoopbackDatagram d) {
    if (_typeOf(d.data) != type) return true;
    seen++;
    return seen > count;
  }
}

void main() {
  const latency = Duration(milliseconds: 30);

  late ManualNetClock clock;
  late LoopbackNetwork net;
  late NetworkHost host;
  final hostEvents = <PeerDisconnectedEvent>[];

  Future<NetworkClient> connectClient() async {
    final client = NetworkClient(
      transport: net.createTransport(),
      clock: clock,
      connectionTimeout: const Duration(seconds: 10),
    );
    final connecting = client.connect('127.0.0.1', 7777);
    await net.advance(latency * 2);
    expect(await connecting, isTrue);
    return client;
  }

  setUp(() async {
    hostEvents.clear();
    clock = ManualNetClock(1000);
    net = LoopbackNetwork(latency: latency, clock: clock);
    host = NetworkHost(
      transport: net.createTransport(),
      clock: clock,
      connectionTimeout: const Duration(seconds: 10),
    );
    host.onPeerDisconnected.listen(hostEvents.add);
    await host.start(7777);
  });

  tearDown(() async {
    await host.stop();
    net.clearInFlight();
  });

  group('client disconnect', () {
    for (final lost in [1, 2]) {
      test('reaches the host promptly when the first $lost of the copies '
          'are lost', () async {
        final client = await connectClient();
        expect(host.peerCount, 1);
        final drop = _DropFirst(PacketType.disconnect, lost);
        net.filter = drop.call;

        await client.disconnect();
        await net.advance(latency);

        expect(drop.seen, NetworkClient.defaultDisconnectRedundancy);
        expect(host.peerCount, 0);
        // Duplicates are idempotent: exactly one event.
        expect(hostEvents, hasLength(1));
        expect(hostEvents.single.reason, 'Client disconnected');
      });
    }

    test('is bounded in wall-clock time', () async {
      final client = await connectClient();
      final sw = Stopwatch()..start();
      await client.disconnect();
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(client.state, ClientState.disconnected);
    });

    test('concurrent calls send one burst and both complete', () async {
      final client = await connectClient();
      final drop = _DropFirst(PacketType.disconnect, 0);
      net.filter = drop.call;
      await Future.wait([client.disconnect(), client.disconnect()]);
      await net.advance(latency);
      expect(drop.seen, NetworkClient.defaultDisconnectRedundancy);
      expect(hostEvents, hasLength(1));
    });

    test('disconnectRedundancy is configurable', () async {
      final client = NetworkClient(
        transport: net.createTransport(),
        clock: clock,
        disconnectRedundancy: 5,
        disconnectRedundancyInterval: Duration.zero,
      );
      final connecting = client.connect('127.0.0.1', 7777);
      await net.advance(latency * 2);
      expect(await connecting, isTrue);
      final drop = _DropFirst(PacketType.disconnect, 4);
      net.filter = drop.call;
      await client.disconnect();
      await net.advance(latency);
      expect(drop.seen, 5);
      expect(hostEvents, hasLength(1));
    });
  });

  group('host disconnect', () {
    test('kick reaches the client when the first copy is lost', () async {
      final client = await connectClient();
      final states = <ConnectionStateEvent>[];
      client.onStateChange.listen(states.add);
      final drop = _DropFirst(PacketType.disconnect, 1);
      net.filter = drop.call;

      await host.disconnectPeer(host.peers.single.id, 'Kicked');
      expect(host.peerCount, 0);
      expect(hostEvents.single.reason, 'Kicked');
      await net.advance(latency);

      expect(drop.seen, NetworkHost.defaultDisconnectRedundancy);
      expect(client.state, ClientState.disconnected);
      expect(client.lastStateReason, 'Kicked');
      expect(states.map((e) => e.state), [ClientState.disconnected]);
      await client.disconnect();
    });

    test('shutdown reaches every client when first copies are lost', () async {
      final a = await connectClient();
      final b = await connectClient();
      // Drop the first copy to each client.
      final drop = _DropFirst(PacketType.disconnect, 2);
      net.filter = drop.call;

      final sw = Stopwatch()..start();
      await host.stop();
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
      await net.advance(latency);

      expect(drop.seen, 2 * NetworkHost.defaultDisconnectRedundancy);
      for (final c in [a, b]) {
        expect(c.state, ClientState.disconnected);
        expect(c.lastStateReason, 'Host shutting down');
        await c.disconnect();
      }
    });
  });

  group('host peer timing uses NetClock', () {
    test(
      'a silent peer times out by advancing the manual clock only',
      () async {
        final client = await connectClient();
        // The client goes silent (everything it sends is dropped); the host
        // keeps updating. No real waiting: the manual clock does the work.
        final clientAddress = client.transport.localAddress!;
        net.filter = (d) => d.source != clientAddress;
        final sw = Stopwatch()..start();
        host.update();
        await net.advance(const Duration(seconds: 9));
        host.update();
        expect(host.peerCount, 1);
        await net.advance(const Duration(milliseconds: 1001));
        host.update();
        expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
        expect(host.peerCount, 0);
        await Future<void>.delayed(Duration.zero); // deliver the event
        expect(hostEvents.single.reason, 'Connection timeout');
        await client.disconnect();
      },
    );

    test('Peer.timeSinceLastReceive follows the injected clock', () {
      final c = ManualNetClock(500);
      final peer = Peer(
        id: 1,
        address: const NetAddress('10.0.0.1', 1),
        clock: c,
      );
      peer.processReceivedSequence(1);
      expect(peer.lastReceiveMs, 500);
      expect(peer.timeSinceLastReceive, Duration.zero);
      c.advance(const Duration(seconds: 3));
      expect(peer.timeSinceLastReceive, const Duration(seconds: 3));
      peer.processReceivedSequence(2);
      expect(peer.timeSinceLastReceive, Duration.zero);
    });

    test('reliable retransmits follow the injected clock', () {
      final c = ManualNetClock();
      final peer = Peer(
        id: 1,
        address: const NetAddress('10.0.0.1', 1),
        clock: c,
      );
      peer.addPendingReliable(1, Uint8List.fromList([1, 2, 3]));
      const fallback = Duration(milliseconds: 100);
      expect(peer.getPacketsToRetransmit(fallback), isEmpty);
      c.advance(const Duration(milliseconds: 101));
      expect(peer.getPacketsToRetransmit(fallback), hasLength(1));
      expect(peer.getPacketsToRetransmit(fallback), isEmpty);
      c.advance(const Duration(milliseconds: 101));
      expect(peer.getPacketsToRetransmit(fallback), hasLength(1));
    });

    test('back-dating lastReceiveTime still moves the timeout', () {
      final c = ManualNetClock(100000);
      final peer = Peer(
        id: 1,
        address: const NetAddress('10.0.0.1', 1),
        clock: c,
      );
      peer.processReceivedSequence(1);
      // Code written against 0.5.0 simulated a stale peer this way.
      peer.lastReceiveTime = DateTime.now().subtract(
        const Duration(seconds: 20),
      );
      expect(
        peer.timeSinceLastReceive,
        greaterThanOrEqualTo(const Duration(seconds: 20)),
      );
      expect(peer.timeSinceLastReceive, lessThan(const Duration(seconds: 21)));
    });

    test('default clock keeps wall-clock behaviour', () {
      final peer = Peer(id: 1, address: const NetAddress('10.0.0.1', 1));
      expect(identical(peer.clock, NetClock.system), isTrue);
      peer.processReceivedSequence(1);
      expect(peer.timeSinceLastReceive, lessThan(const Duration(seconds: 1)));
      expect(
        DateTime.now().difference(peer.lastReceiveTime),
        lessThan(const Duration(seconds: 1)),
      );
      expect(
        DateTime.now().difference(peer.lastSendTime),
        lessThan(const Duration(seconds: 1)),
      );
    });
  });
}
