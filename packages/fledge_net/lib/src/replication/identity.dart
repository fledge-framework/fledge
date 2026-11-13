import 'dart:convert' show utf8;
import 'dart:math' as math;
import 'dart:typed_data';

import '../transport/transport.dart' show NetAddress;

/// Who a player is, independent of how they connect.
///
/// An identity is an opaque, stable string the host uses to recognise a
/// returning player and give them back what's theirs. By convention it
/// starts with the scheme that issued it, so ids from different sources
/// never collide:
///
/// - `dev:<name>`: local development and LAN play over direct IP
///   ([DevIdentityProvider], trusted by [TrustingVerifier]);
/// - `steam:<SteamID64>`: Steam (from `fledge_net_steam`, verified by Steam);
/// - `hub:<account>`: a gateway or hub service ([TokenIdentityProvider],
///   checked by a [TokenVerifier] that asks the hub).
///
/// Games only compare identities; they never parse them.
class ClientIdentity {
  /// The identity: at most [maxLength] bytes of UTF-8, no control
  /// characters.
  final String id;

  /// Evidence for [id] that the host's [IdentityVerifier] checks (a signed
  /// ticket, a hub token). Empty when the scheme needs none.
  final Uint8List proof;

  ClientIdentity(this.id, [Uint8List? proof]) : proof = proof ?? Uint8List(0) {
    final problem = validate(id);
    if (problem != null) throw ArgumentError.value(id, 'id', problem);
  }

  /// Longest identity, in UTF-8 bytes.
  static const maxLength = 128;

  /// Why [id] isn't a usable identity, or null if it is.
  static String? validate(String id) {
    if (id.isEmpty) return 'empty';
    if (utf8.encode(id).length > maxLength) {
      return 'longer than $maxLength bytes';
    }
    if (id.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
      return 'contains control characters';
    }
    return null;
  }

  @override
  String toString() => 'ClientIdentity($id)';
}

/// Client side: says who this player is when joining a host.
abstract interface class IdentityProvider {
  /// The identity to present, with any proof. Called once per join, so a
  /// provider can fetch a fresh ticket or token.
  Future<ClientIdentity> identify();
}

/// Host side: decides whether a joining client really is who they claim.
abstract interface class IdentityVerifier {
  /// Whether [identity] is backed by [proof]. [source] is the address the
  /// client connected from, which some transports authenticate themselves
  /// (a Steam ID under Steam networking). Rejected identities are turned
  /// away with "Authentication failed".
  Future<bool> verify(String identity, Uint8List proof, {NetAddress? source});
}

/// A fixed identity, for development and LAN play over direct IP: `dev:`
/// followed by [name]. Without proof, anyone can claim any dev identity,
/// so pair it with [TrustingVerifier] only on networks you trust.
///
/// Games keep the name stable per install (e.g. a random one saved on
/// first launch: [DevIdentityProvider.random]).
class DevIdentityProvider implements IdentityProvider {
  /// A provider presenting `dev:<name>`.
  DevIdentityProvider(String name) : identity = ClientIdentity('dev:$name');

  /// A provider with a fresh random name, to be saved and reused.
  factory DevIdentityProvider.random([math.Random? random]) {
    final rng = random ?? math.Random.secure();
    final name = [
      for (var i = 0; i < 16; i++) rng.nextInt(16).toRadixString(16),
    ].join();
    return DevIdentityProvider(name);
  }

  final ClientIdentity identity;

  @override
  Future<ClientIdentity> identify() async => identity;
}

/// An identity vouched for by a token, such as one a gateway or hub
/// service issued at sign-in. The host checks it with a [TokenVerifier].
class TokenIdentityProvider implements IdentityProvider {
  TokenIdentityProvider(this._fetch);

  /// Fetches (or refreshes) the identity and its token before each join.
  final Future<({String id, Uint8List token})> Function() _fetch;

  @override
  Future<ClientIdentity> identify() async {
    final (:id, :token) = await _fetch();
    return ClientIdentity(id, token);
  }
}

/// Accepts every well-formed identity without proof. For development and
/// LAN play only: anyone can claim to be anyone.
class TrustingVerifier implements IdentityVerifier {
  const TrustingVerifier();

  @override
  Future<bool> verify(
    String identity,
    Uint8List proof, {
    NetAddress? source,
  }) async => ClientIdentity.validate(identity) == null;
}

/// Checks identities with a callback, e.g. by asking a hub service whether
/// the token belongs to the identity.
class TokenVerifier implements IdentityVerifier {
  const TokenVerifier(this._check);

  final Future<bool> Function(String identity, Uint8List token) _check;

  @override
  Future<bool> verify(
    String identity,
    Uint8List proof, {
    NetAddress? source,
  }) async =>
      ClientIdentity.validate(identity) == null &&
      await _check(identity, proof);
}

/// Accepts an identity when any of several verifiers does, keyed by scheme
/// (the part before the first `:`). A host can take Steam players and LAN
/// dev players at once, for example.
class SchemeVerifier implements IdentityVerifier {
  const SchemeVerifier(this.byScheme);

  /// Verifiers by scheme, e.g. `{'steam': steamVerifier, 'dev': ...}`.
  final Map<String, IdentityVerifier> byScheme;

  @override
  Future<bool> verify(
    String identity,
    Uint8List proof, {
    NetAddress? source,
  }) async {
    final colon = identity.indexOf(':');
    if (colon <= 0) return false;
    final verifier = byScheme[identity.substring(0, colon)];
    return verifier != null &&
        await verifier.verify(identity, proof, source: source);
  }
}
