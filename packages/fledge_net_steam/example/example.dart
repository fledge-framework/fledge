import 'dart:async';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

/// Co-op over Steam: run it to host a friends-only lobby, or let Steam
/// launch it with `+connect_lobby <id>` (a friend's "Join Game" or an
/// accepted invite) to join one.
///
/// Needs the Steam client running and the Steamworks `steam_api` library
/// next to the executable (or pass `libraryPath:` to [Steam.init]). App id
/// 480 is Valve's "Spacewar" test app.
Future<void> main(List<String> args) async {
  final steam = Steam.init(appId: 480);

  final config = NetworkConfig(
    identityProvider: SteamIdentityProvider(steam), // steam:<SteamID64>
    identityVerifier: const SteamIdentityVerifier(), // only from that user
    disconnectPolicy: OwnedEntityPolicy.holdForReturn,
  );
  final app = App()
    ..insertResource(config.fixedTimestep())
    ..addPlugin(NetworkPlugin(config: config));
  final session = app.world.getResource<NetworkSession>()!;
  final coop = SteamCoop(steam, steam);

  // Invites accepted while the game is already running.
  steam.lobbyJoinRequests.listen((lobby) => coop.join(session, lobby));

  final pending = Steam.lobbyFromArgs(args);
  if (pending != null) {
    final joined = await coop.join(session, pending);
    print(
      joined ? 'Joined lobby $pending' : 'Join failed: ${session.lastError}',
    );
  } else {
    final lobby = await coop.host(session, maxPlayers: 4);
    print('Hosting lobby $lobby; opening the invite dialog.');
    coop.invite();
  }

  // Drive the app for a minute, then shut down cleanly.
  final stop = DateTime.now().add(const Duration(minutes: 1));
  while (DateTime.now().isBefore(stop)) {
    await app.tick();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  coop.leave();
  steam.shutdown();
}
