import '../yarn_line.dart' show DialogueLine;

import 'dialogue_state.dart' show DialogueChoice;

// =============================================================================
// Dialogue events (generic core)
// =============================================================================
//
// Requests are sent by anyone — input systems, widgets (between ticks), game
// systems (e.g. a recording-minigame timer selecting a choice, a minigame
// releasing a hold). Only the core systems (`DialogueStartSystem`,
// `DialogueAdvanceSystem`) read them.
//
// Notifications are sent by the core systems when the dialogue's state
// changes. They are fledge events: readable on the tick after they were sent.

/// Starts the dialogue at Yarn node [node].
///
/// Refused (logged, nothing happens) while another dialogue is active or if
/// the node doesn't exist. [context] is an opaque value carried through to
/// `DialogueState.context`, [DialogueStarted] and [DialogueEnded] — e.g. the
/// id of the character being talked to.
class DialogueStartRequested {
  final String node;
  final Object? context;

  const DialogueStartRequested(this.node, {this.context});

  @override
  String toString() => 'DialogueStartRequested($node, context: $context)';
}

/// "Continue": completes the current line's typing if it is still typing,
/// otherwise advances to the next line. While a choice is pending it
/// selects the highlighted choice (`DialogueState.cursorIndex`). Several in
/// one tick count as one.
class DialogueAdvanceRequested {
  const DialogueAdvanceRequested();

  @override
  String toString() => 'DialogueAdvanceRequested()';
}

/// Selects the pending choice at [index] (into `DialogueState.choices`).
/// Ignored unless a choice is pending and [index] is in range; only the
/// first valid selection per tick is applied.
class DialogueChoiceSelected {
  final int index;

  const DialogueChoiceSelected(this.index);

  @override
  String toString() => 'DialogueChoiceSelected($index)';
}

/// Moves the highlighted choice by [delta] (wrapping). Ignored unless a
/// choice is pending.
class DialogueCursorMoved {
  final int delta;

  const DialogueCursorMoved(this.delta);

  @override
  String toString() => 'DialogueCursorMoved($delta)';
}

/// Fast-forwards the dialogue: every remaining line is passed over and
/// every command (including `<<set>>`) runs, until the next choice (which
/// is then shown) or the end. Does nothing while a choice is pending.
class DialogueSkipRequested {
  const DialogueSkipRequested();

  @override
  String toString() => 'DialogueSkipRequested()';
}

/// Ends the active dialogue **now**: no further line, choice or command
/// runs, and [DialogueEnded] is sent with `stopped: true`. With a
/// [context], only a dialogue whose `DialogueState.context` equals it is
/// stopped (so a stale stop can't end someone else's dialogue); without
/// one, whatever is active. Also drops any hold ([DialogueHoldReleased]).
///
/// Unlike every other request, a stop naming the context of a dialogue
/// started this tick is applied (a context-less one is ignored then, like
/// the other requests: it predates the dialogue).
class DialogueStopRequested {
  final Object? context;

  const DialogueStopRequested({this.context});

  @override
  String toString() => 'DialogueStopRequested(context: $context)';
}

/// Releases the hold [token] taken by a holding command (see
/// `registerHoldingCommand`). When no hold is left, the dialogue shows
/// what the runner stopped at after the command — the next line, choice,
/// or the end — on the tick the release is read. Unknown tokens are
/// ignored.
class DialogueHoldReleased {
  final Object token;

  const DialogueHoldReleased(this.token);

  @override
  String toString() => 'DialogueHoldReleased($token)';
}

/// A dialogue started at [node] (with the request's [context]).
class DialogueStarted {
  final String node;
  final Object? context;

  const DialogueStarted(this.node, {this.context});

  @override
  String toString() => 'DialogueStarted($node, context: $context)';
}

/// A new line is being shown. Not sent for lines passed over by a skip.
class DialogueLineShown {
  final DialogueLine line;

  const DialogueLineShown(this.line);

  @override
  String toString() => 'DialogueLineShown($line)';
}

/// A choice is pending: the player (or any system) answers it with
/// [DialogueChoiceSelected].
class DialogueChoicesReady {
  final List<DialogueChoice> choices;

  const DialogueChoicesReady(this.choices);

  /// Index of the choice tagged `#timeout`, or null.
  int? get timeoutChoiceIndex => timeoutIndexOf(choices);

  @override
  String toString() => 'DialogueChoicesReady($choices)';
}

/// Choice [index] was taken (its [text] and Yarn [tags], e.g. metric tags)
/// in the dialogue started with [context].
class DialogueChoiceMade {
  final int index;
  final String text;
  final List<String> tags;

  /// The dialogue's `DialogueStartRequested.context` (a consumer can tell
  /// whose choice it was after the dialogue has already ended).
  final Object? context;

  const DialogueChoiceMade(
    this.index, {
    required this.text,
    this.tags = const [],
    this.context,
  });

  @override
  String toString() =>
      'DialogueChoiceMade($index, $text, tags: $tags, context: $context)';
}

/// The dialogue started at [node] ended ([skipped]: it was fast-forwarded
/// to its end by a [DialogueSkipRequested]; [stopped]: it was cut short by
/// a [DialogueStopRequested], without running the rest).
class DialogueEnded {
  final String node;
  final Object? context;
  final bool skipped;
  final bool stopped;

  const DialogueEnded(
    this.node, {
    this.context,
    this.skipped = false,
    this.stopped = false,
  });

  @override
  String toString() =>
      'DialogueEnded($node, context: $context, skipped: $skipped, '
      'stopped: $stopped)';
}

/// The Yarn tag marking a choice as the one to take when a timed choice
/// runs out (`-> Say nothing #timeout`).
const String timeoutChoiceTag = 'timeout';

/// Index of the first choice in [choices] tagged [timeoutChoiceTag], or
/// null.
int? timeoutIndexOf(List<DialogueChoice> choices) {
  for (var i = 0; i < choices.length; i++) {
    if (choices[i].hasTag(timeoutChoiceTag)) return i;
  }
  return null;
}
