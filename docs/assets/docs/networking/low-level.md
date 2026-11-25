# Low-Level API

Below the replication layer, `fledge_net` has a small datagram connection layer: `NetworkHost` and `NetworkClient` handle the connect handshake, authentication, pings and timeouts; packets carry a fixed header and a typed payload; transports move datagrams (UDP, an in-memory loopback network, an encryption wrapper). `ReliableChannel` adds reliable, ordered delivery on top.

`NetworkSession` is built from these pieces. Use them directly for a custom protocol, a lobby server, or tests of the connection layer itself. Everything the session adds (replication, identities, authority checks, encryption from config, Steam lobbies) is described on the other networking pages and isn't available at this level unless you build it.

## NetworkHost

```dart
final host = NetworkHost(transport: UdpTransport(), maxPeers: 4);
await host.start(7777);

host.onPeerConnected.listen((event) {
  print('Player ${event.peer.id} joined as ${event.peer.identity}');
});
host.onPeerDisconnected.listen((event) {
  print('Player ${event.peer.id} left: ${event.reason}');
});
host.onData.listen((event) {
  if (event.type == PacketType.custom) {
    final reader = PacketReader(event.data);
    print('peer ${event.peer.id} sent ${reader.readString()}');
  }
});

// Every frame:
host.update(); // times out silent peers, pings each peer for RTT
await host.broadcast(PacketType.custom, (PacketBuilder()..writeString('tick')).build());
```

