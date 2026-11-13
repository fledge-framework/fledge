import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';
import 'package:test/test.dart';

import 'fake_steam.dart';

const hostId = 76561198000000001;
const friendId = 76561198000000002;
const strangerId = 76561198000000003;

void main() {
  group('addresses', () {
    test('a Steam address is the user\'s identity string, port unused', () {
      expect(steamAddress(hostId), const NetAddress('steam:$hostId', 0));
      expect(steamIdOf('steam:$hostId'), hostId);
      expect(steamIdOf('steam:'), isNull);
      expect(steamIdOf('steam:abc'), isNull);
      expect(steamIdOf('dev:alice'), isNull);
      expect(steamIdOf('192.168.1.2'), isNull);
    });
  });

  group('SteamTransport', () {
    late FakeSteamNetwork net;
    late SteamTransport host;
    late SteamTransport friend;

    setUp(() async {
      net = FakeSteamNetwork();
      host = SteamTransport(net.user(hostId));
      friend = SteamTransport(net.user(friendId));
      await host.bind(7777);
      await friend.bind(0);
    });

    tearDown(() async {
      await host.close();
      await friend.close();
    });

    test('binding gives this user\'s Steam address', () {
      expect(host.localAddress, steamAddress(hostId));
      expect(host.state, ConnectionState.connected);
    });

    test('datagrams arrive from the sender\'s Steam address', () async {
      final got = <ReceivedPacket>[];
      host.onReceive.listen(got.add);
      await friend.send(steamAddress(hostId), Uint8List.fromList([1, 2, 3]));
      host.poll();
      await Future<void>.delayed(Duration.zero);
      expect(got.single.source, steamAddress(friendId));
      expect(got.single.data, [1, 2, 3]);
      // And back the other way.
      final back = <ReceivedPacket>[];
      friend.onReceive.listen(back.add);
      await host.send(steamAddress(friendId), Uint8List.fromList([9]));
      friend.poll();
      await Future<void>.delayed(Duration.zero);
      expect(back.single.source, steamAddress(hostId));
    });

    test('a refused session\'s datagrams never arrive', () async {
      final picky = SteamTransport(
        net.user(strangerId),
        acceptSession: (id) => id != friendId,
      );
      await picky.bind(0);
      final got = <ReceivedPacket>[];
      picky.onReceive.listen(got.add);
      await friend.send(steamAddress(strangerId), Uint8List.fromList([1]));
      picky.poll();
      await Future<void>.delayed(Duration.zero);
      expect(got, isEmpty);
      expect(net.user(strangerId).closed, contains(friendId));
      await picky.close();
    });

    test('resolves steam: hosts, and nothing else', () async {
      expect(await friend.resolve('steam:$hostId', 0), steamAddress(hostId));
      expect(() => friend.resolve('localhost', 7777), throwsArgumentError);
      expect(
        () => friend.send(const NetAddress('10.0.0.1', 1), Uint8List(1)),
        throwsArgumentError,
      );
    });

    test('closing ends the sessions it opened', () async {
      await friend.send(steamAddress(hostId), Uint8List(1));
      await friend.close();
      expect(net.user(friendId).closed, contains(hostId));
      friend = SteamTransport(net.user(friendId));
      await friend.bind(0);
    });
  });

  group('Steam identities', () {
    test('the provider presents steam:<SteamID64>', () async {
      final steam = FakeSteamNetwork().user(friendId);
      final identity = await SteamIdentityProvider(steam).identify();
      expect(identity.id, 'steam:$friendId');
      expect(identity.proof, isEmpty);
    });

    test(
      'the verifier accepts a steam: identity only from that user',
      () async {
        const verifier = SteamIdentityVerifier();
        final proof = Uint8List(0);
        expect(
          await verifier.verify(
            'steam:$friendId',
            proof,
            source: steamAddress(friendId),
          ),
          isTrue,
        );
        expect(
          await verifier.verify(
            'steam:$hostId',
            proof,
            source: steamAddress(friendId),
          ),
          isFalse,
        );
        expect(
          await verifier.verify(
            'steam:$friendId',
            proof,
            source: const NetAddress('10.0.0.5', 7777),
          ),
          isFalse,
        );
        expect(await verifier.verify('steam:$friendId', proof), isFalse);
      },
    );
  });

  group('a fledge_net session over Steam', () {
    late FakeSteamNetwork net;
    final apps = <App>[];

    setUp(() {
      ComponentId.resetRegistry();
      net = FakeSteamNetwork();
    });

    tearDown(() async {
      for (final app in apps) {
        await app.world.getResource<NetworkSession>()!.close();
      }
      apps.clear();
    });

    NetworkSession session(int steamId, {IdentityProvider? identity}) {
      final config = NetworkConfig(
        identityProvider: identity ?? SteamIdentityProvider(net.user(steamId)),
        identityVerifier: const SteamIdentityVerifier(),
      );
      final app = App()
        ..insertResource(config.fixedTimestep())
        ..addPlugin(
          NetworkPlugin(config: config, replication: ReplicationRegistry()),
        );
      apps.add(app);
      return app.world.getResource<NetworkSession>()!;
    }

    test('a friend joins by SteamID and the host knows who they are', () async {
      final host = session(hostId);
      await host.host(transport: SteamTransport(net.user(hostId)));
      final friend = session(friendId);
      final joined = await friend
          .join(
            'steam:$hostId',
            0,
            transport: SteamTransport(net.user(friendId)),
          )
          .timeout(const Duration(seconds: 5));
      expect(joined, isTrue, reason: friend.lastError);
      expect(host.localIdentity, 'steam:$hostId');
      expect(friend.localIdentity, 'steam:$friendId');
      final peer = host.peerFor('steam:$friendId');
      expect(peer, isNotNull);
      expect(host.identityOf(peer!), 'steam:$friendId');
    });

    test('nobody can join as another Steam user', () async {
      final host = session(hostId);
      await host.host(transport: SteamTransport(net.user(hostId)));
      // The stranger claims to be the friend.
      final impostor = session(
        strangerId,
        identity: SteamIdentityProvider(net.user(friendId)),
      );
      final joined = await impostor
          .join(
            'steam:$hostId',
            0,
            transport: SteamTransport(net.user(strangerId)),
          )
          .timeout(const Duration(seconds: 15));
      expect(joined, isFalse);
      expect(impostor.lastError, contains('Authentication failed'));
      expect(host.peerFor('steam:$friendId'), isNull);
    });
  });
}
