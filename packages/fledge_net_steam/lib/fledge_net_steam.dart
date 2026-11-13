/// Steam networking for Fledge: fledge_net over Steam Networking Messages
/// (Valve's relays and NAT traversal, so friends join with no port
/// forwarding), with Steam player identities (`steam:<SteamID64>`).
///
/// - [Steam]: loads and initialises the Steamworks API.
/// - [SteamTransport]: a fledge_net transport between Steam users.
/// - [SteamIdentityProvider] / [SteamIdentityVerifier]: player identities
///   that Steam vouches for.
/// - [SteamCoop]: hosting and joining through a Steam lobby, with overlay
///   invites and "Join Game".
library;

export 'src/bindings.dart' show SteamInitResult;
export 'src/coop.dart';
export 'src/steam.dart';
export 'src/transport.dart';
