import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
import 'transport.dart';

/// A datagram travelling through a [LoopbackNetwork].
class LoopbackDatagram {
  /// Address of the sending transport.
  final NetAddress source;

  /// Address the datagram was sent to.
  final NetAddress destination;

  /// Raw bytes (exactly what the sender passed to `send`).
  final Uint8List data;

  const LoopbackDatagram({
    required this.source,
    required this.destination,
    required this.data,
  });
}

/// Counters describing what a [LoopbackNetwork] did with its traffic.
class LoopbackStats {
  /// Datagrams handed to the network by any transport.
  int sent = 0;

  /// Datagrams delivered to a bound receiver (duplicates included).
  int delivered = 0;

  /// Datagrams dropped by random loss or the [LoopbackNetwork.filter].
  int dropped = 0;

  /// Extra copies created by [LoopbackNetwork.duplication].
  int duplicated = 0;

  /// Datagrams addressed to nobody (no transport bound at destination).
  int undeliverable = 0;
}

/// In-memory datagram network for running a host and N clients in one
/// process. This is the recommended way to test multiplayer code.
///
/// Create one network, then one [LoopbackTransport] per endpoint with
/// [createTransport]. Pass those transports to `NetworkHost` /
/// `NetworkClient` exactly as you would a `UdpTransport`. Transports find
/// each other by the address they bind to (`host` from [createTransport],
/// port from `bind`; port `0` picks an ephemeral port).
///
/// The network can simulate a bad link:
/// - [latency]: fixed one-way delay applied to every datagram.
/// - [jitter]: extra uniformly random delay in `[0, jitter]` (this also
///   reorders datagrams, like a real network).
/// - [packetLoss]: probability `0..1` that a datagram is dropped.
/// - [duplication]: probability `0..1` that a datagram is delivered twice.
/// - [filter]: deterministic per-datagram drop hook (e.g. "drop the first
///   connect packet").
///
/// All randomness comes from the injectable [Random], so a seeded network
/// reproduces exactly the same loss/jitter pattern on every run.
///
/// ## Delivery modes
///
/// **Real-time** (default, no `clock`): datagrams are delivered by
/// [Timer]s after their simulated delay. Zero-delay datagrams are handed
/// over immediately (listeners still observe them asynchronously, as with
/// a socket).
///
/// **Manual** (pass a [ManualNetClock]): nothing is delivered until you
/// call [advance] or [flush]. [advance] moves the clock forward, delivering
/// each due datagram at its exact delivery time and letting listeners react
/// (and send replies) before moving on. Give the same clock to
/// `NetworkHost(clock:)` / `NetworkClient(clock:)` and RTT, ping cadence
/// and retransmit timing become fully deterministic.
///
/// ```dart
/// final net = LoopbackNetwork(
///   latency: const Duration(milliseconds: 40),
///   jitter: const Duration(milliseconds: 10),
///   packetLoss: 0.05,
///   random: Random(42),
/// );
/// final host = NetworkHost(transport: net.createTransport());
/// await host.start(7777);
///
/// final client = NetworkClient(transport: net.createTransport());
/// await client.connect('127.0.0.1', 7777);
/// ```
class LoopbackNetwork {
  /// Fixed one-way latency added to every datagram.
  Duration latency;

  /// Maximum extra random one-way delay (uniform in `[0, jitter]`).
  Duration jitter;

  /// Probability (`0..1`) that a datagram is silently dropped.
  double packetLoss;

  /// Probability (`0..1`) that a datagram is delivered twice.
  double duplication;

  /// Optional per-datagram hook; return `false` to drop the datagram.
  ///
  /// Evaluated before random loss. Useful for deterministic scenarios such
  /// as dropping exactly the first handshake packet.
  bool Function(LoopbackDatagram datagram)? filter;

  /// Manual clock, or `null` in real-time mode.
  final ManualNetClock? clock;

  /// Traffic counters.
  final LoopbackStats stats = LoopbackStats();

  final Random _random;
  final Map<NetAddress, LoopbackTransport> _bound = {};
  final Set<Timer> _timers = {};
  final SplayTreeMap<(int, int), LoopbackDatagram> _queue = SplayTreeMap(
    _compareSlots,
  );
  int _queueSeq = 0;
  int _nextEphemeralPort = 49152;

