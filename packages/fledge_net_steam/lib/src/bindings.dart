// Hand-written bindings for the part of the Steamworks flat API this package
// uses, from `sdk/public/steam/steam_api_flat.h` (SDK 1.65). The structs are
// read by offset rather than mirrored: only the fields used here.
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

/// `HSteamPipe`.
typedef SteamPipe = int;

/// Size of `SteamNetworkingIdentity` (`#pragma pack(4)`: an `int32` type, an
/// `int32` size and a 128-byte union).
const steamNetworkingIdentitySize = 136;

/// Offset of `SteamNetworkingMessage_t::m_identityPeer` (`m_pData` 8 bytes,
/// `m_cbSize` 4, `m_conn` 4).
const _messageIdentityOffset = 16;

/// Size of `CallbackMsg_t` (`int32`, `int32`, pointer, `int32`; 24 bytes
/// at pack 8, 20 at pack 4: allocate the larger).
const _callbackMsgSize = 24;

/// `SteamNetworkingMessagesSessionRequest_t::k_iCallback`.
const sessionRequestCallback = 1251;

/// `SteamNetworkingMessagesSessionFailed_t::k_iCallback`.
const sessionFailedCallback = 1252;

/// `SteamAPICallCompleted_t::k_iCallback`: an async call's result is
/// ready (`m_hAsyncCall` u64 at 0, `m_iCallback` at 8, `m_cubParam` at 12).
const apiCallCompletedCallback = 703;

/// `LobbyCreated_t::k_iCallback`: `m_eResult` at 0, `m_ulSteamIDLobby` at
/// [lobbyCreatedIdOffset].
const lobbyCreatedCallback = 513;

/// `LobbyEnter_t::k_iCallback`: `m_ulSteamIDLobby` at 0,
/// `m_EChatRoomEnterResponse` at 16.
const lobbyEnterCallback = 504;

/// `GameLobbyJoinRequested_t::k_iCallback`: the user accepted an invite (or
/// chose "Join Game") while running; `m_steamIDLobby` at 0.
const gameLobbyJoinRequestedCallback = 333;

/// `GameRichPresenceJoinRequested_t::k_iCallback`: "Join Game" on a friend
/// whose rich presence has a `connect` string; the string is at 8.
const gameRichPresenceJoinRequestedCallback = 337;

/// Size of the callback structs read here, generously.
const callbackStructMax = 512;

/// `k_EChatRoomEnterResponseSuccess`.
const chatRoomEnterSuccess = 1;

/// Where `LobbyCreated_t` keeps the lobby id: callbacks are packed to 8
/// bytes on Windows and to 4 elsewhere (`VALVE_CALLBACK_PACK_*`), so the
/// `uint64` after the 4-byte result lands at 8 or 4.
int get lobbyCreatedIdOffset => Platform.isWindows ? 8 : 4;

/// `k_nSteamNetworkingSend_UnreliableNoNagle`: fledge_net does its own
/// reliability, so every datagram goes unreliable, sent at once.
const sendUnreliableNoNagle = 1;

/// `k_nSteamNetworkingSend_AutoRestartBrokenSession`.
const sendAutoRestartBrokenSession = 32;

/// `k_EResultOK`.
const resultOk = 1;

/// Why `SteamAPI_InitFlat` failed (`ESteamAPIInitResult`).
enum SteamInitResult {
  ok,
  failedGeneric,
  noSteamClient,
  versionMismatch;

  static SteamInitResult of(int value) =>
      value >= 0 && value < values.length ? values[value] : failedGeneric;
}

