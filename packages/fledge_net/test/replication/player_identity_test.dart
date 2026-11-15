// Player identities: presented when joining, checked by the host, and used
// to hand a returning player back what they left (holdForReturn).
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  group('ClientIdentity', () {
    test('ids must be short, non-empty and printable', () {
      expect(ClientIdentity.validate('dev:alice'), isNull);
      expect(ClientIdentity.validate(''), isNotNull);
      expect(ClientIdentity.validate('a' * 200), isNotNull);
      expect(ClientIdentity.validate('dev:\nalice'), isNotNull);
      expect(() => ClientIdentity(''), throwsArgumentError);
    });

    test('a random dev identity is stable once made, and distinct', () async {
      final a = DevIdentityProvider.random();
      final b = DevIdentityProvider.random();
      expect((await a.identify()).id, (await a.identify()).id);
      expect((await a.identify()).id, isNot((await b.identify()).id));
      expect((await a.identify()).id, startsWith('dev:'));
    });

    test('a scheme verifier routes by the part before the colon', () async {
      final verifier = SchemeVerifier({
        'dev': const TrustingVerifier(),
        'hub': TokenVerifier((id, token) async => utf8.decode(token) == 'ok'),
      });
      expect(await verifier.verify('dev:a', Uint8List(0)), isTrue);
      expect(
        await verifier.verify('hub:a', Uint8List.fromList(utf8.encode('ok'))),
        isTrue,
      );
      expect(await verifier.verify('hub:a', Uint8List(0)), isFalse);
      expect(await verifier.verify('steam:1', Uint8List(0)), isFalse);
      expect(await verifier.verify('nocolon', Uint8List(0)), isFalse);
    });
  });

  group('joining with an identity', () {
    late NetTestbed bed;
    tearDown(() => bed.dispose());

    test(
      'the host learns who joined; anonymous clients stay anonymous',
      () async {
        bed = NetTestbed();
        final host = await bed.startHost();
        final alice = await bed.addClient(
          identity: DevIdentityProvider('alice'),
        );
        final anon = await bed.addClient();
        await bed.frames(5);

        final session = NetTestbed.session(host);
        final aliceId = NetTestbed.session(alice).localPeerId!;
        final anonId = NetTestbed.session(anon).localPeerId!;
        expect(session.identityOf(aliceId), 'dev:alice');
        expect(session.identityOf(anonId), isNull);
        expect(session.peerFor('dev:alice'), aliceId);
        expect(NetTestbed.session(alice).localIdentity, 'dev:alice');
        final joined = NetTestbed.log(host).peerConnected;
        expect(joined.map((e) => e.identity), containsAll(['dev:alice', '']));
      },
    );

    test('a verifier turns away identities it cannot vouch for', () async {
      bed = NetTestbed(
        config: () => NetworkConfig(
          identityVerifier: TokenVerifier(
            (id, token) async => utf8.decode(token) == 'secret-for-$id',
          ),
        ),
      );
      await bed.startHost();
      final good = TokenIdentityProvider(
        () async => (
          id: 'hub:bob',
          token: Uint8List.fromList(utf8.encode('secret-for-hub:bob')),
        ),
      );
      await bed.addClient(identity: good);
      final bad = TokenIdentityProvider(
        () async => (
          id: 'hub:mallory',
          token: Uint8List.fromList(utf8.encode('guess')),
        ),
      );
      await expectLater(
        bed.addClient(identity: bad),
        throwsA(isA<StateError>()),
      );
    });

    test('nobody joins as the host', () async {
      bed = NetTestbed(
        config: () => NetworkConfig(
          identityProvider: DevIdentityProvider('host'),
          identityVerifier: const TrustingVerifier(),
        ),
      );
      await bed.startHost();
      await expectLater(
        bed.addClient(identity: DevIdentityProvider('host')),
        throwsA(isA<StateError>()),
      );
      await bed.addClient(identity: DevIdentityProvider('friend'));
    });

    test('a password and an identity are checked together', () async {
      bed = NetTestbed(config: () => NetworkConfig(serverPassword: 'pw'));
      final host = await bed.startHost();
      final alice = await bed.addClient(identity: DevIdentityProvider('alice'));
      await bed.frames(3);
      final id = NetTestbed.session(alice).localPeerId!;
      expect(NetTestbed.session(host).identityOf(id), 'dev:alice');
    });
  });

  group('holdForReturn', () {
    late NetTestbed bed;
    tearDown(() => bed.dispose());

    test('a returning player gets back what they owned', () async {
      bed = NetTestbed(
        config: () =>
            NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
      );
      final host = await bed.startHost();
      final first = await bed.addClient(identity: DevIdentityProvider('ann'));
      await bed.frames(10);
      final scene = host.world.getResource<HostScene>()!;
      final firstId = NetTestbed.session(first).localPeerId!;
      final avatar = scene.avatars[firstId]!;
      final netId = netIdOf(host, avatar);

      await NetTestbed.session(first).close();
      await bed.frames(20);
      final left = NetTestbed.log(host).peerDisconnected.single;
      expect(left.identity, 'dev:ann');
      expect(left.policy, OwnedEntityPolicy.holdForReturn);
      expect(host.world.get<NetworkIdentity>(avatar)!.ownerId, 0);

      // Back again (the scene mustn't spawn a second avatar).
      scene.spawnAvatars = false;
      final again = await bed.addClient(identity: DevIdentityProvider('ann'));
      await bed.frames(10);
      final againId = NetTestbed.session(again).localPeerId!;
      expect(againId, isNot(firstId));
      expect(host.world.get<NetworkIdentity>(avatar)!.ownerId, againId);
      final rejoined = NetTestbed.log(host).peerConnected.last;
      expect(rejoined.identity, 'dev:ann');
      expect(rejoined.returned, [netId]);
    });

    test('someone else joining does not get them', () async {
      bed = NetTestbed(
        config: () =>
            NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
      );
      final host = await bed.startHost();
      final ann = await bed.addClient(identity: DevIdentityProvider('ann'));
      await bed.frames(10);
      final scene = host.world.getResource<HostScene>()!;
      final avatar = scene.avatars[NetTestbed.session(ann).localPeerId!]!;
      await NetTestbed.session(ann).close();
      await bed.frames(20);
      scene.spawnAvatars = false;
      await bed.addClient(identity: DevIdentityProvider('ben'));
      await bed.frames(10);
      expect(host.world.get<NetworkIdentity>(avatar)!.ownerId, 0);
      expect(NetTestbed.log(host).peerConnected.last.returned, isEmpty);
    });
  });

  test('the same identity joining again replaces its old connection', () async {
    final bed = NetTestbed();
    final host = await bed.startHost();
    final first = await bed.addClient(identity: DevIdentityProvider('cat'));
    await bed.frames(5);
    final firstId = NetTestbed.session(first).localPeerId!;
    final second = await bed.addClient(identity: DevIdentityProvider('cat'));
    await bed.frames(5);
    final session = NetTestbed.session(host);
    expect(session.peerIds, isNot(contains(firstId)));
    expect(session.peerFor('dev:cat'), NetTestbed.session(second).localPeerId);
    await bed.dispose();
  });
}
