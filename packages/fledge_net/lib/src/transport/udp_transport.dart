import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'transport.dart';

/// UDP socket transport for low-latency game networking.
///
/// UDP is preferred for real-time games because:
/// - No head-of-line blocking
/// - Lower latency than TCP
/// - Packet loss is handled at application level
///
/// Follows the [Transport] delivery contract: datagrams go to [onReceive]
/// listeners when any are attached, otherwise into a buffer of at most
/// [maxBufferedPackets] drained by [receive].
///
/// IPv4 only for now: the socket binds an IPv4 address and destination
/// hosts must be numeric IPv4 addresses (`NetworkClient.connect` resolves
/// hostnames for you).
class UdpTransport extends Transport {
  /// Address to bind on. Defaults to all IPv4 interfaces.
  final InternetAddress bindAddress;

  /// Maximum datagrams retained for [receive] while nobody listens to
  /// [onReceive]. Oldest datagrams are dropped first.
  final int maxBufferedPackets;

  /// Maximum outgoing datagrams queued while the OS send buffer is full.
  /// Oldest datagrams are dropped first (counted in
  /// [TransportStats.packetsLost]).
  final int maxQueuedSends;

  RawDatagramSocket? _socket;
  ConnectionState _state = ConnectionState.disconnected;
  NetAddress? _localAddress;
  final TransportStats _stats = TransportStats();

  final _receiveController = StreamController<ReceivedPacket>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final Queue<ReceivedPacket> _pendingPackets = Queue();
  final Queue<_OutboundDatagram> _outbound = Queue();
  int _bufferOverflowCount = 0;

  UdpTransport({
    InternetAddress? bindAddress,
    this.maxBufferedPackets = 1024,
    this.maxQueuedSends = 1024,
  }) : bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  /// Transport statistics.
  TransportStats get stats => _stats;

  /// Received datagrams discarded because the [receive] buffer was full.
  int get bufferOverflowCount => _bufferOverflowCount;

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
      _socket = await RawDatagramSocket.bind(bindAddress, port);
      _localAddress = NetAddress(_socket!.address.address, _socket!.port);

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
      // Read events can coalesce, so drain everything that's queued.
      Datagram? datagram;
      while ((datagram = _socket?.receive()) != null) {
        _deliver(
          ReceivedPacket(
            source: NetAddress(datagram!.address.address, datagram.port),
            data: Uint8List.fromList(datagram.data),
          ),
        );
      }
    } else if (event == RawSocketEvent.write) {
      _flushOutbound();
    }
  }

  void _deliver(ReceivedPacket packet) {
    _stats.packetsReceived++;
    _stats.bytesReceived += packet.data.length;

    if (_receiveController.isClosed) return;
    if (_receiveController.hasListener) {
      _receiveController.add(packet);
      return;
    }
    _pendingPackets.add(packet);
    while (_pendingPackets.length > maxBufferedPackets) {
      _pendingPackets.removeFirst();
      _bufferOverflowCount++;
    }
  }

  /// Try to send everything queued while the socket was not writable.
  void _flushOutbound() {
    final socket = _socket;
    if (socket == null) return;
    while (_outbound.isNotEmpty) {
      final next = _outbound.first;
      final sent = socket.send(next.data, next.address, next.port);
      if (sent == 0) {
        // Still would-block: wait for the next write event.
        socket.writeEventsEnabled = true;
        return;
      }
      _outbound.removeFirst();
      _stats.packetsSent++;
      _stats.bytesSent += next.data.length;
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
    _pendingPackets.clear();
    _outbound.clear();
    _setState(ConnectionState.disconnected);
    await _receiveController.close();
    await _stateController.close();
  }

  /// Send [data] to [address].
  ///
  /// [NetAddress.host] must be a numeric IPv4 address. If the OS send
  /// buffer is momentarily full the datagram is queued (up to
  /// [maxQueuedSends]) and sent when the socket becomes writable, instead
  /// of being silently dropped.
  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    final socket = _socket;
    if (socket == null || _state != ConnectionState.connected) {
      throw StateError('Transport not connected');
    }

    final target = InternetAddress(address.host);
    if (_outbound.isEmpty) {
      final sent = socket.send(data, target, address.port);
      if (sent > 0) {
        _stats.packetsSent++;
        _stats.bytesSent += data.length;
        return;
      }
    }

    _outbound.add(
      _OutboundDatagram(target, address.port, Uint8List.fromList(data)),
    );
    while (_outbound.length > maxQueuedSends) {
      _outbound.removeFirst();
      _stats.packetsLost++;
    }
    socket.writeEventsEnabled = true;
  }

  @override
  List<ReceivedPacket> receive() {
    final packets = _pendingPackets.toList();
    _pendingPackets.clear();
    return packets;
  }
}

class _OutboundDatagram {
  final InternetAddress address;
  final int port;
  final Uint8List data;
  _OutboundDatagram(this.address, this.port, this.data);
}