/// The Steamworks functions used, looked up from `steam_api64.dll`,
/// `libsteam_api.so` or `libsteam_api.dylib`.
class SteamBindings {
  SteamBindings(this.library)
    : initFlat = library
          .lookupFunction<
            Int32 Function(Pointer<Utf8>),
            int Function(Pointer<Utf8>)
          >('SteamAPI_InitFlat'),
      shutdown = library.lookupFunction<Void Function(), void Function()>(
        'SteamAPI_Shutdown',
      ),
      getPipe = library.lookupFunction<Int32 Function(), int Function()>(
        'SteamAPI_GetHSteamPipe',
      ),
      manualDispatchInit = library
          .lookupFunction<Void Function(), void Function()>(
            'SteamAPI_ManualDispatch_Init',
          ),
      manualDispatchRunFrame = library
          .lookupFunction<Void Function(Int32), void Function(int)>(
            'SteamAPI_ManualDispatch_RunFrame',
          ),
      manualDispatchGetNextCallback = library
          .lookupFunction<
            Bool Function(Int32, Pointer<Uint8>),
            bool Function(int, Pointer<Uint8>)
          >('SteamAPI_ManualDispatch_GetNextCallback'),
      manualDispatchFreeLastCallback = library
          .lookupFunction<Void Function(Int32), void Function(int)>(
            'SteamAPI_ManualDispatch_FreeLastCallback',
          ),
      steamUser = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'SteamAPI_SteamUser_v023',
          ),
      userGetSteamId = library
          .lookupFunction<
            Uint64 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('SteamAPI_ISteamUser_GetSteamID'),
      steamFriends = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'SteamAPI_SteamFriends_v018',
          ),
      friendsGetPersonaName = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('SteamAPI_ISteamFriends_GetPersonaName'),
      steamMessages = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'SteamAPI_SteamNetworkingMessages_SteamAPI_v002',
          ),
      messagesSend = library
          .lookupFunction<
            Int32 Function(
              Pointer<Void>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              Uint32,
              Int32,
              Int32,
            ),
            int Function(
              Pointer<Void>,
              Pointer<Uint8>,
              Pointer<Uint8>,
              int,
              int,
              int,
            )
          >('SteamAPI_ISteamNetworkingMessages_SendMessageToUser'),
      messagesReceive = library
          .lookupFunction<
            Int32 Function(
              Pointer<Void>,
              Int32,
              Pointer<Pointer<Uint8>>,
              Int32,
            ),
            int Function(Pointer<Void>, int, Pointer<Pointer<Uint8>>, int)
          >('SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel'),
      messagesAccept = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Pointer<Uint8>),
            bool Function(Pointer<Void>, Pointer<Uint8>)
          >('SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser'),
      messagesClose = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Pointer<Uint8>),
            bool Function(Pointer<Void>, Pointer<Uint8>)
          >('SteamAPI_ISteamNetworkingMessages_CloseSessionWithUser'),
      steamUtils = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'SteamAPI_SteamNetworkingUtils_SteamAPI_v004',
          ),
      utilsInitRelayNetworkAccess = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess'),
      identityClear = library
          .lookupFunction<
            Void Function(Pointer<Uint8>),
            void Function(Pointer<Uint8>)
          >('SteamAPI_SteamNetworkingIdentity_Clear'),
      identitySetSteamId64 = library
          .lookupFunction<
            Void Function(Pointer<Uint8>, Uint64),
            void Function(Pointer<Uint8>, int)
          >('SteamAPI_SteamNetworkingIdentity_SetSteamID64'),
      identityGetSteamId64 = library
          .lookupFunction<
            Uint64 Function(Pointer<Uint8>),
            int Function(Pointer<Uint8>)
          >('SteamAPI_SteamNetworkingIdentity_GetSteamID64'),
      messageRelease = library
          .lookupFunction<
            Void Function(Pointer<Uint8>),
            void Function(Pointer<Uint8>)
          >('SteamAPI_SteamNetworkingMessage_t_Release'),
      manualDispatchGetApiCallResult = library
          .lookupFunction<
            Bool Function(
              Int32,
              Uint64,
              Pointer<Uint8>,
              Int32,
              Int32,
              Pointer<Bool>,
            ),
            bool Function(int, int, Pointer<Uint8>, int, int, Pointer<Bool>)
          >('SteamAPI_ManualDispatch_GetAPICallResult'),
      steamMatchmaking = library
          .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'SteamAPI_SteamMatchmaking_v009',
          ),
      matchmakingCreateLobby = library
          .lookupFunction<
            Uint64 Function(Pointer<Void>, Int32, Int32),
            int Function(Pointer<Void>, int, int)
          >('SteamAPI_ISteamMatchmaking_CreateLobby'),
      matchmakingJoinLobby = library
          .lookupFunction<
            Uint64 Function(Pointer<Void>, Uint64),
            int Function(Pointer<Void>, int)
          >('SteamAPI_ISteamMatchmaking_JoinLobby'),
      matchmakingLeaveLobby = library
          .lookupFunction<
            Void Function(Pointer<Void>, Uint64),
            void Function(Pointer<Void>, int)
          >('SteamAPI_ISteamMatchmaking_LeaveLobby'),
      matchmakingGetLobbyData = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Uint64, Pointer<Utf8>),
            Pointer<Utf8> Function(Pointer<Void>, int, Pointer<Utf8>)
          >('SteamAPI_ISteamMatchmaking_GetLobbyData'),
      matchmakingSetLobbyData = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Uint64, Pointer<Utf8>, Pointer<Utf8>),
            bool Function(Pointer<Void>, int, Pointer<Utf8>, Pointer<Utf8>)
          >('SteamAPI_ISteamMatchmaking_SetLobbyData'),
      matchmakingGetLobbyOwner = library
          .lookupFunction<
            Uint64 Function(Pointer<Void>, Uint64),
            int Function(Pointer<Void>, int)
          >('SteamAPI_ISteamMatchmaking_GetLobbyOwner'),
      matchmakingGetNumLobbyMembers = library
          .lookupFunction<
            Int32 Function(Pointer<Void>, Uint64),
            int Function(Pointer<Void>, int)
          >('SteamAPI_ISteamMatchmaking_GetNumLobbyMembers'),
      matchmakingGetLobbyMemberByIndex = library
          .lookupFunction<
            Uint64 Function(Pointer<Void>, Uint64, Int32),
            int Function(Pointer<Void>, int, int)
          >('SteamAPI_ISteamMatchmaking_GetLobbyMemberByIndex'),
      friendsActivateInviteDialog = library
          .lookupFunction<
            Void Function(Pointer<Void>, Uint64),
            void Function(Pointer<Void>, int)
          >('SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialog'),
      friendsSetRichPresence = library
          .lookupFunction<
            Bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
            bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
          >('SteamAPI_ISteamFriends_SetRichPresence'),
      friendsClearRichPresence = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('SteamAPI_ISteamFriends_ClearRichPresence');

  final DynamicLibrary library;

  final int Function(Pointer<Utf8> errMsg) initFlat;
  final void Function() shutdown;
  final int Function() getPipe;
  final void Function() manualDispatchInit;
  final void Function(int pipe) manualDispatchRunFrame;
  final bool Function(int pipe, Pointer<Uint8> msg)
  manualDispatchGetNextCallback;
  final void Function(int pipe) manualDispatchFreeLastCallback;
  final Pointer<Void> Function() steamUser;
  final int Function(Pointer<Void> user) userGetSteamId;
  final Pointer<Void> Function() steamFriends;
  final Pointer<Utf8> Function(Pointer<Void> friends) friendsGetPersonaName;
  final Pointer<Void> Function() steamMessages;
  final int Function(
    Pointer<Void> messages,
    Pointer<Uint8> identity,
    Pointer<Uint8> data,
    int length,
    int flags,
    int channel,
  )
  messagesSend;
  final int Function(
    Pointer<Void> messages,
    int channel,
    Pointer<Pointer<Uint8>> out,
    int max,
  )
  messagesReceive;
  final bool Function(Pointer<Void> messages, Pointer<Uint8> identity)
  messagesAccept;
  final bool Function(Pointer<Void> messages, Pointer<Uint8> identity)
  messagesClose;
  final Pointer<Void> Function() steamUtils;
  final void Function(Pointer<Void> utils) utilsInitRelayNetworkAccess;
  final void Function(Pointer<Uint8> identity) identityClear;
  final void Function(Pointer<Uint8> identity, int steamId)
  identitySetSteamId64;
  final int Function(Pointer<Uint8> identity) identityGetSteamId64;
  final void Function(Pointer<Uint8> message) messageRelease;
  final bool Function(
    int pipe,
    int call,
    Pointer<Uint8> result,
    int size,
    int expectedCallback,
    Pointer<Bool> failed,
  )
  manualDispatchGetApiCallResult;
  final Pointer<Void> Function() steamMatchmaking;
  final int Function(Pointer<Void> mm, int type, int maxMembers)
  matchmakingCreateLobby;
  final int Function(Pointer<Void> mm, int lobby) matchmakingJoinLobby;
  final void Function(Pointer<Void> mm, int lobby) matchmakingLeaveLobby;
  final Pointer<Utf8> Function(Pointer<Void> mm, int lobby, Pointer<Utf8> key)
  matchmakingGetLobbyData;
  final bool Function(
    Pointer<Void> mm,
    int lobby,
    Pointer<Utf8> key,
    Pointer<Utf8> value,
  )
  matchmakingSetLobbyData;
  final int Function(Pointer<Void> mm, int lobby) matchmakingGetLobbyOwner;
  final int Function(Pointer<Void> mm, int lobby) matchmakingGetNumLobbyMembers;
  final int Function(Pointer<Void> mm, int lobby, int index)
  matchmakingGetLobbyMemberByIndex;
  final void Function(Pointer<Void> friends, int lobby)
  friendsActivateInviteDialog;
  final bool Function(
    Pointer<Void> friends,
    Pointer<Utf8> key,
    Pointer<Utf8> value,
  )
  friendsSetRichPresence;
  final void Function(Pointer<Void> friends) friendsClearRichPresence;

  /// The sender identity inside a received `SteamNetworkingMessage_t`.
  static Pointer<Uint8> messageIdentity(Pointer<Uint8> message) =>
      message + _messageIdentityOffset;

  /// `m_pData` and `m_cbSize` of a received `SteamNetworkingMessage_t`.
  static (Pointer<Uint8>, int) messageData(Pointer<Uint8> message) =>
      (message.cast<Pointer<Uint8>>().value, (message + 8).cast<Int32>().value);

  /// Allocates a `CallbackMsg_t` for [manualDispatchGetNextCallback].
  static Pointer<Uint8> allocateCallbackMsg() =>
      calloc<Uint8>(_callbackMsgSize);

  /// `m_iCallback`, `m_pubParam` and `m_cubParam` of a `CallbackMsg_t`.
  static (int, Pointer<Uint8>, int) callbackFields(Pointer<Uint8> msg) => (
    (msg + 4).cast<Int32>().value,
    (msg + 8).cast<Pointer<Uint8>>().value,
    (msg + 16).cast<Int32>().value,
  );
}
