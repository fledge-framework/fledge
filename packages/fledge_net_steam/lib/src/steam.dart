import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// A datagram received from another Steam user.
class SteamDatagram {
  const SteamDatagram(this.from, this.data);

  /// The sender's SteamID64, authenticated by Steam.
  final int from;
  final Uint8List data;
}

/// What `SteamTransport` needs from Steam. [Steam] is the real one; tests
/// use a fake, so the transport can be tested without Steam running.
abstract interface class SteamNetworking {
  /// This user's SteamID64.
  int get localSteamId;

  /// Sends [data] to [steamId] as one unreliable datagram. Returns whether
  /// Steam took it.
  bool send(int steamId, Uint8List data);

  /// Datagrams that arrived since the last call, oldest first.
  List<SteamDatagram> receive();

  /// Users who started talking to us since the last call and are waiting
  /// for their session to be accepted.
  List<int> takeSessionRequests();

  /// Accepts [steamId]'s session, so their datagrams are delivered.
  void accept(int steamId);

  /// Ends the session with [steamId].
  void close(int steamId);
}

/// Who can find and join a lobby (`ELobbyType`).
enum LobbyType {
  /// Only by invitation.
  private,

  /// Friends and invitees; joiners can invite their own friends.
  friendsOnly,

  /// Friends, and anyone browsing the lobby list.
  public,

  /// Found by search, but hidden from friends.
  invisible,
}

/// A lobby operation Steam reported as failed.
class SteamLobbyException implements Exception {
  const SteamLobbyException(this.message);

  final String message;

  @override
  String toString() => 'SteamLobbyException: $message';
}

/// What `SteamCoop` needs from Steam's matchmaking and friends features:
/// lobbies, the invite overlay, rich presence, and the requests to join a
/// friend. [Steam] is the real one; tests use a fake.
abstract interface class SteamMatchmaking {
  /// This user's SteamID64.
  int get localSteamId;

  /// Creates a lobby and enters it; completes with its id.
  Future<int> createLobby(LobbyType type, int maxMembers);

  /// Enters [lobby]; completes with its id, or throws
  /// [SteamLobbyException] if it's full, gone or closed.
  Future<int> joinLobby(int lobby);

  /// Leaves [lobby].
  void leaveLobby(int lobby);

  /// Sets [key] to [value] on [lobby] (owner only), visible to members.
  void setLobbyData(int lobby, String key, String value);

  /// [lobby]'s value for [key], or empty.
  String lobbyData(int lobby, String key);

  /// [lobby]'s owner.
  int lobbyOwner(int lobby);

  /// Who is in [lobby].
  List<int> lobbyMembers(int lobby);

  /// Opens the Steam overlay's dialog for inviting friends to [lobby].
  void openInviteDialog(int lobby);

  /// Sets this user's rich presence [key] (e.g. `connect`, which puts
  /// "Join Game" on them in friends' lists), or clears it with null.
  void setRichPresence(String key, String? value);

  /// Lobbies this user asked to join from Steam while the game ran:
  /// accepting an invite, or "Join Game" on a friend.
  Stream<int> get lobbyJoinRequests;
}

/// Initialising Steam failed: Steam isn't running, the app id is unknown,
/// or the library is missing or too old.
class SteamException implements Exception {
  const SteamException(this.result, this.message);

  final SteamInitResult result;
  final String message;

  @override
  String toString() => 'SteamException(${result.name}): $message';
}

/// The Steamworks API, loaded and initialised: who this user is, and Steam
/// Networking Messages (relayed, NAT-traversing, authenticated datagrams).
///
/// ```dart
/// final steam = Steam.init(appId: 480); // 480: Valve's test app
/// final transport = SteamTransport(steam);
/// ```
///
/// Needs the Steam client running and logged in, and the `steam_api`
/// library from the Steamworks SDK (`redistributable_bin/`) next to the
/// executable or at [Steam.init]'s `libraryPath`. Call [shutdown] on exit.
class Steam implements SteamNetworking, SteamMatchmaking {
  Steam._(this._api, Duration pumpInterval) {
    _api.manualDispatchInit();
    _pipe = _api.getPipe();
    _user = _api.steamUser();
    _friends = _api.steamFriends();
    _messages = _api.steamMessages();
    _matchmaking = _api.steamMatchmaking();
    _api.utilsInitRelayNetworkAccess(_api.steamUtils());
    localSteamId = _api.userGetSteamId(_user);
    // Steam's callbacks (lobby results, invites, session requests) are
    // pumped here, so they arrive whether or not a transport is running.
    _pumpTimer = Timer.periodic(pumpInterval, (_) => pump());
  }

