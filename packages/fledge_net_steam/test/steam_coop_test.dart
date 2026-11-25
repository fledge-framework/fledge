import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';
import 'package:test/test.dart';

import 'fake_steam.dart';

const hostId = 76561198000000001;
const friendId = 76561198000000002;
const thirdId = 76561198000000003;

void main() {
  group('launch arguments and connect strings', () {
    test('a +connect_lobby launch names the lobby to join', () {
      expect(
        Steam.lobbyFromArgs(['--foo', '+connect_lobby', '109775240000000001']),
        109775240000000001,
      );
      expect(Steam.lobbyFromArgs(['+connect_lobby']), isNull);
      expect(Steam.lobbyFromArgs(['+connect_lobby', 'x']), isNull);
      expect(Steam.lobbyFromArgs(const []), isNull);
    });

    test('the advertised connect string reads back as the lobby', () {
      final connect = SteamCoop.connectString(109775240000000001);
      expect(Steam.lobbyFromConnect(connect), 109775240000000001);
      expect(Steam.lobbyFromConnect('  $connect  '), 109775240000000001);
      expect(Steam.lobbyFromConnect('something else'), isNull);
    });
  });

  group('SteamCoop', () {
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

    NetworkSession session(int steamId) {
      final config = NetworkConfig(
        identityProvider: SteamIdentityProvider(net.user(steamId)),
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

    SteamCoop coop(int steamId) =>
        SteamCoop(net.user(steamId), net.user(steamId));

    test(
      'hosting opens a lobby that names the host and advertises it',
      () async {
        final host = coop(hostId);
        final lobby = await host.host(session(hostId), maxPlayers: 3);
        expect(host.lobby, lobby);
        expect(net.lobbies[lobby]!.data[SteamCoop.hostKey], 'steam:$hostId');
        expect(net.lobbies[lobby]!.max, 3);
        expect(
          net.user(hostId).presence['connect'],
          SteamCoop.connectString(lobby),
        );
        host.invite();
        expect(net.user(hostId).invitesOpened, [lobby]);
      },
    );

    test(
      'a friend joins through the lobby and the host knows who they are',
      () async {
        final hostSession = session(hostId);
        final lobby = await coop(hostId).host(hostSession);
        final friend = coop(friendId);
        final joined = await friend
            .join(session(friendId), lobby)
            .timeout(const Duration(seconds: 5));
        expect(joined, isTrue);
        expect(net.lobbies[lobby]!.members, [hostId, friendId]);
        expect(hostSession.peerFor('steam:$friendId'), isNotNull);
        expect(
          net.user(friendId).presence['connect'],
          SteamCoop.connectString(lobby),
        );
      },
    );

    test('without advertised data, the lobby owner is the host', () async {
      final lobby = await coop(hostId).host(session(hostId));
      net.lobbies[lobby]!.data.clear();
      expect(coop(friendId).hostOf(lobby), 'steam:$hostId');
    });

    test('a full lobby turns a friend away', () async {
      final lobby = await coop(hostId).host(session(hostId), maxPlayers: 2);
      expect(await coop(friendId).join(session(friendId), lobby), isTrue);
      await expectLater(
        coop(thirdId).join(session(thirdId), lobby),
        throwsA(isA<SteamLobbyException>()),
      );
    });

    test(
      'a lobby Steam cannot create is reported, and nothing is hosted',
      () async {
        net.failNextLobby = true;
        final hostSession = session(hostId);
        await expectLater(
          coop(hostId).host(hostSession),
          throwsA(isA<SteamLobbyException>()),
        );
        expect(hostSession.role, NetworkRole.offline);
      },
    );

    test('a join the host refuses leaves the lobby again', () async {
      // The host only takes identities its verifier vouches for: none.
      final config = NetworkConfig(
        identityProvider: SteamIdentityProvider(net.user(hostId)),
        identityVerifier: TokenVerifier((_, _) async => false),
      );
      final app = App()
        ..insertResource(config.fixedTimestep())
        ..addPlugin(
          NetworkPlugin(config: config, replication: ReplicationRegistry()),
        );
      apps.add(app);
      final lobby = await coop(
        hostId,
      ).host(app.world.getResource<NetworkSession>()!);
      final friend = coop(friendId);
      final joined = await friend
          .join(session(friendId), lobby)
          .timeout(const Duration(seconds: 15));
      expect(joined, isFalse);
      expect(friend.lobby, isNull);
      expect(net.lobbies[lobby]!.members, [hostId]);
      expect(net.user(friendId).presence, isEmpty);
    });

    test('a join that throws leaves the lobby again', () async {
      final lobby = await coop(hostId).host(session(hostId));
      final friend = coop(friendId);
      // Hosting first makes the friend's join throw: one session at a time.
      final busy = session(friendId);
      await coop(friendId).host(busy);
      await expectLater(friend.join(busy, lobby), throwsStateError);
      expect(friend.lobby, isNull);
      expect(net.lobbies[lobby]!.members, [hostId]);
    });

    test('leaving stops advertising', () async {
      final host = coop(hostId);
      final lobby = await host.host(session(hostId));
      host.leave();
      expect(host.lobby, isNull);
      expect(net.lobbies[lobby]!.members, isEmpty);
      expect(net.user(hostId).presence, isEmpty);
    });
  });
}
