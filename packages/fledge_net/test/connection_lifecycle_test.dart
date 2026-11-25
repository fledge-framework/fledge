import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// A loopback transport that resolves `fake:` hosts itself, standing in for
/// a non-IP transport such as Steam.
class _ResolvingTransport extends Transport implements AddressResolver {
  final LoopbackTransport inner;
  final NetAddress target;
  _ResolvingTransport(this.inner, this.target);

  @override
  Future<NetAddress> resolve(String host, int port) async {
    if (!host.startsWith('fake:')) throw ArgumentError(host);
    return target;
  }

  @override
  ConnectionState get state => inner.state;
  @override
  NetAddress? get localAddress => inner.localAddress;
  @override
  Future<void> bind(int port) => inner.bind(port);
  @override
  Future<void> close() => inner.close();
  @override
  Future<void> send(NetAddress address, Uint8List data) =>
      inner.send(address, data);
  @override
  List<ReceivedPacket> receive() => inner.receive();
  @override
  Stream<ReceivedPacket> get onReceive => inner.onReceive;
  @override
  Stream<ConnectionState> get onStateChange => inner.onStateChange;
}

void main() {
  test('a host-initiated disconnect closes the client transport', () async {
    final net = LoopbackNetwork();
    final host = NetworkHost(transport: net.createTransport());
    final clientTransport = net.createTransport();
    final client = NetworkClient(transport: clientTransport);
    await host.start(7777);
    expect(await client.connect('127.0.0.1', 7777), isTrue);

    await host.disconnectPeer(client.localPeerId!, 'Kicked');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(client.isConnected, isFalse);
    expect(clientTransport.state, ConnectionState.disconnected);
    await client.disconnect(); // still safe
    await host.stop();
  });

  test('a player can rejoin a full host under the same identity', () async {
    final net = LoopbackNetwork();
    // NetworkSession hosts with replaceSameIdentity on.
    final host = NetworkHost(
      transport: net.createTransport(),
      maxPeers: 1,
      replaceSameIdentity: true,
    );
    await host.start(7777);

    final first = NetworkClient(transport: net.createTransport());
    expect(await first.connect('127.0.0.1', 7777, clientId: 'alice'), isTrue);

    // The first client "crashes" without disconnecting; alice comes back
    // from a new address while her stale peer still holds the only slot.
    final second = NetworkClient(transport: net.createTransport());
    expect(await second.connect('127.0.0.1', 7777, clientId: 'alice'), isTrue);
    expect(host.peerCount, 1);

    // Someone else is still turned away.
    final bob = NetworkClient(
      transport: net.createTransport(),
      connectionTimeout: const Duration(milliseconds: 500),
    );
    expect(await bob.connect('127.0.0.1', 7777, clientId: 'bob'), isFalse);

    await second.disconnect();
    await host.stop();
  });

  test(
    'an encrypted client still resolves through its inner transport',
    () async {
      final net = LoopbackNetwork();
      final key = EncryptedTransport.generateKey();
      final host = NetworkHost(
        transport: EncryptedTransport(
          inner: net.createTransport(),
          sharedKey: key,
        ),
      );
      await host.start(7777);

      final client = NetworkClient(
        transport: EncryptedTransport(
          inner: _ResolvingTransport(
            net.createTransport(),
            const NetAddress('127.0.0.1', 7777),
          ),
          sharedKey: key,
        ),
      );
      expect(await client.connect('fake:host', 0), isTrue);

      await client.disconnect();
      await host.stop();
    },
  );
}
