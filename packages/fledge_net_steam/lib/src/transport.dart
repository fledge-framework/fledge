import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';

import 'steam.dart';

/// The scheme of Steam addresses and identities: `steam:<SteamID64>`.
const steamScheme = 'steam';

/// The [NetAddress] of the Steam user [steamId]. The host part is the same
/// string as their player identity (`steam:<SteamID64>`); the port is
/// unused.
NetAddress steamAddress(int steamId) => NetAddress('$steamScheme:$steamId', 0);

/// The SteamID64 in a `steam:<SteamID64>` address host or identity, or null
/// if it isn't one.
int? steamIdOf(String hostOrIdentity) {
  const prefix = '$steamScheme:';
  if (!hostOrIdentity.startsWith(prefix)) return null;
  final id = int.tryParse(hostOrIdentity.substring(prefix.length));
  return id != null && id > 0 ? id : null;
}

/// A fledge_net [Transport] over Steam Networking Messages: datagrams
/// between Steam users, relayed through Valve's network with NAT
/// traversal, so friends can host and join with no port forwarding, and
/// every datagram's sender is authenticated by Steam.
///
/// Addresses are Steam users: `NetAddress('steam:<SteamID64>', 0)` (see
/// [steamAddress]). Join a host with its address host as the "host":
///
/// ```dart
/// final steam = Steam.init(appId: 480);
/// final config = NetworkConfig(
///   identityProvider: SteamIdentityProvider(steam),
///   identityVerifier: const SteamIdentityVerifier(),
/// );
/// // Host:
/// await session.host(transport: SteamTransport(steam));
/// // Friend, with the host's SteamID64:
/// await session.join('steam:76561198000000000', 0,
///     transport: SteamTransport(steam));
/// ```
///
/// fledge_net does its own reliability and ordering, so every datagram is
/// sent unreliably. Incoming sessions are accepted from anyone by default
/// ([acceptSession]); who may actually join is the host's handshake's
/// decision (password, identity verifier).
class SteamTransport extends Transport implements AddressResolver {
  SteamTransport(
    this.steam, {
    this.pollInterval = const Duration(milliseconds: 2),
    bool Function(int steamId)? acceptSession,
    this.maxBufferedPackets = 1024,
  }) : acceptSession = acceptSession ?? _acceptAll;

  static bool _acceptAll(int _) => true;

  /// The Steam API this transport sends through. It isn't shut down when
  /// the transport closes: other transports or features may share it.
  final SteamNetworking steam;

  /// How often Steam is checked for new datagrams and session requests.
  final Duration pollInterval;

  /// Whether to accept a session [steamId] started. Refused users' datagrams
  /// are never delivered.
  final bool Function(int steamId) acceptSession;

  /// Datagrams kept while nothing listens (oldest dropped first).
  final int maxBufferedPackets;

  ConnectionState _state = ConnectionState.disconnected;
  NetAddress? _localAddress;
  Timer? _poll;
  final Set<int> _talkingTo = {};
  final TransportStats stats = TransportStats();
  final _receiveController = StreamController<ReceivedPacket>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final Queue<ReceivedPacket> _pending = Queue();

  @override
  ConnectionState get state => _state;

  /// This user's Steam address once bound.
  @override
  NetAddress? get localAddress => _localAddress;

  @override
  Stream<ReceivedPacket> get onReceive => _receiveController.stream;

  @override
  Stream<ConnectionState> get onStateChange => _stateController.stream;

  void _setState(ConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// Starts receiving. [port] is ignored: a Steam user has one address.
  @override
  Future<void> bind(int port) async {
    if (_state != ConnectionState.disconnected) {
      throw StateError('Transport already bound');
    }
    _localAddress = steamAddress(steam.localSteamId);
    _poll = Timer.periodic(pollInterval, (_) => poll());
    _setState(ConnectionState.connected);
  }

  /// Accepts waiting sessions and delivers the datagrams that arrived.
  /// Runs every [pollInterval] once bound; tests call it directly.
  void poll() {
    for (final steamId in steam.takeSessionRequests()) {
      if (acceptSession(steamId)) {
        steam.accept(steamId);
        _talkingTo.add(steamId);
      } else {
        steam.close(steamId);
      }
    }
    for (final datagram in steam.receive()) {
      _deliver(
        ReceivedPacket(
          source: steamAddress(datagram.from),
          data: datagram.data,
        ),
      );
    }
  }

  void _deliver(ReceivedPacket packet) {
    stats
      ..packetsReceived += 1
      ..bytesReceived += packet.data.length;
    if (_receiveController.isClosed) return;
    if (_receiveController.hasListener) {
      _receiveController.add(packet);
      return;
    }
    _pending.add(packet);
    while (_pending.length > maxBufferedPackets) {
      _pending.removeFirst();
    }
  }

  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    if (_state != ConnectionState.connected) {
      throw StateError('Transport not connected');
    }
    final steamId = steamIdOf(address.host);
    if (steamId == null) {
      throw ArgumentError.value(address, 'address', 'not a Steam address');
    }
    _talkingTo.add(steamId);
    if (steam.send(steamId, data)) {
      stats
        ..packetsSent += 1
        ..bytesSent += data.length;
    } else {
      stats.packetsLost += 1;
    }
  }

  @override
  List<ReceivedPacket> receive() {
    final taken = List.of(_pending);
    _pending.clear();
    return taken;
  }

  /// Resolves `steam:<SteamID64>` (the host's address host, or their
  /// identity); anything else isn't a Steam address.
  @override
  Future<NetAddress> resolve(String host, int port) async {
    final steamId = steamIdOf(host);
    if (steamId == null) {
      throw ArgumentError.value(host, 'host', 'expected steam:<SteamID64>');
    }
    return steamAddress(steamId);
  }

  /// Stops receiving and ends the sessions this transport opened. Steam
  /// itself stays initialised.
  @override
  Future<void> close() async {
    _poll?.cancel();
    _poll = null;
    for (final steamId in _talkingTo) {
      steam.close(steamId);
    }
    _talkingTo.clear();
    _pending.clear();
    _localAddress = null;
    _setState(ConnectionState.disconnected);
    await _receiveController.close();
    await _stateController.close();
  }
}

/// Presents this Steam user's identity, `steam:<SteamID64>`, when joining.
/// No proof is needed: under [SteamTransport] Steam authenticates who every
/// datagram is from, and [SteamIdentityVerifier] checks the two match.
class SteamIdentityProvider implements IdentityProvider {
  const SteamIdentityProvider(this.steam);

  final SteamNetworking steam;

  @override
  Future<ClientIdentity> identify() async =>
      ClientIdentity('$steamScheme:${steam.localSteamId}');
}

/// Accepts a `steam:` identity only from the Steam user it names: the
/// connect must come over [SteamTransport] from that SteamID64, which Steam
/// has authenticated. Combine with others in a `SchemeVerifier` to also
/// accept, say, `dev:` players on a LAN.
class SteamIdentityVerifier implements IdentityVerifier {
  const SteamIdentityVerifier();

  @override
  Future<bool> verify(
    String identity,
    Uint8List proof, {
    NetAddress? source,
  }) async {
    final claimed = steamIdOf(identity);
    final from = source == null ? null : steamIdOf(source.host);
    return claimed != null && claimed == from;
  }
}
