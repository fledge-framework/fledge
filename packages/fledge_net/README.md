# fledge_net

Multiplayer networking for [Fledge](https://fledge-framework.dev) games: host-authoritative sessions, an ECS replication layer (spawn/despawn, hierarchy, snapshots, interest management), owned inputs with authority checks, client prediction and reconciliation, tick-keyed interpolation, RPCs and player actions, over UDP with optional AES-256-GCM encryption. Pure Dart.

[![pub package](https://img.shields.io/pub/v/fledge_net.svg)](https://pub.dev/packages/fledge_net)

## Installation

```yaml
dependencies:
  fledge_net: ^0.7.1
```

Desktop first (Windows, macOS, Linux). The UDP transport uses `dart:io` (IPv4), so the web isn't supported. For Steam relays, lobbies and identities, add [`fledge_net_steam`](https://pub.dev/packages/fledge_net_steam).

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

class Position {
  final double x, y;
  const Position(this.x, this.y);
}

class Move {
  final double dx, dy;
  const Move(this.dx, this.dy);
}

final replication = ReplicationRegistry()
  ..component<Position>(
    'position',
    NetCodec<Position>.of(
      encode: (p, out) => out..writeFloat32(p.x)..writeFloat32(p.y),
      decode: (r) => Position(r.readFloat32(), r.readFloat32()),
    ),
    interpolate: (a, b, t) =>
        Position(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t),
  )
  ..input<Move>(
    NetCodec<Move>.of(
      encode: (m, out) => out..writeFloat32(m.dx)..writeFloat32(m.dy),
      decode: (r) => Move(r.readFloat32(), r.readFloat32()),
    ),
  )
  ..predict<Position, Move>(
    step: (s, m, dt) => Position(s.x + m.dx * 100 * dt, s.y + m.dy * 100 * dt),
    error: (a, b) => (a.x - b.x).abs() + (a.y - b.y).abs(),
  );

final config = NetworkConfig(tickRate: 60, syncRate: 20);
final app = App()
  ..insertResource(config.fixedTimestep())
  ..addPlugin(NetworkPlugin(config: config, replication: replication));

final session = app.world.getResource<NetworkSession>()!;
await session.host(port: 7777); // or: await session.join('192.168.1.20', 7777);

// Host: replicate an entity owned by peer 1.
app.world.spawn()
  ..insert(Replicated(owner: 1))
  ..insert(const Position(0, 0));
```

Clients submit input for entities they own through `NetLocalInputs<Move>` (in a `Schedules.fixedPreUpdate` system that joins `NetSets.localInput`); the owning client predicts immediately and the host applies the same step. A step that reads the world (collision) registers as `stepWith:` and gets a `PredictContext`. Test whole sessions in one process with `LoopbackNetwork` and a `ManualNetClock`. For authority tests, the test-only `package:fledge_net/testing.dart` lets a client session send forged inputs and RPCs (`sendRawInput`, `sendRawRpc`).

## Player actions

Inputs are level state sent every tick. Discrete things a player does (use an item, place a machine) are actions: exactly once, in order, on the tick they were sent, accepted or rejected by the host, and shown by the sender straight away.

```dart
registry.action<UseItem>('use', useItemCodec);

session.sendAction(UseItem(slot: 2));                    // client
for (final a in world.getResource<NetActions<UseItem>>()!.entries) {
  session.resolveAction(a, accepted: canUse(a.value));  // host, fixedUpdate
}
session.pendingActions<UseItem>();                       // client: draw these on top
```

## Scaling to a shared world

- **Change-only snapshots**: each client is sent only what changed since its last acknowledged copy.
- **Replicated resources**: big shared state (a tile map) replicates in versioned chunks, only the changed ones, on its own reliable channel: `registry.resource<Farm>('farm', FarmCodec())`.
- **Send budget**: `NetworkConfig(sendBudgetBytesPerSecond: …)` (64 KiB/s by default) caps what each client is sent; big joins stream in.
- **Visibility**: `Replicated(ownerOnly: true)` for private entities, `component<T>(…, ownerOnly: true)` for private components on shared ones, `NetworkConfig.relevance` for custom rules, `interestRadius` for distance.
- **Large entities**: an entity whose changes don't fit one snapshot datagram (a player's long inventory) still replicates: its spawn and large deltas go on the reliable control channel in fragments, in tick order with its snapshots, up to `NetworkSession.maxEntityStateBytes` (64 KiB) per entity.
- Reliable messages up to 1 MiB are fragmented automatically.

## Player identity

Players can join with a stable identity (`dev:<name>` for LAN and development, `steam:<id>` from `fledge_net_steam`, `hub:<account>` for a gateway), so the host recognises a returning player whatever transport or address they use:

```dart
NetworkConfig(
  identityProvider: DevIdentityProvider(savedName),     // client
  identityVerifier: const TrustingVerifier(),           // host
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,    // keep what they owned
);
```

With `holdForReturn`, a returning player gets their entities back (`NetPeerConnected.returned`). See [Security and identity](https://fledge-framework.dev/docs/networking/security-identity#player-identity) for hubs and mixed verifiers.

## Finding hosts on the LAN

So players on one network can pick a host from a list instead of typing its address, a host broadcasts a small beacon (your app id, the game port and a payload of your own, up to 512 bytes) about twice a second, and a browser lists the hosts it hears:

```dart
// Host, while accepting players over direct IP:
final advertiser = LanAdvertiser(
  appId: 'my-game',
  gamePort: 7777,
  payload: utf8.encode(jsonEncode({'name': 'Red Acre', 'players': 1})),
);
await advertiser.start();
advertiser.payload = utf8.encode(jsonEncode({'name': 'Red Acre', 'players': 2}));
await advertiser.stop(); // browsers drop it at once

// Player looking for a game:
final browser = LanBrowser(appId: 'my-game');
browser.onChanged.listen((hosts) {
  for (final h in hosts) print('${h.address} ${h.payloadText}');
});
await browser.start();
// join one: session.join(host.host, host.port)
await browser.stop();
```

Beacons go to UDP port `LanDiscovery.defaultPort` (47776), separate from the game port; hosts not heard for 5 s drop off. Socket errors never throw: the list stays empty. Beacons are unauthenticated, so show the payload, never trust it; joining goes through the normal handshake.

## Documentation

See the [networking docs](https://fledge-framework.dev/docs/networking/overview) for the co-op quickstart, [how replication works](https://fledge-framework.dev/docs/networking/replication), [configuration](https://fledge-framework.dev/docs/networking/configuration), and the [low-level API](https://fledge-framework.dev/docs/networking/low-level).

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
