import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:meta/meta.dart';

import '../protocol/packet.dart';
import 'codec.dart';
import 'events.dart';
import 'inputs.dart';

/// Returns the **global** (world-space) 2D position of [entity], or `null`
/// if it has none. Used for interest management.
typedef PositionGetter = (double, double)? Function(World world, Entity entity);

/// Declares what the replication layer sends over the network: component
/// types, the input type, prediction steps and RPC types.
///
/// Host and clients must build **identical** registries (same keys, same
/// order); the handshake compares a [schemaHash] and refuses mismatches.
/// Pass the registry to `NetworkPlugin(replication: ...)`; it is frozen
/// when the plugin is built.
///
/// fledge_net is pure Dart and does not know about `Transform2D` or
/// `GlobalTransform2D` (they live in the Flutter-based
/// `fledge_render_2d`), so the app registers a codec for its transform and
/// supplies [positionOf]:
///
/// ```dart
/// final replication = ReplicationRegistry()
///   ..component<Transform2D>('transform', transformCodec,
///       interpolate: (a, b, t) => lerpTransform(a, b, t))
///   ..component<Health>('health', healthCodec)
///   ..input<MoveInput>(moveInputCodec)
///   ..predict<Transform2D, MoveInput>(
///       step: (state, input, dt) => movedBy(state, input, dt),
///       error: (a, b) => (a.translation - b.translation).length)
///   ..rpc<Emote>('emote', emoteCodec)
///   ..positionOf = (world, e) {
///     final g = world.get<GlobalTransform2D>(e);
///     return g == null ? null : (g.translation.x, g.translation.y);
///   };
/// ```
///
/// Replicate the **local** transform (the one relative to the parent);
/// never register a global/world transform, clients recompute it from the
/// replicated hierarchy (e.g. with `TransformPropagateSystem`).
class ReplicationRegistry {
  final List<ComponentReplicator<Object?>> _components = [];
  final Map<Type, ComponentReplicator<Object?>> _componentsByType = {};
  InputReplicator<Object?>? _input;
  final List<PredictionReplicator> _predictions = [];
  final List<RpcReplicator<Object?>> _rpcs = [];
  final Map<Type, RpcReplicator<Object?>> _rpcsByType = {};
  bool _frozen = false;

  /// Maximum number of replicated component types.
  static const int maxComponents = 32;

  /// Global position of an entity for interest management (see
  /// `NetworkConfig.interestRadius`). Entities for which it returns `null`
  /// are always relevant. When `null`, interest management is disabled.
  PositionGetter? positionOf;

  /// Register component type [T] for replication under [key].
  ///
  /// With [interpolate], clients render entities they do not own between
  /// two snapshots (keyed by server tick, `interpolationDelay` behind)
  /// instead of snapping to each snapshot. It must return a new value.
  /// When snapshots are lost or late it is also called with `t > 1` to
  /// extrapolate (bounded by `NetworkConfig.maxExtrapolation`); clamp `t`
  /// if the type cannot extrapolate.
  ///
  /// **Inside an extension on `ReplicationRegistry`**, call this as
  /// `this.component<T>(...)`: a bare `component<T>(...)` resolves to the
  /// top-level `component` annotation constant exported by `fledge_ecs`
  /// (lexical scope wins over the extension's `this`) and fails to
  /// compile. Cascades (`registry..component<T>(...)`) are unaffected.
  void component<T>(
    String key,
    NetCodec<T> codec, {
    T Function(T from, T to, double t)? interpolate,
  }) {
    _checkMutable();
    if (_componentsByType.containsKey(T)) {
      throw ArgumentError('Component type $T is already registered');
    }
    if (_components.any((c) => c.key == key)) {
      throw ArgumentError.value(key, 'key', 'already registered');
    }
    if (_components.length >= maxComponents) {
      throw StateError('At most $maxComponents replicated component types');
    }
    final rep = ComponentReplicator<T>(
      index: _components.length,
      key: key,
      codec: codec,
      interpolate: interpolate,
    );
    _components.add(rep);
    _componentsByType[T] = rep;
  }

  /// Register the input type [I] that clients send for entities they own
  /// (one input type per registry).
  void input<I>(NetCodec<I> codec) {
    _checkMutable();
    if (_input != null) throw StateError('An input type is already registered');
    _input = InputReplicator<I>(codec);
  }

