# Security and Identity

Who may join a session, who they are, whether anyone can read or tamper with the traffic, and what a joined client is allowed to do. All of it is configured on `NetworkConfig` and enforced by the host.

The host is the authority. Treat every client as possibly modified: the checks on this page run on the host and don't rely on anything a client says about itself, except identities you choose to trust as claimed (`TrustingVerifier`, or no verifier).

## Authentication

A host can require a password, a custom check, or both:

<!-- snippet-setup
class Hub {
  Future<({String id, Uint8List token})> currentSession() async =>
      (id: 'hub:alice', token: Uint8List(0));
  Future<bool> verify(String id, Uint8List token) async => true;
  bool isBanned(String id) => false;
}
final hub = Hub();
const savedName = 'alice';
-->

```dart
final config = NetworkConfig(
  serverPassword: 'hunter2',
  authenticator: (clientId, credentials) async => !hub.isBanned(clientId),
);
```

- `serverPassword`: the host compares the client's credentials with the password's UTF-8 bytes in constant time. Clients with the same config send it automatically; `session.join(..., credentials: bytes)` sends something else instead.
- `authenticator`: `(clientId, credentials) async => bool`. `clientId` is the player's identity (or `FledgeClient` for an anonymous client) and `credentials` is the password slot. If a password is also set, both must accept.
- A rejected client's `join` resolves to `false` with `lastError` `Authentication failed`. A full host answers `Server full`.

