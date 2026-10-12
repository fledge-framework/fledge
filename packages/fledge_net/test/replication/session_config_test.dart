// NetworkConfig wiring: password/authenticator, encryption, tick rate and
// schema checks, FixedTimestep validation.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  group('password', () {
    test('matching password joins and replicates', () async {
      final bed = NetTestbed(
        config: () => NetworkConfig(serverPassword: 'hunter2'),
      );
      await bed.startHost();
      final client = await bed.addClient();
      await bed.frames(10);
      expect(client.world.getResource<NetworkEntityRegistry>()!.count, 2);
      await bed.dispose();
    });

    test('wrong password is rejected', () async {
      var hostSide = true;
      final bed = NetTestbed(
        config: () {
          final c = NetworkConfig(serverPassword: hostSide ? 'right' : 'wrong');
          hostSide = false;
          return c;
        },
      );
      await bed.startHost();
      final client = bed.createApp(isHost: false);
      bed.clients.add(client);
      final ok = await bed.pumpUntil(
        NetTestbed.session(client).join('127.0.0.1', 7777),
      );
      expect(ok, isFalse);
      final session = NetTestbed.session(client);
      expect(session.lastError, 'Authentication failed');
      expect(session.isActive, isFalse);
      await bed.dispose();
    });

    test('custom authenticator and password must both accept', () async {
      final seen = <String>[];
      final bed = NetTestbed(
        config: () => NetworkConfig(
          serverPassword: 'pw',
          authenticator: (id, creds) async {
            seen.add(id);
            return false;
          },
        ),
      );
      await bed.startHost();
      final client = bed.createApp(isHost: false);
      bed.clients.add(client);
      final ok = await bed.pumpUntil(
        NetTestbed.session(client).join('127.0.0.1', 7777),
      );
      expect(ok, isFalse);
      expect(seen, ['FledgeClient']);
      await bed.dispose();
    });
  });

  group('encryption', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
    final otherKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

    test(
      'shared key: session works end to end, wire bytes are encrypted',
      () async {
        final bed = NetTestbed(
          config: () =>
              NetworkConfig(enableEncryption: true, encryptionKey: key),
        );
        final seen = <Uint8List>[];
        bed.net.filter = (d) {
          seen.add(d.data);
          return true;
        };
        await bed.startHost();
        final client = await bed.addClient();
        await bed.frames(20);
        expect(client.world.getResource<NetworkEntityRegistry>()!.count, 2);
        // Every datagram is header(6) + nonce(12) + ciphertext + tag(16).
        expect(
          seen.every(
            (d) => d.length >= EncryptedTransport.plaintextHeaderBytes + 28,
          ),
          isTrue,
        );
        await bed.dispose();
      },
    );

    test('different key cannot connect', () async {
      var hostSide = true;
      final bed = NetTestbed(
        config: () {
          final c = NetworkConfig(
            enableEncryption: true,
            encryptionKey: hostSide ? key : otherKey,
            connectionTimeout: const Duration(milliseconds: 300),
          );
          hostSide = false;
          return c;
        },
      );
      await bed.startHost();
      final client = bed.createApp(isHost: false);
      bed.clients.add(client);
      final ok = await bed.pumpUntil(
        NetTestbed.session(client).join('127.0.0.1', 7777),
      );
      expect(ok, isFalse);
      expect(NetTestbed.session(client).lastError, 'Connection timeout');
      await bed.dispose();
    });

    test(
      'enableEncryption without a key refuses to start (no fallback)',
      () async {
        final bed = NetTestbed(
          config: () => NetworkConfig(enableEncryption: true),
        );
        final app = bed.createApp(isHost: true);
        expect(
          () => NetTestbed.session(app).host(port: 7777),
          throwsA(isA<StateError>()),
        );
        expect(NetTestbed.session(app).isActive, isFalse);
      },
    );
  });

  test('FixedTimestep must match tickRate', () async {
    final bed = NetTestbed();
    final app = bed.createApp(isHost: true)
      ..insertResource(
        FixedTimestep(stepDuration: const Duration(milliseconds: 10)),
      );
    await expectLater(
      NetTestbed.session(app).host(port: 7777),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('tickRate'),
        ),
      ),
    );
  });

  test('schema mismatch fails the client with a clear reason', () async {
    var hostSide = true;
    final bed = NetTestbed(
      registry: () {
        final r = buildRegistry(predict: hostSide);
        hostSide = false;
        return r;
      },
    );
    await bed.startHost();
    final client = bed.createApp(isHost: false);
    bed.clients.add(client);
    final session = NetTestbed.session(client);
    expect(await bed.pumpUntil(session.join('127.0.0.1', 7777)), isTrue);
    await bed.runUntil(() => !session.isActive, what: 'client failure');
    expect(session.lastError, contains('schema mismatch'));
    await bed.frames(2);
    expect(
      NetTestbed.log(client).disconnected.single.reason,
      contains('schema'),
    );
    await bed.dispose();
  });

  test('tick rate mismatch fails the client', () async {
    final bed = NetTestbed(tickRate: 50);
    await bed.startHost();
    // A 25 Hz client on the same network.
    final client = App()
      ..insertResource(NetworkConfig(tickRate: 25).fixedTimestep())
      ..insertResource(WallTime()..delta = 0.02)
      ..addPlugin(
        NetworkPlugin(
          config: NetworkConfig(tickRate: 25),
          replication: buildRegistry(),
          clock: bed.clock,
          transportFactory: bed.net.createTransport,
        ),
      );
    bed.clients.add(client);
    final session = NetTestbed.session(client);
    expect(await bed.pumpUntil(session.join('127.0.0.1', 7777)), isTrue);
    await bed.runUntil(() => !session.isActive, what: 'client failure');
    expect(session.lastError, 'Tick rate mismatch: local 25 Hz, host 50 Hz');
    await bed.dispose();
  });
}
