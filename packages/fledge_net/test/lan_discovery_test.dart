import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('LanBeacon', () {
    LanBeacon beacon({String payload = '{"name":"Red Acre"}'}) => LanBeacon(
      appId: 'tharsis',
      port: 7777,
      instance: 0xDEADBEEF,
      payload: _bytes(payload),
    );

    test('round-trips', () {
      final decoded = LanBeacon.tryDecode(beacon().encode())!;
      expect(decoded.appId, 'tharsis');
      expect(decoded.port, 7777);
      expect(decoded.instance, 0xDEADBEEF);
      expect(decoded.leaving, isFalse);
      expect(utf8.decode(decoded.payload), '{"name":"Red Acre"}');

      final leaving = LanBeacon.tryDecode(
        LanBeacon(appId: 'a', port: 1, instance: 0, leaving: true).encode(),
      )!;
      expect(leaving.leaving, isTrue);
      expect(leaving.payload, isEmpty);
    });

    test('anything malformed decodes to null, never throws', () {
      final good = beacon().encode();
      Uint8List edited(void Function(Uint8List b) edit) =>
          Uint8List.fromList(good)..apply(edit);

      expect(LanBeacon.tryDecode(Uint8List(0)), isNull);
      expect(LanBeacon.tryDecode(edited((b) => b[0] ^= 0xFF)), isNull);
      expect(
        LanBeacon.tryDecode(edited((b) => b[4] = 2)),
        isNull,
        reason: 'v2',
      );
      // Truncated at every length.
      for (var n = 0; n < good.length; n++) {
        expect(LanBeacon.tryDecode(Uint8List.sublistView(good, 0, n)), isNull);
      }
      // Bytes left over.
      expect(LanBeacon.tryDecode(Uint8List.fromList([...good, 0])), isNull);
      // Port 0.
      expect(
        LanBeacon.tryDecode(
          edited(
            (b) => b
              ..[10] = 0
              ..[11] = 0,
          ),
        ),
        isNull,
      );
      // A game packet is not a beacon.
      final packet = Packet(
        header: PacketHeader(type: PacketType.connect, sequence: 1),
        payload: Uint8List(4),
      ).toBytes();
      expect(LanBeacon.tryDecode(packet), isNull);
      // Too big to be one.
      expect(
        LanBeacon.tryDecode(Uint8List(LanBeacon.maxBeaconBytes + 1)),
        isNull,
      );
      // Random garbage.
      final random = Random(7);
      for (var i = 0; i < 500; i++) {
        final junk = Uint8List.fromList(
          List.generate(random.nextInt(80), (_) => random.nextInt(256)),
        );
        expect(() => LanBeacon.tryDecode(junk), returnsNormally);
      }
    });

    test('invalid beacons are refused when made', () {
      expect(
        () => LanBeacon(appId: '', port: 1, instance: 0),
        throwsArgumentError,
      );
      expect(
        () => LanBeacon(appId: 'x' * 65, port: 1, instance: 0),
        throwsArgumentError,
      );
      expect(
        () => LanBeacon(appId: 'a', port: 0, instance: 0),
        throwsArgumentError,
      );
      expect(
        () => LanBeacon(
          appId: 'a',
          port: 1,
          instance: 0,
          payload: Uint8List(LanBeacon.maxPayloadBytes + 1),
        ),
        throwsArgumentError,
      );
      final biggest = LanBeacon(
        appId: 'x' * LanBeacon.maxAppIdBytes,
        port: 65535,
        instance: 0xFFFFFFFF,
        payload: Uint8List(LanBeacon.maxPayloadBytes),
      ).encode();
      expect(biggest.length, LanBeacon.maxBeaconBytes);
      expect(LanBeacon.tryDecode(biggest), isNotNull);
    });
  });

  group('LoopbackNetwork broadcast', () {
    test('reaches every transport bound on the port', () async {
      final net = LoopbackNetwork(clock: ManualNetClock());
      final a = net.createTransport(host: '10.0.0.2');
      final b = net.createTransport(host: '10.0.0.3');
      final other = net.createTransport(host: '10.0.0.4');
      final sender = net.createTransport(host: '10.0.0.5');
      await a.bind(5000);
      await b.bind(5000);
      await other.bind(5001);
      await sender.bind(0);
      await sender.send(
        const NetAddress('255.255.255.255', 5000),
        Uint8List.fromList([1]),
      );
      await net.flush();
      expect(a.receive().single.source.host, '10.0.0.5');
      expect(b.receive(), hasLength(1));
      expect(other.receive(), isEmpty);
      expect(net.stats.delivered, 2);
    });
  });

  group('LanAdvertiser and LanBrowser', () {
    late ManualNetClock clock;
    late LoopbackNetwork net;

    setUp(() {
      clock = ManualNetClock();
      net = LoopbackNetwork(clock: clock);
    });

    LanAdvertiser advertiser({
      String appId = 'tharsis',
      String host = '192.168.1.20',
      String payload = 'Red Acre',
      int gamePort = 7777,
    }) => LanAdvertiser(
      appId: appId,
      gamePort: gamePort,
      payload: _bytes(payload),
      // Beacons go out when the test says (announce), not on a timer.
      interval: const Duration(hours: 1),
      transportFactory: () => net.createTransport(host: host),
      targets: () async => ['255.255.255.255'],
    );

    LanBrowser browser({
      String appId = 'tharsis',
      String host = '192.168.1.30',
    }) => LanBrowser(
      appId: appId,
      clock: clock,
      transportFactory: () => net.createTransport(host: host),
    );

    test('a browser lists an advertised host at its source address', () async {
      final b = browser();
      final changes = <List<LanHost>>[];
      b.onChanged.listen(changes.add);
      await b.start();
      expect(b.isListening, isTrue);
      final a = advertiser();
      await a.start();
      await net.flush();

      final host = b.hosts.single;
      expect(host.address, const NetAddress('192.168.1.20', 7777));
      expect(host.payloadText, 'Red Acre');
      expect(host.instance, a.instance);
      expect(changes, hasLength(1));

      // The same beacon again changes nothing but when it was heard.
      clock.nowMs += 400;
      await a.announce();
      await net.flush();
      expect(b.hosts.single.lastSeenMs, clock.nowMs);
      expect(changes, hasLength(1));

      // A new payload is a change.
      a.payload = _bytes('Red Acre, 2 players');
      await a.announce();
      await net.flush();
      expect(b.hosts.single.payloadText, 'Red Acre, 2 players');
      expect(changes, hasLength(2));
      await a.stop();
      await b.dispose();
    });

    test('another game\'s hosts are never listed', () async {
      final b = browser();
      await b.start();
      final a = advertiser(appId: 'another-game');
      await a.start();
      await net.flush();
      expect(b.hosts, isEmpty);
      expect(b.ignoredDatagrams, 1);
      await a.stop();
      await b.dispose();
    });

    test('a host not heard for the expiry is forgotten', () async {
      final b = browser();
      final changes = <List<LanHost>>[];
      b.onChanged.listen(changes.add);
      await b.start();
      final a = advertiser();
      await a.start(); // one beacon, then silence (a crashed host)
      await net.flush();
      expect(b.hosts, hasLength(1));
      clock.nowMs += LanDiscovery.defaultExpiry.inMilliseconds;
      expect(b.hosts, hasLength(1), reason: 'not yet');
      clock.nowMs += 1;
      b.prune();
      expect(b.hosts, isEmpty);
      await Future<void>.delayed(Duration.zero); // stream events are async
      expect(changes.last, isEmpty);
      await a.stop();
      await b.dispose();
    });

    test('stopping says so: the host leaves the list at once', () async {
      final b = browser();
      await b.start();
      final a = advertiser();
      await a.start();
      await net.flush();
      expect(b.hosts, hasLength(1));
      await a.stop();
      expect(a.isRunning, isFalse);
      await net.flush();
      expect(b.hosts, isEmpty);
      await b.dispose();
    });

    test('several hosts are listed in the order they were heard', () async {
      final b = browser();
      await b.start();
      final first = advertiser(host: '192.168.1.21', payload: 'One');
      final second = advertiser(host: '192.168.1.22', payload: 'Two');
      await first.start();
      await net.flush();
      await second.start();
      await net.flush();
      expect([for (final h in b.hosts) h.payloadText], ['One', 'Two']);
      await first.stop();
      await second.stop();
      await b.dispose();
    });

    group('incoming datagrams', () {
      late LanBrowser b;
      late LoopbackTransport transport;

      setUp(() async {
        b = LanBrowser(
          appId: 'tharsis',
          clock: clock,
          maxHosts: 3,
          transportFactory: () =>
              transport = net.createTransport(host: '192.168.1.30'),
        );
        await b.start();
      });

      tearDown(() => b.dispose());

      Uint8List beacon(
        int instance, {
        String payload = 'x',
        bool leaving = false,
      }) => LanBeacon(
        appId: 'tharsis',
        port: 7777,
        instance: instance,
        leaving: leaving,
        payload: _bytes(payload),
      ).encode();

      Future<void> from(String host, Uint8List data) async {
        transport.inject(NetAddress(host, 50000), data);
        await Future<void>.delayed(Duration.zero);
      }

      test('malformed ones are ignored and counted', () async {
        await from('192.168.1.5', Uint8List.fromList([1, 2, 3]));
        await from('192.168.1.5', Uint8List(2000));
        await from('192.168.1.5', Uint8List.fromList([...beacon(1), 9]));
        await from('not-an-address', beacon(1));
        expect(b.hosts, isEmpty);
        expect(b.ignoredDatagrams, 4);
      });

      test(
        'one host heard on two interfaces is listed once, LAN first',
        () async {
          await from('127.0.0.1', beacon(1, payload: 'a'));
          expect(b.hosts.single.host, '127.0.0.1');
          await from('192.168.1.5', beacon(1, payload: 'a'));
          expect(b.hosts.single.host, '192.168.1.5');
          // Neither loopback nor a second LAN address takes it back.
          await from('127.0.0.1', beacon(1, payload: 'b'));
          await from('10.8.0.2', beacon(1, payload: 'b'));
          expect(b.hosts.single.host, '192.168.1.5');
          expect(b.hosts.single.payloadText, 'a');
          // Only its own address can say it's leaving.
          await from('10.8.0.2', beacon(1, leaving: true));
          expect(b.hosts, hasLength(1));
          await from('192.168.1.5', beacon(1, leaving: true));
          expect(b.hosts, isEmpty);
        },
      );

      test('at most maxHosts are listed', () async {
        for (var i = 0; i < 5; i++) {
          await from('192.168.1.${10 + i}', beacon(i));
        }
        expect(b.hosts, hasLength(3));
        expect(b.ignoredDatagrams, 2);
      });

      test('stopping forgets every host', () async {
        await from('192.168.1.5', beacon(1));
        await b.stop();
        expect(b.hosts, isEmpty);
        expect(b.isListening, isFalse);
      });
    });

    test('a browser that can\'t listen stays empty, then retries', () async {
      final squatter = net.createTransport(host: '192.168.1.30');
      await squatter.bind(LanDiscovery.defaultPort);
      final errors = <Object>[];
      final b = LanBrowser(
        appId: 'tharsis',
        clock: clock,
        retryInterval: const Duration(milliseconds: 10),
        transportFactory: () => net.createTransport(host: '192.168.1.30'),
        onError: errors.add,
      );
      await b.start(); // doesn't throw
      expect(b.isRunning, isTrue);
      expect(b.isListening, isFalse);
      expect(b.hosts, isEmpty);
      expect(errors, hasLength(1));

      await squatter.close();
      for (var i = 0; i < 100 && !b.isListening; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(b.isListening, isTrue);
      expect(errors, hasLength(1), reason: 'reported once');
      await b.dispose();
    });

    test('an advertiser that can\'t open its socket never throws', () async {
      final errors = <Object>[];
      final a = LanAdvertiser(
        appId: 'tharsis',
        gamePort: 7777,
        interval: const Duration(hours: 1),
        transportFactory: _FailingTransport.new,
        targets: () async => ['255.255.255.255'],
        onError: errors.add,
      );
      await a.start();
      expect(a.isRunning, isTrue);
      expect(a.beaconsSent, 0);
      expect(errors, isNotEmpty);
      await a.stop();
    });

    test('invalid configuration is refused up front', () {
      expect(
        () => LanAdvertiser(appId: '', gamePort: 7777),
        throwsArgumentError,
      );
      expect(
        () =>
            LanAdvertiser(appId: 'a', gamePort: 7777)
              ..payload = Uint8List(LanBeacon.maxPayloadBytes + 1),
        throwsArgumentError,
      );
      expect(() => LanBrowser(appId: ''), throwsArgumentError);
    });
  });

  test(
    'broadcastTargets always has the broadcast and loopback addresses',
    () async {
      final targets = await LanDiscovery.broadcastTargets();
      expect(targets, containsAll(['255.255.255.255', '127.0.0.1']));
      for (final t in targets) {
        expect(InternetAddress.tryParse(t)?.type, InternetAddressType.IPv4);
      }
    },
  );

  test('over real UDP sockets on 127.0.0.1', () async {
    // A port of its own, so a game running on this machine doesn't hear it.
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = socket.port;
    socket.close();

    final b = LanBrowser(
      appId: 'tharsis',
      discoveryPort: port,
      transportFactory: () => UdpTransport(
        bindAddress: InternetAddress.loopbackIPv4,
        reusePort: true,
      ),
    );
    final found = b.onChanged.firstWhere((hosts) => hosts.isNotEmpty);
    await b.start();
    expect(b.isListening, isTrue);

    final a = LanAdvertiser(
      appId: 'tharsis',
      gamePort: 9000,
      payload: _bytes('Red Acre'),
      discoveryPort: port,
      interval: const Duration(milliseconds: 50),
      transportFactory: () => UdpTransport(
        bindAddress: InternetAddress.loopbackIPv4,
        broadcast: true,
      ),
      targets: () async => ['127.0.0.1'],
    );
    await a.start();
    final hosts = await found.timeout(const Duration(seconds: 5));
    expect(hosts.single.address, const NetAddress('127.0.0.1', 9000));
    expect(hosts.single.payloadText, 'Red Acre');

    final gone = b.onChanged.firstWhere((hosts) => hosts.isEmpty);
    await a.stop();
    await gone.timeout(const Duration(seconds: 5));
    await b.dispose();
  });
}

extension on Uint8List {
  void apply(void Function(Uint8List b) edit) => edit(this);
}

/// A transport whose socket can never be opened.
class _FailingTransport extends Transport {
  @override
  ConnectionState get state => ConnectionState.failed;
  @override
  NetAddress? get localAddress => null;
  @override
  Stream<ReceivedPacket> get onReceive => const Stream.empty();
  @override
  Stream<ConnectionState> get onStateChange => const Stream.empty();
  @override
  Future<void> bind(int port) async =>
      throw const SocketException('Address already in use');
  @override
  Future<void> close() async {}
  @override
  Future<void> send(NetAddress address, Uint8List data) async =>
      throw StateError('Transport not connected');
  @override
  List<ReceivedPacket> receive() => const [];
}