  LoopbackNetwork({
    this.latency = Duration.zero,
    this.jitter = Duration.zero,
    this.packetLoss = 0,
    this.duplication = 0,
    this.filter,
    this.clock,
    Random? random,
  }) : _random = random ?? Random() {
    if (latency.isNegative || jitter.isNegative) {
      throw ArgumentError('latency and jitter must not be negative');
    }
    if (packetLoss < 0 || packetLoss > 1) {
      throw ArgumentError.value(packetLoss, 'packetLoss', 'must be in 0..1');
    }
    if (duplication < 0 || duplication > 1) {
      throw ArgumentError.value(duplication, 'duplication', 'must be in 0..1');
    }
  }

  static int _compareSlots((int, int) a, (int, int) b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  }

  /// Whether this network only delivers on [advance] / [flush].
  bool get isManual => clock != null;

  /// Number of datagrams scheduled but not yet delivered.
  int get inFlight => isManual ? _queue.length : _timers.length;

  /// Create a transport on this network that will bind on [host].
  ///
  /// Use distinct hosts (e.g. `'10.0.0.2'`) to simulate several machines;
  /// by default every transport lives on `127.0.0.1` and is distinguished
  /// by port.
  LoopbackTransport createTransport({
    String host = '127.0.0.1',
    int maxBufferedPackets = 1024,
  }) {
    return LoopbackTransport._(this, host, maxBufferedPackets);
  }

  /// Manual mode: advance the clock by [duration], delivering every
  /// datagram that falls due in that window, in delivery-time order.
  ///
  /// After each delivery the event loop is given a turn so receivers can
  /// handle the datagram and send replies; replies that fall due within
  /// the same window are delivered too.
  Future<void> advance(Duration duration) async {
    final clock = _requireManual('advance');
    final target = clock.nowMs + duration.inMilliseconds;
    // Let already-started work (e.g. an in-progress connect) send first.
    await _yield();
    while (_queue.isNotEmpty && _queue.firstKey()!.$1 <= target) {
      _deliverNextQueued(clock);
      await _yield();
    }
    if (target > clock.nowMs) clock.nowMs = target;
    await _yield();
  }

  /// Manual mode: deliver everything currently queued (and any replies it
  /// triggers), advancing the clock to each delivery time.
  ///
  /// Stops after [maxDeliveries] to avoid spinning forever on a reply loop.
  Future<void> flush({int maxDeliveries = 10000}) async {
    final clock = _requireManual('flush');
    await _yield();
    var delivered = 0;
    while (_queue.isNotEmpty && delivered++ < maxDeliveries) {
      _deliverNextQueued(clock);
      await _yield();
    }
  }

  /// Cancel every in-flight datagram.
  void clearInFlight() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _queue.clear();
  }

  // Internals ---------------------------------------------------------------

  ManualNetClock _requireManual(String method) {
    final c = clock;
    if (c == null) {
      throw StateError('$method() requires a manual LoopbackNetwork (clock:)');
    }
    return c;
  }

  static Future<void> _yield() => Future<void>.delayed(Duration.zero);

  void _deliverNextQueued(ManualNetClock clock) {
    final key = _queue.firstKey()!;
    final datagram = _queue.remove(key)!;
    if (key.$1 > clock.nowMs) clock.nowMs = key.$1;
    _deliver(datagram);
  }

  NetAddress _bind(LoopbackTransport transport, String host, int port) {
    var actualPort = port;
    if (actualPort == 0) {
      while (_bound.containsKey(NetAddress(host, _nextEphemeralPort))) {
        _nextEphemeralPort++;
      }
      actualPort = _nextEphemeralPort++;
    }
    final address = NetAddress(host, actualPort);
    if (_bound.containsKey(address)) {
      throw StateError('Address already in use: $address');
    }
    _bound[address] = transport;
    return address;
  }

  void _unbind(NetAddress address, LoopbackTransport transport) {
    if (identical(_bound[address], transport)) _bound.remove(address);
  }

  void _send(NetAddress source, NetAddress destination, Uint8List data) {
    stats.sent++;
    final datagram = LoopbackDatagram(
      source: source,
      destination: destination,
      // Copy so later mutation by the sender cannot affect the wire bytes.
      data: Uint8List.fromList(data),
    );

    final hook = filter;
    if (hook != null && !hook(datagram)) {
      stats.dropped++;
      return;
    }
    if (packetLoss > 0 && _random.nextDouble() < packetLoss) {
      stats.dropped++;
      return;
    }

    _schedule(datagram);
    if (duplication > 0 && _random.nextDouble() < duplication) {
      stats.duplicated++;
      _schedule(datagram);
    }
  }

  Duration _sampleDelay() {
    if (jitter == Duration.zero) return latency;
    final extra = _random.nextInt(jitter.inMicroseconds + 1);
    return latency + Duration(microseconds: extra);
  }

  void _schedule(LoopbackDatagram datagram) {
    final delay = _sampleDelay();
    final manual = clock;
    if (manual != null) {
      final at = manual.nowMs + delay.inMilliseconds;
      _queue[(at, _queueSeq++)] = datagram;
      return;
    }
    if (delay == Duration.zero) {
      _deliver(datagram);
      return;
    }
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      _deliver(datagram);
    });
    _timers.add(timer);
  }

  void _deliver(LoopbackDatagram datagram) {
    final receiver = _bound[datagram.destination];
    if (receiver == null) {
      stats.undeliverable++;
      return;
    }
    stats.delivered++;
    receiver._receive(
      ReceivedPacket(
        source: datagram.source,
        data: Uint8List.fromList(datagram.data),
      ),
    );
  }
}

