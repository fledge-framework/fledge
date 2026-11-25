import 'package:fledge_net/fledge_net.dart';

import 'steam.dart';
import 'transport.dart';

/// Hosting and joining a fledge_net session through a Steam lobby, the way
/// players expect: the host opens a lobby, invites friends from the Steam
/// overlay, and friends join by accepting the invite or picking "Join Game"
/// in their friends list, even when the game isn't running yet.
///
/// ```dart
/// final coop = SteamCoop(steam, steam);
/// // Host:
/// await coop.host(session);
/// coop.invite();
/// // Friend, from an invite (running), or from launch arguments:
/// steam.lobbyJoinRequests.listen((lobby) => coop.join(session, lobby));
/// final pending = Steam.lobbyFromArgs(args);
/// if (pending != null) await coop.join(session, pending);
/// ```
///
/// The lobby only carries who the host is ([hostKey]); the game itself runs
/// over [SteamTransport], and who may join is still the host's handshake's
/// decision (password, identity verifier).
class SteamCoop {
  SteamCoop(this.lobbies, this.networking);

  /// Lobbies, invites and rich presence (the [Steam] object).
  final SteamMatchmaking lobbies;

  /// Datagrams between Steam users (the same [Steam] object).
  final SteamNetworking networking;

  /// Lobby data key naming the host: `steam:<SteamID64>`.
  static const hostKey = 'fledge_host';

  /// The lobby this player is in, if any.
  int? get lobby => _lobby;
  int? _lobby;

  /// The rich presence `connect` string that lets friends join [lobby]
  /// from their friends list (Steam launches the game with it as
  /// arguments when it isn't running).
  static String connectString(int lobby) => '+connect_lobby $lobby';

  /// Opens a lobby of [type] for up to [maxPlayers], starts hosting
  /// [session] over Steam (or [transport]), and advertises it so friends
  /// can "Join Game". Returns the lobby id.
  Future<int> host(
    NetworkSession session, {
    LobbyType type = LobbyType.friendsOnly,
    int maxPlayers = 4,
    Transport? transport,
  }) async {
    final id = await lobbies.createLobby(type, maxPlayers);
    _lobby = id;
    lobbies.setLobbyData(id, hostKey, '$steamScheme:${lobbies.localSteamId}');
    try {
      await session.host(transport: transport ?? SteamTransport(networking));
    } catch (_) {
      leave();
      rethrow;
    }
    lobbies.setRichPresence('connect', connectString(id));
    return id;
  }

  /// Opens the Steam overlay to invite friends to the hosted lobby.
  void invite() {
    final id = _lobby;
    if (id == null) throw StateError('Not in a lobby: host first');
    lobbies.openInviteDialog(id);
  }

  /// Enters [lobby], finds its host and joins their [session] over Steam
  /// (or [transport]). Resolves to whether the session accepted; on failure
  /// the lobby is left again and `session.lastError` says why.
  Future<bool> join(
    NetworkSession session,
    int lobby, {
    Transport? transport,
  }) async {
    await lobbies.joinLobby(lobby);
    _lobby = lobby;
    final host = hostOf(lobby);
    final bool joined;
    try {
      joined = await session.join(
        host,
        0,
        transport: transport ?? SteamTransport(networking),
      );
    } catch (_) {
      // For example a session that is already running: don't stay in the
      // lobby we just joined.
      leave();
      rethrow;
    }
    if (!joined) {
      leave();
      return false;
    }
    lobbies.setRichPresence('connect', connectString(lobby));
    return true;
  }

  /// The host of [lobby] as a join address (`steam:<SteamID64>`): what the
  /// host advertised in [hostKey], or else the lobby's owner.
  String hostOf(int lobby) {
    final advertised = lobbies.lobbyData(lobby, hostKey);
    if (steamIdOf(advertised) != null) return advertised;
    return '$steamScheme:${lobbies.lobbyOwner(lobby)}';
  }

  /// Leaves the lobby and stops advertising it. The session is the
  /// caller's to close.
  void leave() {
    final id = _lobby;
    if (id == null) return;
    _lobby = null;
    lobbies
      ..leaveLobby(id)
      ..setRichPresence('connect', null);
  }
}
