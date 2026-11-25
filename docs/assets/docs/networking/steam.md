# Steam

`fledge_net_steam` runs a `fledge_net` session over Steam Networking Messages. Datagrams go through Valve's relays with NAT traversal, so friends host and join without forwarding ports, and Steam authenticates the sender of every datagram. It also gives players a Steam identity (`steam:<SteamID64>`) and lets them host and join through Steam lobbies, overlay invites and "Join Game".

## What you need

```yaml
dependencies:
  fledge_net: ^0.7.0
  fledge_net_steam: ^0.7.0
```

- **Desktop only**: Windows, Linux and macOS. The package calls the Steamworks API through `dart:ffi`, so it doesn't work on the web (or mobile).
- **The Steam client running and logged in** on every player's machine.
- **The `steam_api` library from the [Steamworks SDK](https://partner.steamgames.com/)**. The package doesn't ship it. Take it from the SDK's `sdk/redistributable_bin/`: `win64/steam_api64.dll`, `linux64/libsteam_api.so` or `osx/libsteam_api.dylib`. The SDK license lets you redistribute these with your game.
- **An app id**: your game's, or `480` (Valve's "Spacewar" test app) during development.

## Initialising Steam

```dart
import 'package:fledge_net_steam/fledge_net_steam.dart';

Steam? startSteam() {
  try {
    final steam = Steam.init(appId: 480); // 480: Valve's test app
    print('Signed in as ${steam.personaName} (${steam.localSteamId})');
    return steam;
  } on SteamException catch (e) {
    // e.result: SteamInitResult.failedGeneric, noSteamClient or versionMismatch
    print('Steam unavailable (${e.result.name}): ${e.message}');
    return null;
  } on ArgumentError catch (e) {
    print('steam_api library not found: $e');
    return null;
  }
}
```

`Steam.init({libraryPath, appId, pumpInterval})`:

- **`libraryPath`**: the `steam_api` library to load. By default `Steam.init` first looks where a packaged game keeps it (`Steam.bundledLibraryPaths`), then loads it by name (`Steam.libraryName`: `steam_api64.dll`, `libsteam_api.so` or `libsteam_api.dylib`) the platform's usual way. During development, point it at an extracted SDK.
- **`appId`**: for development. When the game wasn't launched by Steam (no `SteamAppId` in the environment), `Steam.init` writes a `steam_appid.txt` containing the id to the current working directory if there isn't one. That file is how Steam learns which app a game launched outside Steam is. Add `steam_appid.txt` to `.gitignore`. Builds launched by Steam leave `appId` null.
- **`pumpInterval`** (default 10 ms): how often Steam's callbacks run. `Steam` runs them on its own timer, so lobby results and invites arrive in menus, before any session exists. `steam.pump()` runs them immediately.
- Throws `SteamException` (with a `SteamInitResult`: `failedGeneric`, `noSteamClient`, `versionMismatch`) when Steam can't be initialised, and `ArgumentError` when the library can't be loaded.

Call `steam.shutdown()` when the game exits. Nothing on that `Steam` object works afterwards.

### Shipping the library

Put `steam_api` where `Steam.bundledLibraryPaths` looks:

| OS | Location |
|---|---|
| Windows | Next to the executable (`steam_api64.dll`) |
| Linux | The bundle's `lib/` directory (or next to the executable) |
| macOS | The app's `Contents/Frameworks/` (or next to the executable in `Contents/MacOS/`) |

A Flutter build doesn't copy it for you: add it to your build or packaging step (on macOS, for example, a Copy Files build phase into Frameworks). A game launched by Steam needs no `steam_appid.txt`.

## Hosting and joining

`SteamTransport` is a `fledge_net` transport between Steam users. Give it to `session.host` and `session.join`, and use the Steam identity provider and verifier:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

