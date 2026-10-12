import '../protocol/packet.dart';
import '../transport/transport.dart';

/// A datagram carried the fledge_net magic number but a different
/// [PacketHeader.version] than this build speaks.
///
/// Emitted by `NetworkHost.onProtocolMismatch` and
/// `NetworkClient.onProtocolMismatch` so games can show a precise
/// "please update" message instead of a generic timeout.
class ProtocolMismatchEvent {
  /// Address the mismatched datagram came from.
  final NetAddress source;

  /// Protocol version this build speaks ([PacketHeader.version]).
  final int localVersion;

  /// Protocol version found in the datagram.
  final int remoteVersion;

  const ProtocolMismatchEvent({
    required this.source,
    required this.localVersion,
    required this.remoteVersion,
  });

  /// Whether the remote peer runs a newer protocol than this build.
  bool get remoteIsNewer => remoteVersion > localVersion;

  @override
  String toString() =>
      'ProtocolMismatchEvent($source: local v$localVersion, '
      'remote v$remoteVersion)';
}
