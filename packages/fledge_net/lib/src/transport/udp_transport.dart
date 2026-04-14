import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'transport.dart';

/// UDP socket transport for low-latency game networking.
///
/// UDP is preferred for real-time games because:
/// - No head-of-line blocking
/// - Lower latency than TCP
/// - Packet loss is handled at application level
class UdpTransport extends Transport {
  RawDatagramSocket? _socket;
  ConnectionState _state = ConnectionState.disconnected;
  NetAddress? _localAddress;
  final TransportStats _stats = TransportStats();

  final _receiveController = StreamController<ReceivedPacket>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final List<ReceivedPacket> _pendingPackets = [];

  /// Transport statistics.
  TransportStats get stats => _stats;

  @override
  ConnectionState get state => _state;

  @override
  NetAddress? get localAddress => _localAddress;

  @override
  Stream<ReceivedPacket> get onReceive => _receiveController.stream;

  @override
  Stream<ConnectionState> get onStateChange => _stateController.stream;

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  @override
  Future<void> bind(int port) async {
    if (_state != ConnectionState.disconnected) {
      throw StateError('Transport already bound or connecting');
    }

    _setState(ConnectionState.connecting);

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _localAddress = NetAddress(
        _socket!.address.address,
        _socket!.port,
      );

      _socket!.listen(
        _handleSocketEvent,
        onError: _handleError,
        onDone: _handleDone,
      );

      _setState(ConnectionState.connected);
    } catch (e) {
      _setState(ConnectionState.failed);
      rethrow;
    }
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram != null) {
        final packet = ReceivedPacket(
          source: NetAddress(
            datagram.address.address,
            datagram.port,
          ),
          data: Uint8List.fromList(datagram.data),
        );

        _stats.packetsReceived++;
        _stats.bytesReceived += datagram.data.length;

        _pendingPackets.add(packet);
        _receiveController.add(packet);
      }
    }
  }

  void _handleError(Object error) {
    _setState(ConnectionState.failed);
  }

  void _handleDone() {
    _setState(ConnectionState.disconnected);
  }

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
    _localAddress = null;
    _setState(ConnectionState.disconnected);
    await _receiveController.close();
    await _stateController.close();
  }

  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    if (_socket == null || _state != ConnectionState.connected) {
      throw StateError('Transport not connected');
    }

    final sent = _socket!.send(
      data,
      InternetAddress(address.host),
      address.port,
    );

    if (sent > 0) {
      _stats.packetsSent++;
      _stats.bytesSent += data.length;
    }
  }

  @override
  List<ReceivedPacket> receive() {
    final packets = List<ReceivedPacket>.from(_pendingPackets);
    _pendingPackets.clear();
    return packets;
  }
}
