import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../protocol/net_clock.dart';
import '../transport/transport.dart';
import '../transport/udp_transport.dart';
import 'lan_beacon.dart';

/// Makes the transport an advertiser or browser sends and receives
/// beacons on (bound by them). Defaults to a broadcast-enabled
/// [UdpTransport]; tests pass `LoopbackNetwork.createTransport`.
typedef DiscoveryTransportFactory = Transport Function();

/// The addresses an advertiser sends each beacon to.
typedef DiscoveryTargets = Future<List<String>> Function();

/// LAN host discovery, so players can pick a host on their own network
/// instead of typing its address.
///
/// A host that accepts players over direct IP runs a [LanAdvertiser]: a
/// small [LanBeacon] datagram (the game's app id, the game port and an
/// opaque payload) broadcast to [defaultPort] about twice a second. A
/// player looking for games runs a [LanBrowser] on that port, which lists
/// the hosts it hears ([LanHost]) and forgets one not heard for a few
/// seconds.
///
/// Only the local network sees beacons (IPv4 broadcast stops at routers).
/// They are plaintext and unauthenticated, so a payload is for display
/// only; joining a listed host goes through the normal handshake.
///
/// Neither class throws on socket errors: they're logged (`dart:developer`,
/// name `fledge_net.discovery`) and reported to `onError`, and the browser's
/// list stays empty while it can't listen. Desktop first; the web has no
/// UDP (like the rest of `fledge_net`).
abstract final class LanDiscovery {
  /// The UDP port beacons are sent to and browsers listen on, shared by
  /// every game (each filters by app id). Keep it apart from game ports.
  static const int defaultPort = 47776;

  /// How often an advertiser sends a beacon by default.
  static const Duration defaultInterval = Duration(milliseconds: 500);

  /// How long a browser keeps a host it no longer hears, by default.
  static const Duration defaultExpiry = Duration(seconds: 5);

  /// Where an advertiser sends beacons by default: the limited broadcast
  /// address, `127.0.0.1` (other copies on this machine) and, for each
  /// non-loopback IPv4 interface, its subnet's broadcast address assuming
  /// a /24 (`dart:io` doesn't report netmasks), since some systems send
  /// `255.255.255.255` out of one interface only. Never throws.
  static Future<List<String>> broadcastTargets() async {
    final targets = <String>{'255.255.255.255', '127.0.0.1'};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.isLoopback || address.isLinkLocal) continue;
          final bytes = address.rawAddress;
          if (bytes.length != 4) continue;
          targets.add('${bytes[0]}.${bytes[1]}.${bytes[2]}.255');
        }
      }
    } on Object catch (e) {
      _log('listing network interfaces failed: $e');
    }
    return targets.toList();
  }

  static Transport _udp() =>
      UdpTransport(broadcast: true, reusePort: true, maxBufferedPackets: 64);
}

void _log(String message) =>
    developer.log(message, name: 'fledge_net.discovery');

/// Broadcasts a [LanBeacon] for a host on the local network while it's
/// accepting players (see [LanDiscovery]).
///
/// ```dart
/// final advertiser = LanAdvertiser(
///   appId: 'my-game',
///   gamePort: 7777,
///   payload: utf8.encode('{"name":"Red Acre"}'),
/// );
/// await advertiser.start(); // after session.host(port: 7777)
/// advertiser.payload = utf8.encode('{"name":"Red Acre","players":2}');
/// await advertiser.stop(); // when hosting stops
/// ```
class LanAdvertiser {
  /// The game's id; only browsers with the same id list this host.
  final String appId;

  /// The game port players join on.
  final int gamePort;

  /// Where beacons go: browsers listen on this port.
  final int discoveryPort;

  /// How often a beacon goes out while running.
  final Duration interval;

  final DiscoveryTransportFactory _transportFactory;
  final DiscoveryTargets _targets;
  final void Function(Object error)? _onError;
  final Duration _targetsRefresh;
  final int _instance;

  Uint8List _payload;
  Transport? _transport;
  Future<Transport?>? _binding;
  Timer? _timer;
  bool _running = false;
  List<String>? _cachedTargets;
  DateTime? _targetsAt;
  int _beaconsSent = 0;
  bool _reportedSendError = false;

  /// Creates an advertiser for a host on [gamePort].
  ///
  /// [targets] lists the addresses beacons go to (default
  /// [LanDiscovery.broadcastTargets], refreshed every [targetsRefresh] so
  /// a network joined later is covered). Throws [ArgumentError] for an
  /// invalid [appId], [gamePort] or [payload] (see [LanBeacon]).
  LanAdvertiser({
    required this.appId,
    required this.gamePort,
    Uint8List? payload,
    this.discoveryPort = LanDiscovery.defaultPort,
    this.interval = LanDiscovery.defaultInterval,
    DiscoveryTransportFactory? transportFactory,
    DiscoveryTargets? targets,
    Duration targetsRefresh = const Duration(seconds: 5),
    void Function(Object error)? onError,
    Random? random,
  }) : _payload = payload ?? Uint8List(0),
       _transportFactory = transportFactory ?? LanDiscovery._udp,
       _targets = targets ?? LanDiscovery.broadcastTargets,
       _targetsRefresh = targetsRefresh,
       _onError = onError,
       _instance = (random ?? Random.secure()).nextInt(1 << 32) {
    // Validates everything a beacon needs, so start() can't fail on it.
    _beacon();
  }