Future<void> play(Steam steam, {int? hostSteamId}) async {
  final config = NetworkConfig(
    identityProvider: SteamIdentityProvider(steam), // steam:<SteamID64>
    identityVerifier: const SteamIdentityVerifier(), // only from that Steam user
    disconnectPolicy: OwnedEntityPolicy.holdForReturn,
  );
  final app = App()
    ..insertResource(config.fixedTimestep())
    ..addPlugin(NetworkPlugin(config: config));
  final session = app.world.getResource<NetworkSession>()!;

  if (hostSteamId == null) {
    await session.host(transport: SteamTransport(steam));
  } else {
    final ok = await session.join(
      'steam:$hostSteamId', // the port is unused
      0,
      transport: SteamTransport(steam),
    );
    if (!ok) print('Join failed: ${session.lastError}');
  }
}
```

### Addresses

Addresses are Steam users: `NetAddress('steam:<SteamID64>', 0)`. `steamAddress(steamId)` builds one, `steamIdOf(hostOrIdentity)` reads the SteamID64 back (or returns `null`), and `steamScheme` is `'steam'`. The address's host is the same string as the user's player identity. `SteamTransport` implements `AddressResolver`, so `join('steam:…', 0)` is resolved by the transport and never reaches DNS. `bind`'s port is ignored: a Steam user has one address.

### SteamTransport

`SteamTransport(steam, {pollInterval, acceptSession, maxBufferedPackets})`:

| Option | Default | Description |
|---|---|---|
| `pollInterval` | 2 ms | How often Steam is checked for new datagrams and session requests. |
| `acceptSession` | accept everyone | `bool Function(int steamId)`: whether to accept a session another user started. Refused users' datagrams are never delivered. |
| `maxBufferedPackets` | 1024 | Datagrams kept while nothing listens (oldest dropped first). |

- **Datagrams are sent unreliable and unbuffered** (no Nagle delay). `fledge_net` does its own acks, ordering and fragmentation, so a session behaves the same over Steam as over UDP. A send Steam refuses counts in `transport.stats.packetsLost`.
- **Sessions**: Steam asks before delivering datagrams from someone new. By default every session is accepted, and the host's handshake (password, identity verifier) decides who actually joins. To turn strangers away before the handshake, filter with `acceptSession`, for example `(id) => steam.lobbyMembers(lobby).contains(id)`.
- Closing the transport ends the sessions it opened but leaves Steam initialised, because other transports or features may share the `Steam` object.

### Steam identities

`SteamIdentityProvider(steam)` presents `steam:<SteamID64>` with no proof. `SteamIdentityVerifier` accepts it only when the connect came over `SteamTransport` from that same SteamID64, which Steam has authenticated. Nobody can claim another Steam user's identity.

To also accept LAN players on the same host, combine verifiers by scheme:

```dart
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

final config = NetworkConfig(
  identityVerifier: SchemeVerifier({
    'steam': const SteamIdentityVerifier(),
    'dev': const TrustingVerifier(), // LAN only: dev identities are trusted as claimed
  }),
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,
);
```

Pair Steam identities with `OwnedEntityPolicy.holdForReturn`: a player whose game crashes gets their avatar back when they rejoin, and a rejoin replaces their stale connection immediately. See [Player identity](/docs/networking/security-identity#player-identity).

## Lobbies, invites and Join Game

`SteamCoop` hosts and joins through a Steam lobby, the way players expect: the host opens a lobby and invites friends from the overlay, and friends join by accepting the invite or picking "Join Game" in their friends list, even when the game isn't running yet.

```dart
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

Future<void> hostLobby(Steam steam, NetworkSession session) async {
  final coop = SteamCoop(steam, steam);
  final lobby = await coop.host(session, maxPlayers: 4); // friends-only by default
  print('Hosting lobby $lobby');
  coop.invite(); // the Steam overlay's invite dialog
}

