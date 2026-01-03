/// Global tick counter for change detection.
///
/// The tick counter advances once per frame and is used to track
/// when components were added or modified.
class Tick {
  int _value = 0;

  /// The current tick value.
  int get value => _value;

  /// Advances the tick counter by one.
  ///
  /// This should be called once per frame, typically at the end
  /// of the frame after all systems have run.
  void advance() => _value++;

  /// Resets the tick counter to zero.
  ///
  /// This is primarily useful for testing.
  void reset() => _value = 0;
}

/// Tracks when a component was added and last changed.
///
/// Each component slot in a table has an associated [ComponentTicks]
/// that records the tick when the component was added and last modified.
class ComponentTicks {
  /// The tick when this component was added to the entity.
  int addedTick;

  /// The tick when this component was last modified.
  int changedTick;

  /// Creates component ticks with the given values.
  ComponentTicks({
    required this.addedTick,
    required this.changedTick,
  });

  /// Creates component ticks for a newly added component.
  factory ComponentTicks.added(int currentTick) {
    return ComponentTicks(
      addedTick: currentTick,
      changedTick: currentTick,
    );
  }

  /// Returns true if this component was added after [lastSeenTick].
  ///
  /// This is used by [Added<T>] queries to filter entities where
  /// the component was recently added.
  bool isAdded(int lastSeenTick) => addedTick > lastSeenTick;

  /// Returns true if this component was changed after [lastSeenTick].
  ///
  /// This is used by [Changed<T>] queries to filter entities where
  /// the component was recently modified.
  bool isChanged(int lastSeenTick) => changedTick > lastSeenTick;

  /// Marks this component as changed at the given tick.
  void markChanged(int currentTick) {
    changedTick = currentTick;
  }

  @override
  String toString() => 'ComponentTicks(added: $addedTick, changed: $changedTick)';
}
