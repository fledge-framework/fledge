import '../component.dart';
import '../entity.dart';
import '../world.dart';

/// The kind of trigger that activates an observer.
enum TriggerKind {
  /// Triggered when a component is added to an entity.
  onAdd,

  /// Triggered when a component is removed from an entity.
  onRemove,

  /// Triggered when a component's value is changed.
  onChange,
}

/// A callback type for observer reactions.
typedef ObserverCallback<T> = void Function(
    World world, Entity entity, T component);

/// An observer that reacts to component lifecycle events.
///
/// Observers provide a reactive way to respond to component additions,
/// removals, and changes without polling in systems.
///
/// ```dart
/// // React to health being removed (death)
/// world.observers.register(Observer<Health>.onRemove((w, e, h) {
///   w.eventWriter<DeathEvent>().send(DeathEvent(e));
/// }));
///
/// // React to position changes
/// world.observers.register(Observer<Position>.onChange((w, e, pos) {
///   print('Entity $e moved to (${pos.x}, ${pos.y})');
/// }));
/// ```
class Observer<T> {
  /// The component type this observer watches.
  final Type componentType;

  /// The trigger kind that activates this observer.
  final TriggerKind trigger;

  /// The callback to invoke when triggered.
  final ObserverCallback<T> _callback;

  /// Creates an observer triggered when a component is added.
  Observer.onAdd(ObserverCallback<T> callback)
      : componentType = T,
        trigger = TriggerKind.onAdd,
        _callback = callback;

  /// Creates an observer triggered when a component is removed.
  Observer.onRemove(ObserverCallback<T> callback)
      : componentType = T,
        trigger = TriggerKind.onRemove,
        _callback = callback;

  /// Creates an observer triggered when a component is changed.
  Observer.onChange(ObserverCallback<T> callback)
      : componentType = T,
        trigger = TriggerKind.onChange,
        _callback = callback;

  /// Invokes the observer callback with the given parameters.
  void invoke(World world, Entity entity, T component) {
    _callback(world, entity, component);
  }

  @override
  String toString() => 'Observer<$componentType>($trigger)';
}

/// Internal storage for a registered observer.
class _RegisteredObserver {
  final ComponentId componentId;
  final TriggerKind trigger;
  final Observer observer;

  _RegisteredObserver(this.componentId, this.trigger, this.observer);
}

/// Registry for managing component observers.
///
/// The observer registry stores observers organized by component type and
/// trigger kind for efficient dispatch.
///
/// ```dart
/// final observers = Observers();
///
/// observers.register(Observer<Health>.onRemove((w, e, h) {
///   print('Entity $e lost health component');
/// }));
///
/// // Trigger manually (usually done by World)
/// observers.triggerOnRemove<Health>(world, entity, healthComponent);
/// ```
class Observers {
  /// Observers organized by ComponentId.
  final Map<ComponentId, List<_RegisteredObserver>> _byComponent = {};

  /// Observers organized by trigger kind then ComponentId.
  final Map<TriggerKind, Map<ComponentId, List<Observer>>> _byTrigger = {
    TriggerKind.onAdd: {},
    TriggerKind.onRemove: {},
    TriggerKind.onChange: {},
  };

  /// Registers an observer.
  ///
  /// The observer will be called whenever the corresponding trigger event
  /// occurs for the observer's component type.
  void register<T>(Observer<T> observer) {
    final componentId = ComponentId.of<T>();

    // Add to by-component index
    _byComponent.putIfAbsent(componentId, () => []).add(
          _RegisteredObserver(componentId, observer.trigger, observer),
        );

    // Add to by-trigger index
    _byTrigger[observer.trigger]!
        .putIfAbsent(componentId, () => [])
        .add(observer);
  }

  /// Unregisters an observer.
  ///
  /// Returns true if the observer was found and removed.
  bool unregister<T>(Observer<T> observer) {
    final componentId = ComponentId.of<T>();

    // Remove from by-component index
    final componentList = _byComponent[componentId];
    if (componentList != null) {
      componentList.removeWhere((r) => identical(r.observer, observer));
    }

    // Remove from by-trigger index
    final triggerMap = _byTrigger[observer.trigger]!;
    final triggerList = triggerMap[componentId];
    if (triggerList != null) {
      return triggerList.remove(observer);
    }

    return false;
  }

  /// Triggers all onAdd observers for the given component type.
  void triggerOnAdd<T>(World world, Entity entity, T component) {
    final componentId = ComponentId.of<T>();
    final observers = _byTrigger[TriggerKind.onAdd]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      (observer as Observer<T>).invoke(world, entity, component);
    }
  }

  /// Triggers all onRemove observers for the given component type.
  void triggerOnRemove<T>(World world, Entity entity, T component) {
    final componentId = ComponentId.of<T>();
    final observers = _byTrigger[TriggerKind.onRemove]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      (observer as Observer<T>).invoke(world, entity, component);
    }
  }

  /// Triggers all onChange observers for the given component type.
  void triggerOnChange<T>(World world, Entity entity, T component) {
    final componentId = ComponentId.of<T>();
    final observers = _byTrigger[TriggerKind.onChange]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      (observer as Observer<T>).invoke(world, entity, component);
    }
  }

  /// Triggers observers using runtime type lookup.
  ///
  /// This is used internally when the static type is not known.
  void triggerOnAddDynamic(
      World world, Entity entity, ComponentId componentId, dynamic component) {
    final observers = _byTrigger[TriggerKind.onAdd]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      observer.invoke(world, entity, component);
    }
  }

  /// Triggers observers using runtime type lookup.
  ///
  /// This is used internally when the static type is not known.
  void triggerOnRemoveDynamic(
      World world, Entity entity, ComponentId componentId, dynamic component) {
    final observers = _byTrigger[TriggerKind.onRemove]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      observer.invoke(world, entity, component);
    }
  }

  /// Triggers observers using runtime type lookup.
  ///
  /// This is used internally when the static type is not known.
  void triggerOnChangeDynamic(
      World world, Entity entity, ComponentId componentId, dynamic component) {
    final observers = _byTrigger[TriggerKind.onChange]![componentId];
    if (observers == null) return;

    for (final observer in observers) {
      observer.invoke(world, entity, component);
    }
  }

  /// Returns true if there are any observers registered.
  bool get hasObservers => _byComponent.isNotEmpty;

  /// Returns true if there are observers for the given component type.
  bool hasObserversFor<T>() => _byComponent.containsKey(ComponentId.of<T>());

  /// The total number of registered observers.
  int get count =>
      _byComponent.values.fold(0, (sum, list) => sum + list.length);

  /// Clears all registered observers.
  void clear() {
    _byComponent.clear();
    for (final map in _byTrigger.values) {
      map.clear();
    }
  }
}