Future<void> joinLobbies(
  Steam steam,
  NetworkSession session,
  List<String> args,
) async {
  final coop = SteamCoop(steam, steam);

  // Invites accepted, or "Join Game" picked, while the game runs:
  steam.lobbyJoinRequests.listen((lobby) => coop.join(session, lobby));

  // Steam launched the game to join a lobby (+connect_lobby <id>):
  final pending = Steam.lobbyFromArgs(args);
  if (pending != null && !await coop.join(session, pending)) {
    print('Join failed: ${session.lastError}');
  }
}
```

- **`SteamCoop(lobbies, networking)`** takes the matchmaking and networking halves; pass the `Steam` object for both.
- **`host(session, {type, maxPlayers, transport})`** creates a lobby (`LobbyType.friendsOnly` by default; also `private`, `public`, `invisible`), writes the host's address into the lobby data under `SteamCoop.hostKey` (`fledge_host`), starts hosting over `SteamTransport`, and sets the rich presence `connect` string. Returns the lobby id. If hosting fails it leaves the lobby and rethrows.
- **`invite()`** opens the overlay's invite dialog for the hosted lobby.
- **`join(session, lobby, {transport})`** enters the lobby, finds the host (`hostOf(lobby)`: the advertised `hostKey`, or else the lobby owner) and joins over Steam. It resolves to whether the session accepted; on failure it leaves the lobby again and `session.lastError` says why. A lobby that's full or gone throws `SteamLobbyException`.
- **`leave()`** leaves the lobby and clears the rich presence. It doesn't close the session, and `session.close()` doesn't leave the lobby: do both.
- **`lobby`** is the lobby this player is in, if any.
- **Rich presence**: hosting or joining sets `connect` to `SteamCoop.connectString(lobby)` (`+connect_lobby <id>`), which puts "Join Game" on the player in friends' lists. When the game isn't running, Steam launches it with those arguments; when it is, the request arrives on `steam.lobbyJoinRequests`.
- **Launch arguments**: `Steam.lobbyFromArgs(args)` finds `+connect_lobby <id>` in `main`'s arguments (a Flutter desktop runner must forward its command-line arguments to the Dart entrypoint). `Steam.lobbyFromConnect(connect)` parses the same from a `connect` string.

The lobby only names the host. The game runs over `SteamTransport`, and the host's handshake still decides who gets in.

### Matchmaking calls

`Steam` implements `SteamMatchmaking`, the lower-level lobby and friends API that `SteamCoop` uses:

| Member | Description |
|---|---|
| `createLobby(type, maxMembers)` | Creates and enters a lobby; completes with its id. |
| `joinLobby(lobby)` | Enters a lobby; throws `SteamLobbyException` if it's full, gone or closed. |
| `leaveLobby(lobby)` | Leaves it. |
| `setLobbyData(lobby, key, value)` / `lobbyData(lobby, key)` | Lobby data (only the owner may set it). |
| `lobbyOwner(lobby)`, `lobbyMembers(lobby)` | Who owns it and who is in it (SteamID64s). |
| `openInviteDialog(lobby)` | The overlay's invite dialog. |
| `setRichPresence(key, value)` | Sets a rich presence key, or clears it with `null`. `steam.clearRichPresence()` clears all. |
| `lobbyJoinRequests` | Stream of lobby ids the user asked to join from Steam. |

Failed lobby operations throw `SteamLobbyException`.

## Testing without Steam

`SteamTransport` talks to Steam only through the `SteamNetworking` interface, and `SteamCoop` through `SteamMatchmaking`. `Steam` implements both; tests implement them with fakes and run without Steam:

```dart
import 'dart:typed_data';

import 'package:fledge_net_steam/fledge_net_steam.dart';

/// Users on a pretend Steam network, by SteamID64.
class FakeSteamNetwork {
  final users = <int, FakeSteam>{};
  FakeSteam user(int id) => users.putIfAbsent(id, () => FakeSteam(this, id));
}

class FakeSteam implements SteamNetworking {
  FakeSteam(this.network, this.localSteamId);

  final FakeSteamNetwork network;
  final _inbox = <SteamDatagram>[];

  @override
  final int localSteamId;

  @override
  bool send(int steamId, Uint8List data) {
    network.users[steamId]?._inbox.add(SteamDatagram(localSteamId, data));
    return true;
  }

