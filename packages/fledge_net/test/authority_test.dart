import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkIdentity authority model', () {
    test('isOwnedBy returns true for matching peerId', () {
      final id = NetworkIdentity(netId: 1, ownerId: 5);
      expect(id.isOwnedBy(5), true);
    });

    test('isOwnedBy returns false for non-matching peerId', () {
      final id = NetworkIdentity(netId: 1, ownerId: 5);
      expect(id.isOwnedBy(3), false);
    });

    test('isOwnedBy returns true for host (ownerId 0)', () {
      final id = NetworkIdentity(netId: 1, ownerId: 0);
      expect(id.isOwnedBy(0), true);
      expect(id.isOwnedBy(1), false);
    });

    test('transferAuthority updates ownerId and hasAuthority', () {
      final id = NetworkIdentity(netId: 1, ownerId: 0, hasAuthority: true);

      // Transfer to client 3 without local authority.
      id.transferAuthority(3);
      expect(id.ownerId, 3);
      expect(id.hasAuthority, false);
    });

    test('transferAuthority with localAuthority true', () {
      final id = NetworkIdentity(netId: 1, ownerId: 0, hasAuthority: false);

      id.transferAuthority(5, localAuthority: true);
      expect(id.ownerId, 5);
      expect(id.hasAuthority, true);
    });

    test('transferAuthority back to host', () {
      final id = NetworkIdentity(netId: 1, ownerId: 3, hasAuthority: true);

      id.transferAuthority(0, localAuthority: true);
      expect(id.ownerId, 0);
      expect(id.hasAuthority, true);
      expect(id.isOwnedBy(0), true);
      expect(id.isOwnedBy(3), false);
    });
  });
}