  /// The payload the next beacons carry. Setting it takes effect with the
  /// next beacon; throws [ArgumentError] above [LanBeacon.maxPayloadBytes].
  Uint8List get payload => _payload;
  set payload(Uint8List value) {
    LanBeacon.checkPayload(value);
    _payload = Uint8List.fromList(value);
  }

  /// Whether it's advertising ([start] called, [stop] not yet).
  bool get isRunning => _running;

  /// Beacons sent so far (one per target per announcement).
  int get beaconsSent => _beaconsSent;

  /// This run's [LanBeacon.instance].
  int get instance => _instance;

  LanBeacon _beacon({bool leaving = false}) => LanBeacon(
    appId: appId,
    port: gamePort,
    instance: _instance,
    leaving: leaving,
    payload: _payload,
  );

  /// Starts advertising: a beacon now, then one every [interval]. Never
  /// throws for socket errors (it keeps trying each interval).
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(interval, (_) => announce());
    await announce();
  }

  /// Sends one beacon to every target now, between the timer's (does
  /// nothing unless running). Never throws.
  Future<void> announce() async {
    if (_running) await _send(_beacon());
  }

  Future<void> _send(LanBeacon beacon) async {
    final transport = await _bound();
    if (transport == null) return;
    final data = beacon.encode();
    for (final target in await _currentTargets()) {
      try {
        await transport.send(NetAddress(target, discoveryPort), data);
        _beaconsSent++;
      } on Object catch (e) {
        // One unreachable target (no route, a down interface) is normal;
        // report the first failure only, and keep the rest going.
        if (!_reportedSendError) {
          _reportedSendError = true;
          _report('beacon to $target failed: $e', e);
        }
        if (transport.state != ConnectionState.connected) {
          await _drop();
          return;
        }
      }
    }
  }

  Future<List<String>> _currentTargets() async {
    final at = _targetsAt;
    final now = DateTime.now();
    if (_cachedTargets == null ||
        at == null ||
        now.difference(at) >= _targetsRefresh) {
      try {
        _cachedTargets = await _targets();
      } on Object catch (e) {
        _report('listing beacon targets failed: $e', e);
        _cachedTargets ??= const ['255.255.255.255'];
      }
      _targetsAt = now;
    }
    return _cachedTargets!;
  }

  Future<Transport?> _bound() {
    final existing = _transport;
    if (existing != null) return Future.value(existing);
    // One bind at a time: a beacon due while binding waits for it.
    return _binding ??= _bind().whenComplete(() => _binding = null);
  }

  Future<Transport?> _bind() async {
    final transport = _transportFactory();
    try {
      await transport.bind(0);
    } on Object catch (e) {
      _report('opening the beacon socket failed: $e', e);
      try {
        await transport.close();
      } on Object {
        // Already unusable.
      }
      return null;
    }
    if (!_running) {
      // Stopped while binding.
      await transport.close();
      return null;
    }
    return _transport = transport;
  }

  Future<void> _drop() async {
    final transport = _transport;
    _transport = null;
    try {
      await transport?.close();
    } on Object {
      // Closing a failed socket can fail too.
    }
  }

  void _report(String message, Object error) {
    _log(message);
    _onError?.call(error);
  }

  /// Stops advertising, sending a last "leaving" beacon so browsers drop
  /// the host at once. Never throws.
  Future<void> stop() async {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    if (_transport != null) await _send(_beacon(leaving: true));
    _running = false;
    await _drop();
  }
}

/// Listens for [LanBeacon]s of one game and keeps the list of hosts heard
/// in the last [expiry] (see [LanDiscovery]).
///
/// ```dart
/// final browser = LanBrowser(appId: 'my-game');
/// browser.onChanged.listen((hosts) {
///   for (final h in hosts) print('${h.address}: ${h.payloadText}');
/// });
/// await browser.start();
/// // ...
/// await browser.stop();
/// ```
class LanBrowser {
  /// The game's id: beacons with another id are ignored.
  final String appId;

  /// The port beacons arrive on.
  final int discoveryPort;

  /// How long a host stays listed after its last beacon.
  final Duration expiry;

  /// Most hosts listed at once; beacons from further hosts are ignored.
  final int maxHosts;

  /// How often to try again while the port can't be opened, and how often
  /// expired hosts are dropped.
  final Duration retryInterval;

  final NetClock _clock;
  final DiscoveryTransportFactory _transportFactory;
  final void Function(Object error)? _onError;

  final Map<int, LanHost> _hosts = {};
  final _changes = StreamController<List<LanHost>>.broadcast();
  Transport? _transport;
  StreamSubscription<ReceivedPacket>? _subscription;
  Timer? _timer;
  bool _running = false;
  bool _binding = false;
  bool _reportedBindError = false;
  int _ignored = 0;