  /// Predict component [S] (already registered with [component]) on the
  /// owning client by applying [step] to each input [I].
  ///
  /// [step] must be **pure and deterministic**: it receives the current
  /// state, the input and `FixedTimestep.stepSeconds`, must not mutate
  /// `state`, and returns the new state. The host applies the same [step]
  /// to every entity with an input that tick (in `NetPredictSystem`), so
  /// host and owning client compute the same result.
  ///
  /// [error] measures the difference between two states; when the
  /// server state for an acknowledged tick differs from the prediction for
  /// that tick by more than [tolerance] the client snaps to the server
  /// state and replays its unacknowledged inputs. With [correctionBlend]
  /// below 1 (requires `interpolate` on the component registration) the
  /// corrected state is blended in from the mispredicted one instead
  /// (`lerp(predicted, corrected, correctionBlend)`), which smooths
  /// corrections visually; later snapshots converge the remainder.
  void predict<S, I>({
    required S Function(S state, I input, double dt) step,
    required double Function(S a, S b) error,
    double tolerance = 0.01,
    double correctionBlend = 1.0,
  }) {
    _checkMutable();
    final input = _input;
    if (input == null || input is! InputReplicator<I>) {
      throw StateError('Call input<$I>() before predict<$S, $I>()');
    }
    final component = _componentsByType[S];
    if (component == null || component is! ComponentReplicator<S>) {
      throw StateError('Register component<$S>() before predict<$S, $I>()');
    }
    if (correctionBlend <= 0 || correctionBlend > 1) {
      throw ArgumentError.value(
        correctionBlend,
        'correctionBlend',
        '0 < x <= 1',
      );
    }
    if (correctionBlend < 1 && !component.interpolated) {
      throw ArgumentError(
        'correctionBlend < 1 needs an interpolate function on $S',
      );
    }
    if (_predictions.any((p) => p.component == component)) {
      throw ArgumentError('$S is already predicted');
    }
    _predictions.add(
      TypedPredictionReplicator<S, I>(
        component: component,
        step: step,
        errorFn: error,
        tolerance: tolerance,
        correctionBlend: correctionBlend,
      ),
    );
  }

  /// Register RPC payload type [T] under [key]. Received RPCs are
  /// delivered as `NetRpcReceived<T>` ECS events.
  void rpc<T>(String key, NetCodec<T> codec) {
    _checkMutable();
    if (_rpcsByType.containsKey(T)) {
      throw ArgumentError('RPC type $T is already registered');
    }
    if (_rpcs.any((r) => r.key == key)) {
      throw ArgumentError.value(key, 'key', 'already registered');
    }
    final rep = RpcReplicator<T>(index: _rpcs.length, key: key, codec: codec);
    _rpcs.add(rep);
    _rpcsByType[T] = rep;
  }

  /// Whether the registry can no longer be modified.
  bool get isFrozen => _frozen;

