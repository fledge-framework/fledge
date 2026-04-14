import 'package:fledge_save/fledge_save.dart';

/// Play-field bounds in world units (== pixels here).
class GameBounds {
  final double width;
  final double height;
  const GameBounds({this.width = 480, this.height = 320});
}

/// Pickups collected in the current run. Resets each time the player
/// starts a new game; not persisted.
class RunScore {
  int value = 0;
  void reset() => value = 0;
}

/// Highest pickup count ever achieved. Persisted across runs via
/// [Saveable] — `fledge_save` auto-discovers this when it walks the
/// world's resources at save time.
class HighScore with Saveable {
  int value = 0;

  @override
  String get saveKey => 'drifter.highScore';

  @override
  Map<String, dynamic> toSaveJson() => {'value': value};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    value = (json['value'] as num?)?.toInt() ?? 0;
  }
}

/// Flipped on by `SaveLoadSystem` when the "load" action fires. The
/// Flutter game loop drains this at the top of the tick and calls
/// `SaveManager.load` asynchronously.
class LoadRequested {
  bool pending = false;
}

/// Flipped on by `SaveLoadSystem` when the "reset" action fires. The
/// Flutter layer despawns the current player/pickup entities and
/// rebuilds them via the `GameApp` helpers.
class ResetRequested {
  bool pending = false;
}