  /// Creates a browser for [appId]'s hosts. Throws [ArgumentError] for an
  /// invalid [appId] (see [LanBeacon]).
  LanBrowser({
    required this.appId,
    this.discoveryPort = LanDiscovery.defaultPort,
    this.expiry = LanDiscovery.defaultExpiry,
    this.maxHosts = 32,
    this.retryInterval = const Duration(seconds: 1),
    NetClock? clock,
    DiscoveryTransportFactory? transportFactory,
    void Function(Object error)? onError,
  }) : _clock = clock ?? NetClock.system,
       _transportFactory = transportFactory ?? LanDiscovery._udp,
       _onError = onError {
    LanBeacon.checkAppId(appId);
  }

  /// The hosts heard within [expiry], in the order they were first heard.
  List<LanHost> get hosts {
    prune();
    return List.unmodifiable(_hosts.values);
  }

  /// The host list whenever it changes: a host found, its payload or
  /// address changed, or one gone (expired or leaving).
  Stream<List<LanHost>> get onChanged => _changes.stream;

  /// Whether it's started ([start] called, [stop] not yet).
  bool get isRunning => _running;

  /// Whether the discovery port is open and beacons can arrive.
  bool get isListening => _transport != null;

  /// Datagrams ignored: malformed, another game's, too big, or from a host
  /// over [maxHosts].
  int get ignoredDatagrams => _ignored;

  /// Starts listening. Never throws: if the port can't be opened it's
  /// retried every [retryInterval], and the list stays empty meanwhile.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(retryInterval, (_) {
      prune();
      if (_transport == null) _listen();
    });
    await _listen();
  }

  Future<void> _listen() async {
    if (_binding || _transport != null || !_running) return;
    _binding = true;
    final transport = _transportFactory();
    try {
      await transport.bind(discoveryPort);
    } on Object catch (e) {
      if (!_reportedBindError) {
        _reportedBindError = true;
        _log('listening on port $discoveryPort failed: $e');
        _onError?.call(e);
      }
      try {
        await transport.close();
      } on Object {
        // Already unusable.
      }
      _binding = false;
      return;
    }
    _binding = false;
    if (!_running) {
      await transport.close();
      return;
    }
    _transport = transport;
    _subscription = transport.onReceive.listen(_receive);
    transport.onStateChange.listen((state) {
      if (state == ConnectionState.failed && identical(_transport, transport)) {
        _log('discovery socket failed; reopening');
        _close();
      }
    });
  }

  void _receive(ReceivedPacket packet) {
    final beacon = LanBeacon.tryDecode(packet.data);
    final source = InternetAddress.tryParse(packet.source.host);
    if (beacon == null ||
        beacon.appId != appId ||
        source == null ||
        source.type != InternetAddressType.IPv4) {
      _ignored++;
      return;
    }
    final now = _clock.nowMs;
    final known = _hosts[beacon.instance];
    if (known != null) {
      // The same host heard on another interface: keep the first address,
      // except a LAN one beats loopback (both reach a copy on this machine).
      final sameAddress = known.host == packet.source.host;
      final better =
          !sameAddress &&
          InternetAddress(known.host).isLoopback &&
          !source.isLoopback;
      if (!sameAddress && !better) return;
      if (beacon.leaving) {
        _hosts.remove(beacon.instance);
        _emit();
        return;
      }
      final changed =
          better ||
          known.port != beacon.port ||
          !_sameBytes(known.payload, beacon.payload);
      _hosts[beacon.instance] = LanHost(
        address: NetAddress(packet.source.host, beacon.port),
        instance: beacon.instance,
        payload: beacon.payload,
        firstSeenMs: known.firstSeenMs,
        lastSeenMs: now,
      );
      if (changed) _emit();
      return;
    }
    if (beacon.leaving) return;
    if (_hosts.length >= maxHosts) {
      _ignored++;
      return;
    }
    _hosts[beacon.instance] = LanHost(
      address: NetAddress(packet.source.host, beacon.port),
      instance: beacon.instance,
      payload: beacon.payload,
      firstSeenMs: now,
      lastSeenMs: now,
    );
    _emit();
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Drops hosts not heard within [expiry] (also done on a timer and when
  /// reading [hosts]).
  void prune() {
    final cutoff = _clock.nowMs - expiry.inMilliseconds;
    final before = _hosts.length;
    _hosts.removeWhere((_, h) => h.lastSeenMs < cutoff);
    if (_hosts.length != before) _emit();
  }

  /// Forgets every host heard so far.
  void clear() {
    if (_hosts.isEmpty) return;
    _hosts.clear();
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_hosts.values));
  }

  Future<void> _close() async {
    final transport = _transport;
    _transport = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await transport?.close();
    } on Object {
      // Closing a failed socket can fail too.
    }
  }

  /// Stops listening and forgets every host. Never throws. A stopped
  /// browser can be started again.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _close();
    clear();
  }

  /// Stops and closes [onChanged] for good.
  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }
}
