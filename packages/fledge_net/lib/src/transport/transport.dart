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
/// Implementations provide specific protocols (UDP, WebSocket, etc.)
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

  /// Receive pending packets.
  ///
  /// Returns an empty list if no packets are available.
  List<ReceivedPacket> receive();

  /// Stream of received packets.
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