Every send is one unreliable datagram: it may be lost, duplicated or reordered. For reliable, ordered delivery, layer a [`ReliableChannel`](#reliable-delivery) over the datagrams.

| Member | Description |
|---|---|
| `start(port)` | Bind the transport and start listening. |
| `stop()` | Send every peer a disconnect notice (redundantly) and close the transport. |
| `update()` | Call every frame: drops peers silent for `connectionTimeout`, pings each peer every `pingInterval`. |
| `sendTo(peerId, type, data)` | Send to one peer. |
| `broadcast(type, data)`, `broadcastExcept(excludeId, type, data)` | Send to every connected peer (but one). |
| `disconnectPeer(id, reason)` | Kick a peer. It's removed after the first notice copy. |
| `peers`, `peerCount`, `getPeer(id)` | Connected `Peer`s (`id`, `address`, `identity`, `state`, `rtt`, `timeSinceLastReceive`). |
| `isRunning` | Whether the host is started. |
| `roomCode` | A random 6-letter code generated on creation, for your own lobby or matchmaking use. |
| `onPeerConnected`, `onPeerDisconnected`, `onData`, `onProtocolMismatch` | Event streams. `onData` carries every packet type except the connection layer's own (connect, disconnect, ping, pong). |

Constructor options:

| Option | Default | Description |
|---|---|---|
| `transport` | required | The `Transport` to use. |
| `maxPeers` | 8 | Further connects are rejected with `Server full`. |
| `connectionTimeout` | 10 s | Silence after which a peer is dropped. |
| `authenticator` | `null` | `(clientId, credentials) async => bool`. |
| `sourceAuthenticator` | `null` | Like `authenticator` but also given the source `NetAddress` (for transports whose addresses are authenticated, such as Steam IDs). Used instead of `authenticator` when set. |
| `maxPendingConnects` | 64 | Most connects being authenticated at once. Connects from further addresses are ignored until a slot frees up (the client keeps retrying). |
| `pingInterval` | 1 s | How often `update()` pings each peer. |
| `clock` | `NetClock.system` | Clock for pings, RTT and peer timeouts. |
| `disconnectRedundancy`, `disconnectRedundancyInterval` | 3, 5 ms | Copies of each disconnect notice and the gap between them. |
| `replaceSameIdentity` | `false` | A client connecting with the identity of a connected peer replaces that peer. Anonymous clients never replace each other. `NetworkSession` turns it on. |

## NetworkClient

```dart
final client = NetworkClient(transport: UdpTransport());

client.onStateChange.listen((event) {
  print('Connection: ${event.state} ${event.reason ?? ''}');
});
client.onData.listen((event) {
  if (event.type == PacketType.custom) {
    print('host says ${PacketReader(event.data).readString()}');
  }
});

final ok = await client.connect('192.168.1.100', 7777);
if (!ok) print('Failed: ${client.lastStateReason}');

// Every frame:
client.update(); // pings the host, detects a silent host
await client.send(PacketType.custom, (PacketBuilder()..writeString('hello')).build());
```

| Member | Description |
|---|---|
| `connect(host, port, {clientId, credentials})` | Connect. Resolves to `true` when accepted, `false` when rejected or timed out. `clientId` is the player identity to present (default: anonymous). |
| `disconnect()` | Send `disconnectRedundancy` disconnect notices, then close the transport. |
| `update()` | Call every frame: pings every `pingInterval`, fails the connection after `connectionTimeout` of silence. |
| `send(type, data)` | Send to the host. Throws `StateError` when not connected. |
| `state`, `isConnected` | `ClientState.disconnected`, `connecting`, `connected` or `failed`. |
| `localPeerId` | The peer id the host assigned. |
| `rtt` | Smoothed round-trip time in ms. |
| `hostAddress` | The host's numeric address after resolution. |
| `lastStateReason` | Reason from the last state change (`Authentication failed`, `Connection timeout`, the host's disconnect reason). Never contains credentials. |
| `onStateChange`, `onData`, `onProtocolMismatch` | Event streams. |

Constructor options: `connectionTimeout` (10 s), `pingInterval` (1 s), `connectRetryInterval` (250 ms), `clock`, `hostResolver`, `disconnectRedundancy` (3), `disconnectRedundancyInterval` (5 ms).

`connect` accepts a numeric address or a host name such as `'localhost'`. Host names are resolved with `InternetAddress.lookup`, preferring an IPv4 result, because `UdpTransport` is IPv4-only. Pass `hostResolver: (host) async => '10.0.0.5'` to resolve names yourself. A transport that implements `AddressResolver` (such as `SteamTransport`) resolves the host itself instead, including when it is wrapped in an `EncryptedTransport`.

## Connection handshake

1. The client sends a `connect` packet with its identity and credentials, and re-sends it every `connectRetryInterval` until the host answers or `connectionTimeout` expires, so one lost packet doesn't stall the handshake. The retries run on their own timer; you don't need to call `client.update()` during `connect()`.
2. A full host answers `connectRejected` (`Server full`). With `replaceSameIdentity` (which `NetworkSession` turns on), a connection that will replace the same player's stale one doesn't count against `maxPeers`, so a player can rejoin a full host straight away.
3. With an authenticator, the host awaits it. Further `connect` packets from the same address are ignored meanwhile, so one client never becomes two peers. A rejection is answered with `Authentication failed`.
4. On acceptance the host creates a `Peer` and sends `connectAccepted` with the peer id. If the client keeps retrying because that reply was lost, the host sends the acceptance again (same peer id); this retry loop is what makes the acceptance reliable.
5. The client moves to `connected`. Duplicate acceptances are ignored.

`connect()`'s overall timeout and its retries run on real timers, not on the injected `NetClock`.

**Disconnecting.** `NetworkClient.disconnect()`, `NetworkHost.disconnectPeer()` and `stop()` send 3 identical `disconnect` datagrams 5 ms apart (`disconnectRedundancy`, `disconnectRedundancyInterval`), so a single lost datagram doesn't leave the other side waiting for its timeout. The host removes the peer after the first copy; the duplicates are ignored.

## Round-trip time

RTT is measured with ping/pong. Each side puts its own monotonic-clock timestamp in a `ping`, and the other side echoes it unchanged in the `pong`, so a sample is always `now − echoed` on the same clock and stays correct across the 32-bit wrap. `client.update()` pings the host and `host.update()` pings each peer every `pingInterval`. The results feed `NetworkClient.rtt` and `Peer.rtt`, exponential moving averages. Samples that are negative or above 60 s are discarded.

### NetClock

`NetClock` is the monotonic millisecond clock behind timestamps, RTT and timeouts. `NetClock.system` is backed by a `Stopwatch`, so wall-clock changes don't affect it. `ManualNetClock` only moves when you call `advance(duration)` or set `nowMs`, for deterministic tests. Wire timestamps are 32-bit and wrap about every 49.7 days; compute differences with `NetClock.elapsed32(now32, then32)`. Timestamps are only meaningful to the machine that wrote them: clocks on different machines are never compared.

## Packets

Every packet starts with a 20-byte header:

| Field | Size | Description |
|---|---|---|
| Magic | 4 bytes | `0x464C4547` ("FLEG") |
| Version | 1 byte | Protocol version (`PacketHeader.version`, currently `4`) |
| Type | 1 byte | `PacketType` |
| Sequence | 2 bytes | Packet sequence number |
| Ack | 2 bytes | Last sequence received from the other side |
| AckBits | 4 bytes | Bitmap of the 32 sequences before it |
| Timestamp | 4 bytes | Sender's `NetClock` (ms, unsigned 32-bit, wraps) |
| Reserved | 2 bytes | Reserved |

### Packet types

| `PacketType` | Used for |
|---|---|
| `connect`, `connectAccepted`, `connectRejected`, `disconnect` | The handshake and disconnect notices |
| `ping`, `pong` | RTT |
| `stateUpdate` | Replication: snapshot chunks |
| `input` | Replication: redundant per-tick inputs and actions |
| `replication` | Replication: the reliable channels |
| `tickSync` | Replication: tick synchronisation |
| `custom` | Free for your own protocol |

A custom protocol over `NetworkHost`/`NetworkClient` should use `custom` (and put its own message kind in the payload), since the replication types carry the session's formats.

### Size limit

Datagrams are capped at `Packet.maxDatagramBytes` (1200 bytes), which keeps them under typical path MTUs so the IP layer never fragments them. After the 20-byte header and 28 bytes reserved for `EncryptedTransport` (reserved even when encryption is off), the largest payload is `Packet.maxPayloadBytes`, **1152 bytes**. `NetworkClient.send`, `NetworkHost.sendTo`, `broadcast` and `broadcastExcept` throw `ArgumentError` for larger payloads (a broadcast sends nothing in that case). These raw sends don't fragment: split large data yourself, or send it through a `ReliableChannel`, which does. The replication layer stays under the limit on its own.

### Protocol version mismatch

`PacketHeader.deserialize` returns `null` for a packet whose version doesn't match, so peers on different protocol versions can't exchange traffic. Both sides report the mismatch instead of timing out:

- **Host**: emits a `ProtocolMismatchEvent` (`source`, `localVersion`, `remoteVersion`, `remoteIsNewer`) on `onProtocolMismatch`. If the packet was a `connect`, it also replies with `connectRejected` and a reason such as `Protocol version mismatch: host v4, client v3`. It never replies to other traffic.
- **Client**: when bytes from the host carry the magic number but another version, it emits a `ProtocolMismatchEvent` and fails with `Protocol version mismatch: local v4, server v5`. `connect()` returns `false` right away.

In a session these surface as the `NetProtocolMismatch` event and `session.lastError`.

### Writing and reading payloads

`PacketBuilder` and `PacketReader` provide typed, little-endian serialization:

```dart
final builder = PacketBuilder()
  ..writeFloat32(12.5)
  ..writeFloat32(-3)
  ..writeString('Zoë 🦆')
  ..writeBool(true)
  ..writeVarUint(300);
final bytes = builder.build();

final reader = PacketReader(bytes);
final x = reader.readFloat32();
final y = reader.readFloat32();
final name = reader.readString();
final alive = reader.readBool();
final count = reader.readVarUint();
```

- Fixed-size: `writeByte`, `writeBool`, `writeInt16`/`writeUint16`, `writeInt32`/`writeUint32`, `writeInt64`, `writeFloat32`, `writeFloat64`, with matching `read*` methods.
- `writeString` writes UTF-8 with a 16-bit byte-length prefix, so any Unicode text round-trips. `writeBytes` uses the same prefix. Both are limited to 65535 bytes and throw `ArgumentError` beyond that; `readString` throws `FormatException` on invalid UTF-8.
- Compact: `writeVarUint`/`writeVarInt` (LEB128 varints, the signed one zigzag-encoded) and `writeVarBytes` (a varint length, no 64 KiB limit). `writeRawBytes` writes bytes with no prefix.
- `reader.hasMore`, `reader.skip(n)`; reading past the end throws.

## Reliable delivery

`ReliableChannel` gives you reliable, ordered, de-duplicated messages over unreliable datagrams. Use one per connection: its sending half numbers messages and resends unacknowledged ones, and its receiving half releases them strictly in order. Acks are cumulative ("everything up to N"), so a lost ack is repaired by the next packet.

```dart
Future<void> pumpReliable(
  ReliableChannel channel,
  NetworkClient client,
  NetClock clock,
) async {
  // Every tick: new messages plus resends of unacked ones older than the timeout.
  for (final packet in channel.takePackets(
    nowMs: clock.nowMs,
    resendAfterMs: 200,
    ack: channel.receivedAck, // piggyback our cumulative ack
  )) {
    await client.send(PacketType.custom, packet);
  }
}

void onReliablePacket(ReliableChannel channel, Uint8List payload) {
  channel.onAck(channel.receivePacket(payload));
  for (final message in channel.drain()) {
    // In order, exactly once.
    print('got ${message.length} bytes');
  }
}
```

Queue messages with `channel.enqueue(bytes)`. The channel never gives up on a message, and it is bounded:

- **Message size**: up to `ReliableChannel.maxMessageBytes` (1 MiB). A message larger than one packet's worth (`maxFragmentBytes`, 1133 bytes) is split into fragments, each sent, acknowledged and resent like a message of its own, and joined back together on the receiving side. `enqueue` throws `ArgumentError` above 1 MiB.
- **Send side**: at most `maxUnacked` fragments (default 16384) wait for an ack. Once `isFull`, `enqueue` throws `StateError`; `canEnqueue(length)` checks first. The ordered stream can't be completed after that, so drop the connection. The replication layer disconnects such a peer (`Reliable channel overflow`) or ends the client session.
- **Receive side**: at most `maxReceiveWindow` out-of-order fragments (default 1024) are buffered; one further ahead is dropped and arrives again with the sender's resend.
- `takePackets` produces at most `maxPackets` packets (default 32) and about `maxBytes` bytes per call; the rest go on the next call. Each packet fits `Packet.maxPayloadBytes`.

Choose `resendAfterMs` from the measured RTT (the replication layer uses about 1.5 RTT plus two ticks, between 50 ms and 2 s).

## Transports

A `Transport` moves datagrams between `NetAddress`es. `NetworkHost`, `NetworkClient` and `NetworkSession` take any transport:

| Transport | Package | Use |
|---|---|---|
| `UdpTransport` | fledge_net | Real networks (IPv4, `dart:io`; not on the web) |
| `LoopbackTransport` | fledge_net | In-memory network for tests (`LoopbackNetwork.createTransport`) |
| `EncryptedTransport` | fledge_net | Wraps another transport with AES-256-GCM (see [Encryption](/docs/networking/security-identity#encryption)) |
| `SteamTransport` | fledge_net_steam | Steam Networking Messages (see [Steam](/docs/networking/steam)) |

**Delivery contract.** Each received datagram is delivered exactly once. If anything listens to `transport.onReceive` (as `NetworkHost` and `NetworkClient` do), packets go to the stream only. Otherwise they go to a bounded buffer (`maxBufferedPackets`, default 1024, oldest dropped first) that `transport.receive()` drains. Every built-in transport follows it.

- **`NetAddress(host, port)`** is a value type (equality and hash by host and port). For UDP the host is a numeric IPv4 address; other transports use their own form (`steam:<SteamID64>`, port 0).
- **`AddressResolver`**: a transport whose addresses aren't IP addresses or host names implements `Future<NetAddress> resolve(String host, int port)`, and `NetworkClient.connect` asks it instead of DNS.
- **`TransportStats`** (`UdpTransport.stats`, `SteamTransport.stats`): `bytesSent`, `bytesReceived`, `packetsSent`, `packetsReceived`, `packetsLost`, and `reset()`.

To write your own transport, extend `Transport` and implement `state`, `localAddress`, `bind`, `close`, `send`, `receive`, `onReceive` and `onStateChange`, following the delivery contract.

### UdpTransport

`UdpTransport({bindAddress, maxBufferedPackets = 1024, maxQueuedSends = 1024})` binds an IPv4 `RawDatagramSocket` (all interfaces by default; pass `InternetAddress.loopbackIPv4` for local-only). Destination hosts must be numeric IPv4 addresses (`NetworkClient` resolves host names first).

- **Send queue**: when the OS send buffer is full (the socket would block, which Windows reports under bursts), datagrams are queued and sent when the socket becomes writable, instead of being silently dropped. The queue holds `maxQueuedSends` datagrams; beyond that the oldest are dropped and counted in `stats.packetsLost`. Only queue overflow is counted there: UDP itself may still drop, duplicate or reorder datagrams anywhere on the way, with no error, which is why the layers above ack and resend.
- Each read event drains every waiting datagram.
- `bufferOverflowCount` counts received datagrams dropped because nobody drained the poll buffer.

### LoopbackNetwork

`LoopbackNetwork` is an in-memory datagram network and the recommended way to test netcode. Create one network, give each endpoint its own transport with `createTransport()`, and use them exactly like `UdpTransport`:

```dart
final net = LoopbackNetwork(
  latency: const Duration(milliseconds: 40), // one-way
  jitter: const Duration(milliseconds: 10), // extra random delay (reorders)
  packetLoss: 0.05, // 5% dropped
  duplication: 0.01, // 1% delivered twice
  random: math.Random(42), // same seed, same run
);

final host = NetworkHost(transport: net.createTransport());
await host.start(7777);

final client = NetworkClient(transport: net.createTransport());
await client.connect('127.0.0.1', 7777);
```

- `net.filter = (datagram) => ...` drops chosen datagrams deterministically (return `false` to drop), e.g. "drop the first `connect`". It runs before random loss.
- `createTransport(host: '10.0.0.2')` simulates distinct machines; by default every transport is on `127.0.0.1`, told apart by port.
- `transport.inject(source, bytes)` feeds a hand-crafted packet.
- `net.stats` counts `sent`, `delivered`, `dropped`, `duplicated` and `undeliverable` datagrams; `net.inFlight` is how many are scheduled.
- `latency`, `jitter`, `packetLoss` and `duplication` can be changed mid-test.

**Manual mode** gives exact, repeatable timing. Pass a `ManualNetClock` to the network and to the host and client. Nothing is delivered until you call `await net.advance(duration)` or `net.flush()`, and the clock moves to each delivery time:

```dart
final clock = ManualNetClock();
final net = LoopbackNetwork(latency: const Duration(milliseconds: 50), clock: clock);
final host = NetworkHost(transport: net.createTransport(), clock: clock);
final client = NetworkClient(transport: net.createTransport(), clock: clock);
await host.start(7777);
final connecting = client.connect('127.0.0.1', 7777);
await net.advance(const Duration(milliseconds: 100));
print(await connecting); // true

for (var i = 0; i < 100; i++) {
  host.update();
  client.update();
  await net.advance(const Duration(milliseconds: 10));
}
print(client.rtt); // 100, exactly
```

Host peer timeouts and pings follow the injected clock, so advancing a `ManualNetClock` past `connectionTimeout` times out a silent peer without real waiting. `connect()`'s overall timeout and its retries still run on real timers. `clearInFlight()` discards everything scheduled.

To run whole sessions this way, pass the clock and `net.createTransport` to `NetworkPlugin`, as in the [quickstart's test setup](/docs/networking/overview#9-test-it-in-one-process).