The host checks a connect in this order: the credentials framing, the password, the identity (well-formed, not the host's own identity, then the `identityVerifier`), then the `authenticator`. Connects from one address are authenticated one at a time, and at most 64 connects are checked at once, so a flood of connects can't pile up authenticator calls.

Without encryption the password crosses the network in the clear. On anything but a trusted LAN, turn on [encryption](#encryption) too.

## Player identity

A player identity is an opaque, stable string the host uses to recognise a returning player, whatever transport or address they connect from. By convention it starts with the scheme that issued it, so identities from different sources never collide:

| Scheme | Issued by | Checked by |
|---|---|---|
| `dev:<name>` | `DevIdentityProvider`, for development and LAN play over direct IP | `TrustingVerifier` (no proof) |
| `steam:<SteamID64>` | `SteamIdentityProvider` from [fledge_net_steam](/docs/networking/steam) | `SteamIdentityVerifier` (Steam authenticates the sender) |
| `hub:<account>` | `TokenIdentityProvider`, with a token from your sign-in service | `TokenVerifier`, which asks the service |

Games compare identities; they never parse them. The client says who it is with an `IdentityProvider`, and the host checks it with an `IdentityVerifier`:

```dart
// Development / LAN: a name kept per install, trusted as claimed.
final lanConfig = NetworkConfig(
  identityProvider: DevIdentityProvider(savedName),
  identityVerifier: const TrustingVerifier(),
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,
);

// A hub: the client presents a token from sign-in; the host asks the hub.
final hubConfig = NetworkConfig(
  identityProvider: TokenIdentityProvider(() => hub.currentSession()),
  identityVerifier: TokenVerifier((id, token) => hub.verify(id, token)),
);

// Several at once, by scheme (the part before the first ':').
final mixedConfig = NetworkConfig(
  identityVerifier: SchemeVerifier({
    'dev': const TrustingVerifier(),
    'hub': TokenVerifier((id, token) => hub.verify(id, token)),
  }),
);
```

- `DevIdentityProvider.random()` makes a fresh random name. Save it on first launch and pass it to `DevIdentityProvider(name)` afterwards, so the player keeps the same identity.
- Without a provider a client joins anonymously. Without a verifier the host accepts any well-formed identity as claimed, which is fine on a LAN and not on the internet.
- The identity travels in the connect handshake; its proof travels with the password in the credentials. A verifier rejection is reported like a wrong password (`Authentication failed`). A provider that throws makes `join` fail with `Could not identify the player`.
- Nobody can join with the host's own identity.
- `session.localIdentity` is this player's identity (the host's too). On the host, `identityOf(peerId)` and `peerFor(identity)` map between peers and identities, and `NetPeerConnected` / `NetPeerDisconnected` carry it.
- With `OwnedEntityPolicy.holdForReturn`, a returning player gets their entities back (`NetPeerConnected.returned` lists them). See [Disconnects](/docs/networking/replication#disconnects).
- A client joining with the identity of a player who is still connected (after a crash, or from a new address) **replaces** the old connection instead of waiting for it to time out. With a trusting verifier this means anyone on the network can disconnect a player by claiming their identity, which is one more reason to use a real verifier on untrusted networks.
- `ClientIdentity.validate` rules: non-empty, at most 128 bytes of UTF-8, no control characters. Write your own provider or verifier by implementing `IdentityProvider.identify()` or `IdentityVerifier.verify(identity, proof, {source})`. `source` is the address the connect came from, which some transports authenticate (a Steam ID under `SteamTransport`).

## Encryption

Set `enableEncryption` and a pre-shared 32-byte `encryptionKey`, and the session wraps its transport in `EncryptedTransport`:

```dart
final key = EncryptedTransport.generateKey(); // 32 random bytes; distribute it yourself

final config = NetworkConfig(
  enableEncryption: true,
  encryptionKey: key,
);
```

`EncryptedTransport` uses AES-256-GCM (via `package:pointycastle`). Each packet looks like this on the wire:

```
[ 6 bytes  ] plaintext header (magic + version + type), kept readable for routing
[ 12 bytes ] random GCM nonce
[ N bytes  ] ciphertext (sequence, ack, ackBits, timestamp, payload)
[ 16 bytes ] GCM authentication tag
```

- The 6-byte header is bound into the authentication tag as additional authenticated data, so tampering with it is detected. Packets that fail verification (wrong key, flipped bit, truncated tag) are silently dropped. A client with the wrong key therefore never gets an answer and its `join` times out.
- Starting a session with encryption enabled but no key throws, and a key that isn't 32 bytes throws `ArgumentError`. There is no unencrypted fallback. The key is never logged.
- The 28 bytes of overhead are reserved in every packet even when encryption is off, so payload limits don't change when you turn it on.

> **Key distribution:** the key is pre-shared. Host and clients must be configured with the same 32 bytes before any encrypted traffic flows, and getting it there is up to your game (a config file, a login response, a code the host reads out). There is no key exchange in the protocol.

Over Steam, `SteamTransport` already relies on Steam's authenticated, relayed connections, and encryption currently can't be combined with it when joining (see [Steam](/docs/networking/steam#limitations)).

To encrypt a transport you drive yourself, wrap it directly: `EncryptedTransport(inner: UdpTransport(), sharedKey: key)`. Setting `sharedKey` to `null` on a raw `EncryptedTransport` passes traffic through unencrypted; `NetworkSession` never does that.

## Authority

Every replicated entity has a `NetworkIdentity` recording its network id and owner:

<!-- snippet-setup
final world = World();
final entity = world.spawn().entity;
-->

```dart
final id = world.get<NetworkIdentity>(entity)!;
id.netId;          // network id, the same on every machine
id.ownerId;        // 0 = host-owned, >0 = a client's peer id
id.localPeerId;    // this instance's peer id (0 on the host)
id.hasAuthority;   // this instance owns it: ownerId == localPeerId
id.isOwnedBy(2);   // ownerId == 2
id.ownerId = 2;    // on the host: hand the entity to peer 2 (replicated)
```

`hasAuthority` follows ownership changes. On the host it's `true` only for host-owned entities: the host still simulates every entity, but a client-owned entity is driven by that client's inputs. Ownership starts as `Replicated(owner: ...)` and afterwards `NetworkIdentity.ownerId` on the host is the source of truth.

The host enforces it:

- **Inputs** and **targeted RPCs** are accepted only from the entity's owner (`ownerId == peerId`). Anything else is dropped, counted in `NetworkStats` (`rejectedInputs`, `rejectedRpcs`), and reported with a `NetRejected` event naming the peer, the kind, the network id and a fixed reason. Payload data never appears in it.
- **Actions** out of sequence, or targeting an entity the sender doesn't own, are rejected the same way (`rejectedActions`), and the sender gets a rejected `NetActionResolved` when the host can tell it which action that was.
- **Clients can't spawn, despawn, re-parent or change ownership.** Clients may only send RPCs on the reliable channel; any other message is dropped and counted in `rejectedMessages`.
- Ownership is tracked on the host. A client submits inputs only for entities that the session's own owner map (filled from the host's messages) says it owns, so editing a client's local `NetworkIdentity` can't spoof control.

If you build your own protocol on [`NetworkHost`](/docs/networking/low-level), these checks don't exist there: check `ownerId == peer.id` yourself.

## Testing authority

The test-only library `package:fledge_net/testing.dart` (not exported from `fledge_net.dart`) lets a client session act like a modified client, so you can assert that the host turns it away:

```dart
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/testing.dart';

class Move {
  final double dx, dy;
  const Move(this.dx, this.dy);
}

final moveCodec = NetCodec<Move>.of(
  encode: (m, out) => out..writeFloat32(m.dx)..writeFloat32(m.dy),
  decode: (r) => Move(r.readFloat32(), r.readFloat32()),
);

/// [attacker] is a joined client session; [victimNetId] an entity it doesn't own.
Future<void> claimSomeoneElsesEntity(
  NetworkSession attacker,
  int victimNetId,
  int hostTick,
) async {
  await attacker.sendRawInput(
    netId: victimNetId,
    firstTick: hostTick,
    inputs: List.filled(10, encodeWithCodec(moveCodec, const Move(1, 0))),
  );
  // Then, on the host: stats.rejectedInputs > 0 and a NetRejected event.
}
```

- `sendRawInput(netId:, firstTick:, inputs:)` sends inputs for any entity. `encodeWithCodec(codec, value)` encodes one value; `encodeRawInputPacket(streams: [RawInputStream(...)])` with `sendRawInputPacket` builds a whole packet.
- `sendRawRpc(value, targetNetId:)` names any RPC target.
- `sendRawAction(value, seq:, tick:, targetNetId:)` sends an action with a chosen sequence number (replaying an old one, skipping ahead).

Run these against a host in the same process with a [`LoopbackNetwork`](/docs/networking/overview#9-test-it-in-one-process).
