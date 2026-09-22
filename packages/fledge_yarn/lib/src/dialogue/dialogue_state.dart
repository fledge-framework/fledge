import 'dart:developer' as developer;

import 'package:fledge_ecs/fledge_ecs.dart';

import '../command_handler.dart';
import '../dialogue_runner.dart';
import '../variable_storage.dart';
import '../yarn_line.dart';
import '../yarn_project.dart';
import 'dialogue_events.dart';

part 'dialogue_systems.dart';

// =============================================================================
// DialogueState (generic core)
// =============================================================================
//
// This library (the state + its two systems, `dialogue_systems.dart` is a
// part of it) is presentation-facing state on top of the runner's own
// `DialogueRunnerState`. The state's mutators are library-private: only
// `DialogueStartSystem` and `DialogueAdvanceSystem` change it, in response
// to the request events in dialogue_events.dart (a holding command's hold —
// `registerHoldingCommand` — is taken while one of them runs the command).
// Everything else — widgets, run conditions, game systems — only reads it.

/// One option of a pending choice, as presented to the player.
class DialogueChoice {
  /// The option's text.
  final String text;

  /// Its Yarn tags, without the `#` (`-> Sure! #warm #energy_2`).
  final List<String> tags;

  /// Whether its condition passed. The Yarn runner drops unavailable
  /// options, so every listed choice is currently available.
  final bool isAvailable;

  const DialogueChoice({
    required this.text,
    this.tags = const [],
    this.isAvailable = true,
  });

  /// Whether the option carries [tag] (with or without the leading `#`).
  bool hasTag(String tag) =>
      tags.contains(tag.startsWith('#') ? tag.substring(1) : tag);

  @override
  String toString() => 'DialogueChoice($text, tags: $tags)';
}

/// The one active dialogue (or none), presentation-facing.
///
/// Wraps [DialogueRunner], which only the core systems touch. Not saved:
/// a dialogue doesn't survive save/load (Yarn *variables* do, separately).
class DialogueState {
  /// Typewriter speed for new lines, in characters per second. `<= 0` or
  /// infinite shows each line at once.
  final double charactersPerSecond;

  DialogueState({this.charactersPerSecond = 40});

  DialogueRunner? _runner;
  String? _startNode;
  Object? _context;
  DialogueLine? _line;
  List<DialogueChoice> _choices = const [];
  int _cursor = 0;
  double _visibleCharacters = 0;
  bool _startedThisTick = false;
  final List<Object> _holds = [];

  /// Whether a dialogue is running (a line or a choice is up).
  bool get isActive => _runner != null;

  /// The node the dialogue was started at (the `DialogueStartRequested`
  /// node), or null.
  String? get startNode => _startNode;

  /// The Yarn node currently running (changes on `<<jump>>`), or null.
  String? get nodeName => _runner?.currentNodeTitle;

  /// The start request's context (e.g. who is being talked to), or null.
  Object? get context => _context;

  /// The line on screen: the current line, or — while a choice is pending —
  /// the line that led to it (null if the node opened with the choice).
  DialogueLine? get currentLine => _line;

  /// The pending choice's options (empty unless [isWaitingForChoice]).
  List<DialogueChoice> get choices => _choices;

  /// Whether a choice is pending (never while [isHeld]).
  bool get isWaitingForChoice =>
      !isHeld && (_runner?.isWaitingForChoice ?? false);

  /// Whether a holding command (`registerHoldingCommand`) paused the
  /// dialogue: nothing is shown ([currentLine] is null, no [choices]) and
  /// every request but a stop is ignored until each hold is released
  /// (`DialogueHoldReleased`).
  bool get isHeld => _holds.isNotEmpty;

  /// The tokens of the holds in place, oldest first.
  List<Object> get holdTokens => List.unmodifiable(_holds);

  /// The highlighted option (keyboard navigation), `0 <= i < choices.length`
  /// while a choice is pending.
  int get cursorIndex => _cursor;

  /// Index of the pending option tagged `#timeout`, or null.
  int? get timeoutChoiceIndex => timeoutIndexOf(_choices);

  /// How many characters of [currentLine] are shown.
  int get visibleCharacterCount {
    final length = _line?.text.length ?? 0;
    return _visibleCharacters.floor().clamp(0, length);
  }

  /// The typed-so-far part of [currentLine].
  String get visibleText =>
      _line == null ? '' : _line!.text.substring(0, visibleCharacterCount);

  /// Typing progress of [currentLine], 0..1 (1 with no line).
  double get typewriterProgress {
    final length = _line?.text.length ?? 0;
    if (length == 0) return 1;
    return visibleCharacterCount / length;
  }

  /// Whether [currentLine] is fully typed.
  bool get isLineComplete => typewriterProgress >= 1;

  // ---------------------------------------------------------------------------
  // Mutators — library-private, used only by the core systems.
  // ---------------------------------------------------------------------------

  void _begin(DialogueRunner runner, String node, Object? context) {
    _runner = runner;
    _startNode = node;
    _context = context;
    _line = null;
    _choices = const [];
    _cursor = 0;
    _visibleCharacters = 0;
    _startedThisTick = true;
  }

  void _showLine(DialogueLine line, {bool complete = false}) {
    _line = line;
    _choices = const [];
    _cursor = 0;
    _visibleCharacters = complete || !_typesGradually
        ? line.text.length.toDouble()
        : 0;
  }

  void _showChoices(List<DialogueChoice> choices) {
    _choices = List.unmodifiable(choices);
    _cursor = 0;
    // The leading line stays up, fully typed.
    _completeLine();
  }

  void _completeLine() {
    _visibleCharacters = (_line?.text.length ?? 0).toDouble();
  }

  void _type(double seconds) {
    if (_line == null || isLineComplete || seconds <= 0) return;
    if (!_typesGradually) {
      _completeLine();
      return;
    }
    _visibleCharacters = (_visibleCharacters + charactersPerSecond * seconds)
        .clamp(0, _line!.text.length.toDouble());
  }

  void _moveCursor(int delta) {
    if (_choices.isEmpty) return;
    _cursor = (_cursor + delta) % _choices.length;
  }

  /// A holding command ran: hide the line and choices until released.
  void _hold(Object token) {
    _holds.add(token);
    _line = null;
    _choices = const [];
    _cursor = 0;
    _visibleCharacters = 0;
  }

  /// Releases the first hold with [token]; whether one was released.
  bool _release(Object token) => _holds.remove(token);

  void _clear() {
    _holds.clear();
    _runner = null;
    _startNode = null;
    _context = null;
    _line = null;
    _choices = const [];
    _cursor = 0;
    _visibleCharacters = 0;
    _startedThisTick = false;
  }

  bool get _typesGradually =>
      charactersPerSecond > 0 && charactersPerSecond.isFinite;
}

void _log(String message, {int level = 800}) =>
    developer.log(message, name: 'dialogue', level: level);