  @override
  List<SteamDatagram> receive() {
    final taken = List.of(_inbox);
    _inbox.clear();
    return taken;
  }

  @override
  List<int> takeSessionRequests() => const []; // everyone is accepted

  @override
  void accept(int steamId) {}

  @override
  void close(int steamId) {}
}

final network = FakeSteamNetwork();
final hostTransport = SteamTransport(network.user(76561198000000001));
final clientTransport = SteamTransport(network.user(76561198000000002));
```

Pass these transports to `session.host` and `session.join('steam:76561198000000001', 0, ...)`. `SteamTransport.poll()` delivers waiting datagrams immediately if you don't want to wait for its timer. The package's own tests use a fuller fake, with session requests and lobbies (`packages/fledge_net_steam/test/fake_steam.dart`).

## Walkthrough: the example

`packages/fledge_net_steam/example/example.dart` is a complete co-op program. Run it to host a friends-only lobby, or let Steam launch it with `+connect_lobby <id>` (a friend's "Join Game" or an accepted invite) to join one:

```dart
import 'dart:async';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

Future<void> main(List<String> args) async {
  // 1. Load and initialise Steam. 480 is Valve's test app.
  final steam = Steam.init(appId: 480);

  // 2. Steam identities, verified against Steam's authenticated sender, and
  //    returning players get their entities back.
  final config = NetworkConfig(
    identityProvider: SteamIdentityProvider(steam),
    identityVerifier: const SteamIdentityVerifier(),
    disconnectPolicy: OwnedEntityPolicy.holdForReturn,
  );
  final app = App()
    ..insertResource(config.fixedTimestep())
    ..addPlugin(NetworkPlugin(config: config));
  final session = app.world.getResource<NetworkSession>()!;
  final coop = SteamCoop(steam, steam);

  // 3. Invites accepted while the game is already running.
  steam.lobbyJoinRequests.listen((lobby) => coop.join(session, lobby));

  // 4. Launched by Steam to join a lobby? Join it. Otherwise host one.
  final pending = Steam.lobbyFromArgs(args);
  if (pending != null) {
    final joined = await coop.join(session, pending);
    print(joined ? 'Joined lobby $pending' : 'Join failed: ${session.lastError}');
  } else {
    final lobby = await coop.host(session, maxPlayers: 4);
    print('Hosting lobby $lobby; opening the invite dialog.');
    coop.invite();
  }

  // 5. Drive the app for a minute, then shut down cleanly.
  final stop = DateTime.now().add(const Duration(minutes: 1));
  while (DateTime.now().isBefore(stop)) {
    await app.tick();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  coop.leave();
  steam.shutdown();
}
```

1. `Steam.init` loads `steam_api` and connects to the running Steam client; it throws if either is missing.
2. The config uses Steam identities with `holdForReturn`. The registry is empty here: a real game passes its `ReplicationRegistry` to `NetworkPlugin` as in the [quickstart](/docs/networking/overview#co-op-quickstart).
3. `lobbyJoinRequests` fires when the player accepts an invite or picks "Join Game" while the program runs.
4. `lobbyFromArgs` covers the case where Steam started the program to join a lobby.
5. A plain loop stands in for a game loop: `app.tick()` runs the network systems every frame, and the `await` lets Steam's timers (callbacks every 10 ms, the transport's poll every 2 ms) run in between.

## Limitations

- Desktop only; no web or mobile.
- `enableEncryption` works over Steam (the client resolves `steam:` hosts through the encryption wrapper), but it adds little: Steam already relays the traffic and authenticates each sender, and the pre-shared key still has to reach every player some other way.
- A real Steam session needs two Steam accounts, each signed in to its own Steam client, normally on two machines. Test the game logic with a [`LoopbackNetwork`](/docs/networking/overview#9-test-it-in-one-process) or the fakes above, and save Steam for end-to-end checks.
- The lobby carries no game state: it only says who the host is. Lobby browsing and search aren't wrapped; the matchmaking calls above are what's available.