  /// 32-bit FNV-1a hash of the registered keys, in order.
  int get schemaHash {
    final b = StringBuffer();
    for (final c in _components) {
      b.write('c:${c.key}${c.interpolated ? '~' : ''};');
    }
    if (_input != null) b.write('i;');
    for (final p in _predictions) {
      b.write('p:${p.component.key};');
    }
    for (final r in _rpcs) {
      b.write('r:${r.key};');
    }
    var hash = 0x811c9dc5;
    for (final unit in b.toString().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  void _checkMutable() {
    if (_frozen) {
      throw StateError(
        'ReplicationRegistry is frozen once NetworkPlugin is built; '
        'register everything before addPlugin',
      );
    }
  }

  // Internal accessors -------------------------------------------------------

  /// Freeze the registry (called by `NetworkPlugin.build`).
  @internal
  void freeze() => _frozen = true;

  /// Registered components, in index order.
  @internal
  List<ComponentReplicator<Object?>> get components =>
      List.unmodifiable(_components);

  /// Component registration for [type], if any.
  @internal
  ComponentReplicator<Object?>? componentFor(Type type) =>
      _componentsByType[type];

  /// The input registration, if any.
  @internal
  InputReplicator<Object?>? get inputReplicator => _input;

  /// Prediction registrations.
  @internal
  List<PredictionReplicator> get predictions => List.unmodifiable(_predictions);

  /// Prediction registration for component [index], if any.
  @internal
  PredictionReplicator? predictionFor(int index) {
    for (final p in _predictions) {
      if (p.component.index == index) return p;
    }
    return null;
  }

  /// RPC registrations, in index order.
  @internal
  List<RpcReplicator<Object?>> get rpcs => List.unmodifiable(_rpcs);

  /// RPC registration for [type], if any.
  @internal
  RpcReplicator<Object?>? rpcFor(Type type) => _rpcsByType[type];
}

/// Type-erased access to one replicated component type.
@internal
class ComponentReplicator<T> {
  final int index;
  final String key;
  final NetCodec<T> codec;
  final T Function(T from, T to, double t)? interpolate;

  ComponentReplicator({
    required this.index,
    required this.key,
    required this.codec,
    this.interpolate,
  });

  int get bit => 1 << index;

  ComponentId get componentId => ComponentId.of<T>();

  bool get interpolated => interpolate != null;

  bool has(World world, Entity entity) => world.has<T>(entity);

  Object? get(World world, Entity entity) => world.get<T>(entity);

  Uint8List encodeFrom(World world, Entity entity) =>
      encodeValue(world.get<T>(entity) as T);

  Uint8List encodeValue(Object? value) {
    final out = PacketBuilder();
    codec.encode(value as T, out);
    return out.build();
  }

  Object? decode(Uint8List bytes) => codec.decode(PacketReader(bytes));

  void insert(World world, Entity entity, Object? value) =>
      world.insert<T>(entity, value as T);

  void remove(World world, Entity entity) => world.remove<T>(entity);

  Object? lerp(Object? from, Object? to, double t) =>
      interpolate!(from as T, to as T, t);
}

/// Type-erased access to the registered input type.
@internal
class InputReplicator<I> {
  final NetCodec<I> codec;

  InputReplicator(this.codec);

  Type get inputsType => NetInputs<I>;

  Type get localInputsType => NetLocalInputs<I>;

  void install(App app) {
    app.insertResource<NetInputs<I>>(NetInputs<I>());
    app.insertResource<NetLocalInputs<I>>(NetLocalInputs<I>());
  }

  Uint8List encode(Object? input) {
    final out = PacketBuilder();
    codec.encode(input as I, out);
    return out.build();
  }

  Object? decode(Uint8List bytes) => codec.decode(PacketReader(bytes));

  /// Take the submissions made this tick through `NetLocalInputs<I>`.
  Map<Entity, Object?> takeLocal(World world) =>
      world.getResource<NetLocalInputs<I>>()?.take() ?? const {};

  void publish(World world, int tick, List<RawInputEntry> entries) {
    world.getResource<NetInputs<I>>()?.replace(tick, [
      for (final e in entries)
        NetInputEntry<I>(
          peerId: e.peerId,
          entity: e.entity,
          netId: e.netId,
          tick: tick,
          input: e.input as I,
          repeated: e.repeated,
        ),
    ]);
  }
}

/// Erased input entry used internally before publishing.
@internal
class RawInputEntry {
  final int peerId;
  final Entity entity;
  final int netId;
  final Object? input;
  final bool repeated;

  RawInputEntry(
    this.peerId,
    this.entity,
    this.netId,
    this.input,
    this.repeated,
  );
}

/// Type-erased prediction registration.
@internal
abstract class PredictionReplicator {
  ComponentReplicator<Object?> get component;
  double get tolerance;
  double get correctionBlend;

  Object? step(Object? state, Object? input, double dt);

  double error(Object? a, Object? b);
}

@internal
class TypedPredictionReplicator<S, I> implements PredictionReplicator {
  @override
  final ComponentReplicator<Object?> component;
  final S Function(S state, I input, double dt) stepFn;
  final double Function(S a, S b) errorFn;
  @override
  final double tolerance;
  @override
  final double correctionBlend;

  TypedPredictionReplicator({
    required this.component,
    required S Function(S state, I input, double dt) step,
    required this.errorFn,
    required this.tolerance,
    required this.correctionBlend,
  }) : stepFn = step;

  @override
  Object? step(Object? state, Object? input, double dt) =>
      stepFn(state as S, input as I, dt);

  @override
  double error(Object? a, Object? b) => errorFn(a as S, b as S);
}

/// Type-erased RPC registration.
@internal
class RpcReplicator<T> {
  final int index;
  final String key;
  final NetCodec<T> codec;

  RpcReplicator({required this.index, required this.key, required this.codec});

  Type get eventType => NetRpcReceived<T>;

  void registerEvent(App app) => app.addEvent<NetRpcReceived<T>>();

  Uint8List encode(Object? value) {
    final out = PacketBuilder();
    codec.encode(value as T, out);
    return out.build();
  }

  void emit(
    World world,
    int sender,
    Uint8List bytes,
    int targetNetId,
    Entity? target,
  ) {
    final value = codec.decode(PacketReader(bytes));
    world.eventWriter<NetRpcReceived<T>>().send(
      NetRpcReceived<T>(
        sender: sender,
        value: value,
        targetNetId: targetNetId,
        target: target,
      ),
    );
  }
}
