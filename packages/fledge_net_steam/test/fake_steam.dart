import 'dart:async';
import 'dart:typed_data';

import 'package:fledge_net_steam/fledge_net_steam.dart';

/// A pretend Steam network: users talk by SteamID64 the way Steam
/// Networking Messages works. The first datagram from someone new raises a
/// session request; their datagrams are held until the session is accepted,
/// and dropped if it's refused.
class FakeSteamNetwork {
  final Map<int, FakeSteam> _users = {};

  /// Lobbies by id: owner, members, data, capacity.
  final Map<int, FakeLobby> lobbies = {};
  int _nextLobby = 109775240000000001;

  /// The next lobby creation fails, as when Steam's servers can't be
  /// reached.
  bool failNextLobby = false;

  FakeSteam user(int steamId) =>
      _users.putIfAbsent(steamId, () => FakeSteam._(this, steamId));

  void _deliver(int from, int to, Uint8List data) {
    final recipient = _users[to];
    if (recipient == null) return; // offline: Steam drops it
    recipient._arrive(from, data);
  }
}

class FakeLobby {
  FakeLobby(this.owner, this.max);

  final int owner;
  final int max;
  final List<int> members = [];
  final Map<String, String> data = {};
}

class FakeSteam implements SteamNetworking, SteamMatchmaking {
  FakeSteam._(this._network, this.localSteamId);

  final FakeSteamNetwork _network;

  @override
  final int localSteamId;

  final Set<int> _accepted = {};
  final Set<int> _requested = {};
  final List<int> _requests = [];
  final Map<int, List<Uint8List>> _held = {};
  final List<SteamDatagram> _inbox = [];
  final List<int> closed = [];

  void _arrive(int from, Uint8List data) {
    if (_accepted.contains(from)) {
      _inbox.add(SteamDatagram(from, data));
      return;
    }
    (_held[from] ??= []).add(data);
    if (_requested.add(from)) _requests.add(from);
  }

  @override
  bool send(int steamId, Uint8List data) {
    // Talking to someone opens the session from our side.
    _accepted.add(steamId);
    _network._deliver(localSteamId, steamId, Uint8List.fromList(data));
    return true;
  }

  @override
  List<SteamDatagram> receive() {
    final taken = List.of(_inbox);
    _inbox.clear();
    return taken;
  }

  @override
  List<int> takeSessionRequests() {
    final taken = List.of(_requests);
    _requests.clear();
    return taken;
  }

  @override
  void accept(int steamId) {
    _accepted.add(steamId);
    for (final data in _held.remove(steamId) ?? const <Uint8List>[]) {
      _inbox.add(SteamDatagram(steamId, data));
    }
  }

  // Matchmaking ----------------------------------------------------------------

  final invitesOpened = <int>[];
  final presence = <String, String>{};
  final joinRequests = StreamController<int>.broadcast();

  @override
  Future<int> createLobby(LobbyType type, int maxMembers) async {
    if (_network.failNextLobby) {
      _network.failNextLobby = false;
      throw const SteamLobbyException('Lobby not created (3)');
    }
    final id = _network._nextLobby++;
    _network.lobbies[id] = FakeLobby(localSteamId, maxMembers)
      ..members.add(localSteamId);
    return id;
  }

  @override
  Future<int> joinLobby(int lobby) async {
    final found = _network.lobbies[lobby];
    if (found == null || found.members.length >= found.max) {
      throw const SteamLobbyException('Could not enter (2)');
    }
    found.members.add(localSteamId);
    return lobby;
  }

  @override
  void leaveLobby(int lobby) =>
      _network.lobbies[lobby]?.members.remove(localSteamId);

  @override
  void setLobbyData(int lobby, String key, String value) {
    final found = _network.lobbies[lobby];
    if (found != null && found.owner == localSteamId) found.data[key] = value;
  }

  @override
  String lobbyData(int lobby, String key) =>
      _network.lobbies[lobby]?.data[key] ?? '';

  @override
  int lobbyOwner(int lobby) => _network.lobbies[lobby]?.owner ?? 0;

  @override
  List<int> lobbyMembers(int lobby) =>
      List.of(_network.lobbies[lobby]?.members ?? const <int>[]);

  @override
  void openInviteDialog(int lobby) => invitesOpened.add(lobby);

  @override
  void setRichPresence(String key, String? value) {
    if (value == null) {
      presence.remove(key);
    } else {
      presence[key] = value;
    }
  }

  @override
  Stream<int> get lobbyJoinRequests => joinRequests.stream;

  @override
  void close(int steamId) {
    closed.add(steamId);
    _accepted.remove(steamId);
    _requested.remove(steamId);
    _held.remove(steamId);
  }
}
