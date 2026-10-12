import 'dart:typed_data';

/// Connection state for network transports.
enum ConnectionState {
  /// Not connected.
  disconnected,

  /// Attempting to connect.
  connecting,

  /// Successfully connected.
  connected,

  /// Connection failed or was lost.
  failed,
}

/// Network address for peers.
class NetAddress {
  /// IP address or hostname.
  final String host;

  /// Port number.
  final int port;

  const NetAddress(this.host, this.port);

  @override
  String toString() => '$host:$port';

  @override
  bool operator ==(Object other) =>
      other is NetAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// Received packet from network.
class ReceivedPacket {
  /// Source address of the packet.
  final NetAddress source;

  /// Packet data.
  final Uint8List data;

  /// Timestamp when packet was received.
  final DateTime receivedAt;

  ReceivedPacket({
    required this.source,
    required this.data,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

/// Abstract transport interface for network communication.
///
/// Implementations provide specific protocols (UDP, WebSocket, in-memory
/// loopback, etc.).
///
/// ## Delivery contract
///
/// Every received datagram is delivered **exactly once**, through one of
/// two paths:
///
/// 1. **Push** (primary): if [onReceive] has at least one listener, the
///    packet is emitted on [onReceive] and is *not* retained.
///    `NetworkHost` and `NetworkClient` use this path.
/// 2. **Poll** (fallback): if nobody is listening to [onReceive], the
///    packet is held in a *bounded* buffer that [receive] drains. When the
///    buffer is full the oldest packets are discarded, so an undrained
///    transport never grows without limit.
///
/// Implementations must not deliver a packet on both paths, and must bound
/// any buffering. Wrappers (e.g. `EncryptedTransport`) delegate to the
/// inner transport and therefore inherit its behaviour.
abstract class Transport {
  /// Current connection state.
  ConnectionState get state;

  /// Local address this transport is bound to.
  NetAddress? get localAddress;

  /// Initialize and bind the transport.
  Future<void> bind(int port);

  /// Close the transport and release resources.
  Future<void> close();

  /// Send data to a specific address.
  Future<void> send(NetAddress address, Uint8List data);

  /// Send data to multiple addresses.
  Future<void> sendMultiple(List<NetAddress> addresses, Uint8List data) async {
    for (final address in addresses) {
      await send(address, data);
    }
  }

  /// Drain packets buffered while nobody was listening to [onReceive].
  ///
  /// Returns an empty list if no packets are available — always the case
  /// while an [onReceive] listener is attached (see the class-level
  /// delivery contract).
  List<ReceivedPacket> receive();

  /// Stream of received packets (the primary delivery path).
  Stream<ReceivedPacket> get onReceive;

  /// Stream of state changes.
  Stream<ConnectionState> get onStateChange;
}

/// Transport statistics for monitoring.
class TransportStats {
  /// Total bytes sent.
  int bytesSent = 0;

  /// Total bytes received.
  int bytesReceived = 0;

  /// Total packets sent.
  int packetsSent = 0;

  /// Total packets received.
  int packetsReceived = 0;

  /// Packets lost (if detectable).
  int packetsLost = 0;

  /// Reset all statistics.
  void reset() {
    bytesSent = 0;
    bytesReceived = 0;
    packetsSent = 0;
    packetsReceived = 0;
    packetsLost = 0;
  }
}