  /// Loads the Steamworks library and initialises it.
  ///
  /// [libraryPath] is the `steam_api` library to load; by default it's
  /// looked for where a packaged game keeps it ([bundledLibraryPaths]),
  /// then by name (`steam_api64.dll`, `libsteam_api.so`,
  /// `libsteam_api.dylib`) the platform's usual way.
  ///
  /// [appId], for development, writes a `steam_appid.txt` with it to the
  /// current directory if none is there (and the game wasn't launched by
  /// Steam), which is how Steam learns the app of a game not launched
  /// through it. Use 480 (Valve's "Spacewar" test
  /// app) until the game has its own. Shipping builds launched by Steam
  /// leave it null.
  ///
  /// Steam's callbacks are run every [pumpInterval].
  ///
  /// Throws [SteamException] if Steam can't be initialised, and an
  /// [ArgumentError] if the library can't be loaded.
  factory Steam.init({
    String? libraryPath,
    int? appId,
    Duration pumpInterval = const Duration(milliseconds: 10),
  }) {
    // Launched by Steam, the app is known (Steam sets SteamAppId), and an
    // install folder may not be writable: only write the file otherwise,
    // and never let it stop Steam starting.
    if (appId != null && Platform.environment['SteamAppId'] == null) {
      try {
        final file = File('${Directory.current.path}/steam_appid.txt');
        if (!file.existsSync()) file.writeAsStringSync('$appId');
      } on FileSystemException {
        // Steam reports the missing app id itself if it matters.
      }
    }
    final api = SteamBindings(_open(libraryPath));
    final error = calloc<Uint8>(1024).cast<Utf8>();
    try {
      final result = SteamInitResult.of(api.initFlat(error));
      if (result != SteamInitResult.ok) {
        throw SteamException(result, error.toDartString());
      }
    } finally {
      calloc.free(error);
    }
    return Steam._(api, pumpInterval);
  }

