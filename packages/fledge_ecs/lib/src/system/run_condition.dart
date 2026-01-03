import '../world.dart';

/// A condition that determines whether a system should run.
///
/// Run conditions are evaluated before each system execution. If the condition
/// returns false, the system is skipped for that frame.
///
/// ```dart
/// // Only run when game is playing
/// final system = FunctionSystem(
///   'movement',
///   runIf: (world) => world.getResource<GameState>()?.isPlaying ?? false,
///   run: (world) { /* ... */ },
/// );
/// ```
typedef RunCondition = bool Function(World world);

/// Common run conditions for systems.
///
/// These factory methods create reusable run conditions based on common
/// patterns.
class RunConditions {
  RunConditions._();

  /// Creates a condition that checks a predicate against a resource.
  ///
  /// Returns false if the resource doesn't exist.
  ///
  /// ```dart
  /// final runIfPlaying = RunConditions.resource<GameState>(
  ///   (state) => state.isPlaying,
  /// );
  /// ```
  static RunCondition resource<T>(bool Function(T) predicate) {
    return (world) {
      final res = world.getResource<T>();
      if (res == null) return false;
      return predicate(res);
    };
  }

  /// Creates a condition that requires a resource to exist.
  ///
  /// ```dart
  /// final hasPlayer = RunConditions.resourceExists<Player>();
  /// ```
  static RunCondition resourceExists<T>() {
    return (world) => world.hasResource<T>();
  }

  /// Creates a condition that combines multiple conditions with AND logic.
  ///
  /// All conditions must return true for the combined condition to be true.
  ///
  /// ```dart
  /// final bothConditions = RunConditions.and([
  ///   (w) => w.hasResource<Player>(),
  ///   (w) => w.getResource<GameState>()?.isPlaying ?? false,
  /// ]);
  /// ```
  static RunCondition and(List<RunCondition> conditions) {
    return (world) {
      for (final condition in conditions) {
        if (!condition(world)) return false;
      }
      return true;
    };
  }

  /// Creates a condition that combines multiple conditions with OR logic.
  ///
  /// At least one condition must return true for the combined condition to be true.
  ///
  /// ```dart
  /// final eitherCondition = RunConditions.or([
  ///   (w) => w.hasResource<Player>(),
  ///   (w) => w.hasResource<AI>(),
  /// ]);
  /// ```
  static RunCondition or(List<RunCondition> conditions) {
    return (world) {
      for (final condition in conditions) {
        if (condition(world)) return true;
      }
      return false;
    };
  }

  /// Creates a condition that negates another condition.
  ///
  /// ```dart
  /// final notPaused = RunConditions.not(
  ///   (w) => w.getResource<GameState>()?.isPaused ?? false,
  /// );
  /// ```
  static RunCondition not(RunCondition condition) {
    return (world) => !condition(world);
  }

  /// Creates a condition that always returns true.
  ///
  /// Useful as a default or for testing.
  static RunCondition always() => (world) => true;

  /// Creates a condition that always returns false.
  ///
  /// Useful for temporarily disabling a system.
  static RunCondition never() => (world) => false;

  /// Creates a condition that runs only when a specific event type has events.
  ///
  /// Returns false if the event type is not registered.
  ///
  /// ```dart
  /// final hasCollisions = RunConditions.onEvent<CollisionEvent>();
  /// ```
  static RunCondition onEvent<T>() {
    return (world) {
      if (!world.events.isRegistered<T>()) {
        return false;
      }
      final reader = world.eventReader<T>();
      return reader.read().isNotEmpty;
    };
  }
}