/// [Transport] endpoint on a [LoopbackNetwork]. Create one with
/// [LoopbackNetwork.createTransport].
///
/// Follows the [Transport] delivery contract: each received datagram is
/// delivered exactly once, to [onReceive] listeners when any are attached,
/// otherwise into a bounded buffer drained by [receive].
class LoopbackTransport extends Transport {
  /// The network this transport belongs to.
  final LoopbackNetwork network;

  /// Host part of the address this transport binds on.
  final String host;

  /// Maximum datagrams retained for [receive] while nobody listens to
  /// [onReceive]. Oldest datagrams are dropped first.
  final int maxBufferedPackets;

  ConnectionState _state = ConnectionState.disconnected;
  NetAddress? _localAddress;
  final _receiveController = StreamController<ReceivedPacket>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  final Queue<ReceivedPacket> _buffer = Queue();
  int _bufferOverflowCount = 0;

  LoopbackTransport._(this.network, this.host, this.maxBufferedPackets) {
    if (maxBufferedPackets < 0) {
      throw ArgumentError.value(
        maxBufferedPackets,
        'maxBufferedPackets',
        'must not be negative',
      );
    }
  }

  @override
  ConnectionState get state => _state;

  @override
  NetAddress? get localAddress => _localAddress;

  @override
  Stream<ReceivedPacket> get onReceive => _receiveController.stream;

  @override
  Stream<ConnectionState> get onStateChange => _stateController.stream;

  /// Datagrams discarded because the [receive] buffer was full.
  int get bufferOverflowCount => _bufferOverflowCount;

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  @override
  Future<void> bind(int port) async {
    if (_state != ConnectionState.disconnected || _receiveController.isClosed) {
      throw StateError('Transport already bound or closed');
    }
    _localAddress = network._bind(this, host, port);
    _setState(ConnectionState.connected);
  }

  @override
  Future<void> close() async {
    final address = _localAddress;
    if (address != null) network._unbind(address, this);
    _localAddress = null;
    _buffer.clear();
    _setState(ConnectionState.disconnected);
    await _receiveController.close();
    await _stateController.close();
  }

  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    final local = _localAddress;
    if (local == null || _state != ConnectionState.connected) {
      throw StateError('Transport not connected');
    }
    network._send(local, address, data);
  }

  @override
  List<ReceivedPacket> receive() {
    final packets = _buffer.toList();
    _buffer.clear();
    return packets;
  }

  /// Deliver [data] to this transport as if it had arrived from [source],
  /// bypassing the network's latency and loss simulation.
  void inject(NetAddress source, Uint8List data) {
    _receive(ReceivedPacket(source: source, data: Uint8List.fromList(data)));
  }

  void _receive(ReceivedPacket packet) {
    if (_receiveController.isClosed) return;
    if (_receiveController.hasListener) {
      _receiveController.add(packet);
      return;
    }
    _buffer.add(packet);
    while (_buffer.length > maxBufferedPackets) {
      _buffer.removeFirst();
      _bufferOverflowCount++;
    }
  }
}