  /// Where a packaged game keeps the library: next to the executable on
  /// Windows, in the bundle's `lib/` on Linux, in the app's `Frameworks/`
  /// on macOS.
  static List<String> get bundledLibraryPaths {
    final exe = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) return ['$exe/$libraryName'];
    if (Platform.isMacOS) {
      return ['$exe/../Frameworks/$libraryName', '$exe/$libraryName'];
    }
    return ['$exe/lib/$libraryName', '$exe/$libraryName'];
  }

  static DynamicLibrary _open(String? libraryPath) {
    if (libraryPath != null) return DynamicLibrary.open(libraryPath);
    for (final path in bundledLibraryPaths) {
      if (File(path).existsSync()) return DynamicLibrary.open(path);
    }
    return DynamicLibrary.open(libraryName);
  }

  /// The `steam_api` library's file name on this platform.
  static String get libraryName {
    if (Platform.isWindows) return 'steam_api64.dll';
    if (Platform.isMacOS) return 'libsteam_api.dylib';
    return 'libsteam_api.so';
  }

  final SteamBindings _api;
  late final int _pipe;
  late final Pointer<Void> _user;
  late final Pointer<Void> _friends;
  late final Pointer<Void> _messages;
  late final Pointer<Void> _matchmaking;
  late final Timer _pumpTimer;
  final Pointer<Uint8> _result = calloc<Uint8>(callbackStructMax);
  final Pointer<Bool> _failed = calloc<Bool>();
  final Map<int, _PendingCall> _calls = {};
  final _joinRequests = StreamController<int>.broadcast();
  final Pointer<Uint8> _callback = SteamBindings.allocateCallbackMsg();
  final Pointer<Uint8> _identity = calloc<Uint8>(steamNetworkingIdentitySize);
  final Pointer<Pointer<Uint8>> _inbox = calloc<Pointer<Uint8>>(_inboxSize);
  final List<int> _requests = [];
  bool _shutDown = false;

  /// Messages read per receive call.
  static const _inboxSize = 64;

  @override
  late final int localSteamId;

  /// This user's Steam display name.
  String get personaName => _api.friendsGetPersonaName(_friends).toDartString();

  /// Runs Steam's callbacks: session requests are collected for
  /// [takeSessionRequests]. Called by [takeSessionRequests]; call it once a
  /// frame too if nothing else does.
  void pump() {
    if (_shutDown) return;
    _api.manualDispatchRunFrame(_pipe);
    while (_api.manualDispatchGetNextCallback(_pipe, _callback)) {
      final (id, param, _) = SteamBindings.callbackFields(_callback);
      switch (id) {
        case sessionRequestCallback:
          // The callback's only field is the requesting identity.
          _requests.add(_api.identityGetSteamId64(param));
        case apiCallCompletedCallback:
          _completeCall(param);
        case gameLobbyJoinRequestedCallback:
          _joinRequests.add(param.cast<Uint64>().value);
        case gameRichPresenceJoinRequestedCallback:
          final lobby = lobbyFromConnect(
            (param + 8).cast<Utf8>().toDartString(),
          );
          if (lobby != null) _joinRequests.add(lobby);
      }
      _api.manualDispatchFreeLastCallback(_pipe);
    }
  }

  Pointer<Uint8> _identityOf(int steamId) {
    _api
      ..identityClear(_identity)
      ..identitySetSteamId64(_identity, steamId);
    return _identity;
  }

  @override
  bool send(int steamId, Uint8List data) {
    if (_shutDown) return false;
    final buffer = calloc<Uint8>(data.length);
    try {
      buffer.asTypedList(data.length).setAll(0, data);
      final result = _api.messagesSend(
        _messages,
        _identityOf(steamId),
        buffer,
        data.length,
        sendUnreliableNoNagle | sendAutoRestartBrokenSession,
        0,
      );
      return result == resultOk;
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  List<SteamDatagram> receive() {
    if (_shutDown) return const [];
    final out = <SteamDatagram>[];
    while (true) {
      final count = _api.messagesReceive(_messages, 0, _inbox, _inboxSize);
      for (var i = 0; i < count; i++) {
        final message = _inbox[i];
        final (data, length) = SteamBindings.messageData(message);
        final from = _api.identityGetSteamId64(
          SteamBindings.messageIdentity(message),
        );
        out.add(
          SteamDatagram(from, Uint8List.fromList(data.asTypedList(length))),
        );
        _api.messageRelease(message);
      }
      if (count < _inboxSize) return out;
    }
  }

  // Async calls ----------------------------------------------------------------

  /// An async call's result is ready: read it and finish the waiting call.
  void _completeCall(Pointer<Uint8> completed) {
    final call = completed.cast<Uint64>().value;
    final size = (completed + 12).cast<Uint32>().value;
    final pending = _calls.remove(call);
    if (pending == null) return;
    final ok =
        size <= callbackStructMax &&
        _api.manualDispatchGetApiCallResult(
          _pipe,
          call,
          _result,
          size,
          pending.callback,
          _failed,
        ) &&
        !_failed.value;
    if (!ok) {
      pending.completer.completeError(
        SteamLobbyException('Steam call ${pending.callback} failed'),
      );
      return;
    }
    pending.read(_result, pending.completer);
  }

  Future<int> _await(
    int call,
    int callback,
    void Function(Pointer<Uint8> result, Completer<int> done) read,
  ) {
    if (call == 0) {
      return Future.error(const SteamLobbyException('Steam refused the call'));
    }
    final completer = Completer<int>();
    _calls[call] = _PendingCall(callback, completer, read);
    return completer.future;
  }

  // Matchmaking ------------------------------------------------------------------

  @override
  Future<int> createLobby(LobbyType type, int maxMembers) => _await(
    _api.matchmakingCreateLobby(_matchmaking, type.index, maxMembers),
    lobbyCreatedCallback,
    (result, done) {
      final status = result.cast<Int32>().value;
      if (status != resultOk) {
        done.completeError(SteamLobbyException('Lobby not created ($status)'));
        return;
      }
      done.complete((result + lobbyCreatedIdOffset).cast<Uint64>().value);
    },
  );

  @override
  Future<int> joinLobby(int lobby) => _await(
    _api.matchmakingJoinLobby(_matchmaking, lobby),
    lobbyEnterCallback,
    (result, done) {
      final response = (result + 16).cast<Uint32>().value;
      if (response != chatRoomEnterSuccess) {
        done.completeError(SteamLobbyException('Could not enter ($response)'));
        return;
      }
      done.complete(result.cast<Uint64>().value);
    },
  );

  @override
  void leaveLobby(int lobby) => _api.matchmakingLeaveLobby(_matchmaking, lobby);

  @override
  void setLobbyData(int lobby, String key, String value) =>
      _withStrings(key, value, (k, v) {
        _api.matchmakingSetLobbyData(_matchmaking, lobby, k, v);
      });

  @override
  String lobbyData(int lobby, String key) {
    final k = key.toNativeUtf8();
    try {
      return _api
          .matchmakingGetLobbyData(_matchmaking, lobby, k)
          .toDartString();
    } finally {
      calloc.free(k);
    }
  }

  @override
  int lobbyOwner(int lobby) =>
      _api.matchmakingGetLobbyOwner(_matchmaking, lobby);

  @override
  List<int> lobbyMembers(int lobby) => [
    for (
      var i = 0;
      i < _api.matchmakingGetNumLobbyMembers(_matchmaking, lobby);
      i++
    )
      _api.matchmakingGetLobbyMemberByIndex(_matchmaking, lobby, i),
  ];

  @override
  void openInviteDialog(int lobby) =>
      _api.friendsActivateInviteDialog(_friends, lobby);

  @override
  void setRichPresence(String key, String? value) =>
      _withStrings(key, value ?? '', (k, v) {
        _api.friendsSetRichPresence(_friends, k, v);
      });

  /// Clears all of this user's rich presence.
  void clearRichPresence() => _api.friendsClearRichPresence(_friends);

  @override
  Stream<int> get lobbyJoinRequests => _joinRequests.stream;

  /// The lobby in a rich presence `connect` string or launch arguments
  /// (`+connect_lobby <id>`), or null.
  static int? lobbyFromConnect(String connect) =>
      lobbyFromArgs(connect.trim().split(RegExp(r'\s+')));

  /// The lobby Steam asked this launch to join: it starts a game with
  /// `+connect_lobby <id>` when a friend accepts an invite or picks "Join
  /// Game" while it isn't running. Null if there's none.
  static int? lobbyFromArgs(List<String> args) {
    final at = args.indexOf('+connect_lobby');
    if (at < 0 || at + 1 >= args.length) return null;
    final lobby = int.tryParse(args[at + 1]);
    return lobby != null && lobby > 0 ? lobby : null;
  }

  static void _withStrings(
    String a,
    String b,
    void Function(Pointer<Utf8>, Pointer<Utf8>) use,
  ) {
    final na = a.toNativeUtf8();
    final nb = b.toNativeUtf8();
    try {
      use(na, nb);
    } finally {
      calloc
        ..free(na)
        ..free(nb);
    }
  }

  @override
  List<int> takeSessionRequests() {
    pump();
    final taken = List.of(_requests);
    _requests.clear();
    return taken;
  }

  @override
  void accept(int steamId) {
    if (!_shutDown) _api.messagesAccept(_messages, _identityOf(steamId));
  }

  @override
  void close(int steamId) {
    if (!_shutDown) _api.messagesClose(_messages, _identityOf(steamId));
  }

  /// Shuts Steam down. Nothing here works afterwards.
  void shutdown() {
    if (_shutDown) return;
    _shutDown = true;
    _pumpTimer.cancel();
    for (final pending in _calls.values) {
      pending.completer.completeError(
        const SteamLobbyException('Steam shut down'),
      );
    }
    _calls.clear();
    _joinRequests.close();
    _api.shutdown();
    calloc
      ..free(_result)
      ..free(_failed)
      ..free(_callback)
      ..free(_identity)
      ..free(_inbox);
  }
}

class _PendingCall {
  _PendingCall(this.callback, this.completer, this.read);

  final int callback;
  final Completer<int> completer;
  final void Function(Pointer<Uint8> result, Completer<int> done) read;
}
