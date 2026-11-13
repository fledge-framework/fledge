// The connection layer sends single unreliable datagrams; reliable
// delivery is ReliableChannel's job (see replication/building_blocks_test).
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

PacketType? _typeOf(Uint8List data) =>
    data.length > 5 ? PacketType.fromValue(data[5]) : null;

void main() {
  group('Connection layer delivery', () {
    late ManualNetClock clock;
    late LoopbackNetwork net;
    late NetworkHost host;
    late NetworkClient client;
    final sent = <PacketType?>[];

    setUp(() async {
      sent.clear();
      clock = ManualNetClock();
      net = LoopbackNetwork(
        clock: clock,
        latency: const Duration(milliseconds: 10),
        filter: (d) {
          sent.add(_typeOf(d.data));
          return true;
        },
      );
      host = NetworkHost(transport: net.createTransport(), clock: clock);
      client = NetworkClient(transport: net.createTransport(), clock: clock);
      await host.start(7777);
      final connecting = client.connect('127.0.0.1', 7777);
      await net.advance(const Duration(milliseconds: 50));
      expect(await connecting, isTrue);
    });

    tearDown(() async {
      await client.disconnect();
      await host.stop();
      net.clearInFlight();
    });

    test('each send is one datagram, never retransmitted', () async {
      final received = <PeerDataEvent>[];
      host.onData.listen(received.add);
      await client.send(PacketType.custom, Uint8List.fromList([1, 2, 3]));
      for (var i = 0; i < 100; i++) {
        host.update();
        client.update();
        await net.advance(const Duration(milliseconds: 20));
      }
      expect(sent.where((t) => t == PacketType.custom), hasLength(1));
      expect(received.where((e) => e.type == PacketType.custom), hasLength(1));
    });

    test(
      'connectAccepted is not repeated once the client is connected',
      () async {
        for (var i = 0; i < 100; i++) {
          host.update();
          client.update();
          await net.advance(const Duration(milliseconds: 20));
        }
        expect(
          sent.where((t) => t == PacketType.connectAccepted),
          hasLength(1),
        );
      },
    );
  });
}
