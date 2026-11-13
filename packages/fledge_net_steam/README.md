# fledge_net_steam

Steam networking for [Fledge](https://fledge-framework.dev): [`fledge_net`](https://pub.dev/packages/fledge_net) over Steam Networking Messages, with Steam player identities. Friends host and join through Valve's relays with NAT traversal, so nobody forwards ports, and Steam authenticates who every datagram is from.

## Requirements

- Desktop (Windows, Linux, macOS). Uses `dart:ffi`; no web.
- The Steam client running and logged in.
- The `steam_api` library from the [Steamworks SDK](https://partner.steamgames.com/) (`sdk/redistributable_bin/`: `win64/steam_api64.dll`, `linux64/libsteam_api.so`, `osx/libsteam_api.dylib`), shipped next to your executable or loaded from a path. The SDK's license lets you redistribute these libraries with your game; this package doesn't include them.
- An app id: your game's, or 480 (Valve's "Spacewar" test app) during development.

## Quick start

```dart
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net_steam/fledge_net_steam.dart';

final steam = Steam.init(appId: 480); // throws SteamException if Steam isn't up

final config = NetworkConfig(
  identityProvider: SteamIdentityProvider(steam),   // steam:<SteamID64>
  identityVerifier: const SteamIdentityVerifier(),  // only from that user
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,
);

// Host:
await session.host(transport: SteamTransport(steam));

// A friend, with the host's SteamID64:
await session.join(
  'steam:76561198000000000',
  0,
  transport: SteamTransport(steam),
);

// On exit:
steam.shutdown();
```

## Lobbies, invites and "Join Game"

`SteamCoop` hosts and joins through a Steam lobby, the way players expect:

```dart
final coop = SteamCoop(steam, steam);

// Host: open a friends-only lobby, start hosting, advertise "Join Game".
await coop.host(session, maxPlayers: 4);
coop.invite(); // the Steam overlay's invite dialog

// Friend, while running: accepting an invite or "Join Game".
steam.lobbyJoinRequests.listen((lobby) => coop.join(session, lobby));

// Friend, when Steam launched the game to join (`+connect_lobby <id>`).
final pending = Steam.lobbyFromArgs(args); // main(List<String> args)
if (pending != null) await coop.join(session, pending);
```

- The lobby only names the host (`SteamCoop.hostKey`, falling back to the lobby owner); the game runs over `SteamTransport`, and the host's handshake still decides who gets in.
- Hosting sets the rich presence `connect` string, which puts "Join Game" on the player in friends' lists; leaving clears it.
- `Steam` runs Steam's callbacks itself (every `pumpInterval`), so invites arrive in menus, before any session exists.
- The lower-level calls (`createLobby`, `joinLobby`, `setLobbyData`, `lobbyMembers`, `openInviteDialog`, `setRichPresence`) are on `Steam` through the `SteamMatchmaking` interface.

## Shipping

Ship the `steam_api` library with the game, where `Steam.init` looks first (`Steam.bundledLibraryPaths`): next to the executable on Windows, in the bundle's `lib/` on Linux, in the app's `Contents/Frameworks/` on macOS. A game launched by Steam needs no `steam_appid.txt`; `Steam.init` only writes one when Steam didn't launch it.

## How it fits fledge_net

- **Addresses** are Steam users: `NetAddress('steam:<SteamID64>', 0)` (`steamAddress`). The host part is the same string as the user's player identity. `SteamTransport` resolves `steam:` hosts itself, so they never reach DNS.
- **Datagrams** go unreliable and unbuffered: fledge_net does its own reliability, ordering and fragmentation-free framing, so it behaves the same over Steam as over UDP.
- **Sessions** started by others are accepted by default (`acceptSession`); who may actually join is decided by the host's handshake (password, identity verifier).
- **Identities**: `SteamIdentityProvider` presents `steam:<SteamID64>` with no proof, and `SteamIdentityVerifier` accepts it only when the connect came from that Steam user, whom Steam has authenticated. To accept LAN `dev:` players on the same host, combine verifiers: `SchemeVerifier({'steam': const SteamIdentityVerifier(), 'dev': const TrustingVerifier()})`.

## Development

- `Steam.init(appId: 480)` writes a `steam_appid.txt` with the id to the current directory if none is there, which is how Steam learns the app of a game not launched through it. Keep it out of version control. Builds launched by Steam pass no `appId`.
- `Steam.init(libraryPath: …)` loads the library from an extracted SDK instead of next to the executable.
- Tests use a fake Steam network (`SteamNetworking` is the seam), so they run without Steam. `test/bindings_test.dart` checks every bound function exists in the real library when `STEAMWORKS_SDK` points at an extracted SDK.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/net) (Steam section).

## License

Apache 2.0. The Steamworks SDK and its libraries are Valve's, under the Steamworks SDK license.
