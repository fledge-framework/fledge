import 'package:flutter/material.dart';

import '../yarn_line.dart' show DialogueLine;
import 'dialogue_state.dart';

/// Wraps the box's content in its frame (background, border, nine-slice…).
typedef DialogueFrameBuilder =
    Widget Function(BuildContext context, Widget child);

/// Builds the portrait for [line]'s speaker, or null for none.
typedef DialoguePortraitBuilder =
    Widget? Function(BuildContext context, DialogueLine line);

/// Look of [DialogueBoxWidget] / [DialogueChoiceList].
class DialogueBoxTheme {
  /// Padding inside the frame. Ignored by a custom [frameBuilder] (which
  /// does its own).
  final EdgeInsets contentPadding;
  final Color backgroundColor;
  final Color borderColor;

  /// Custom frame (e.g. a nine-slice sprite) instead of the default
  /// rectangle.
  final DialogueFrameBuilder? frameBuilder;

  final TextStyle speakerStyle;
  final TextStyle textStyle;

  /// Minimum height of the text area (keeps the box from jumping as the
  /// line types in).
  final double textMinHeight;

  final TextStyle choiceStyle;
  final TextStyle selectedChoiceStyle;
  final Color choiceBorderColor;
  final Color selectedChoiceBorderColor;
  final Color selectedChoiceFill;
  final Color choiceCursorColor;

  /// Shown under a fully typed line (null: nothing).
  final String? continueHint;
  final TextStyle continueHintStyle;

  const DialogueBoxTheme({
    this.contentPadding = const EdgeInsets.all(12),
    this.backgroundColor = const Color(0xE6202028),
    this.borderColor = const Color(0xFFFFFFFF),
    this.frameBuilder,
    this.speakerStyle = const TextStyle(
      fontSize: 14,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.textStyle = const TextStyle(
      fontSize: 13,
      color: Colors.white,
      height: 1.5,
    ),
    this.textMinHeight = 60,
    this.choiceStyle = const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
    this.selectedChoiceStyle = const TextStyle(
      fontSize: 12,
      color: Colors.white,
    ),
    this.choiceBorderColor = const Color(0xFF616161),
    this.selectedChoiceBorderColor = Colors.white,
    this.selectedChoiceFill = const Color(0x33FFFFFF),
    this.choiceCursorColor = Colors.white,
    this.continueHint = 'Continue',
    this.continueHintStyle = const TextStyle(fontSize: 10, color: Colors.grey),
  });

  Widget frame(BuildContext context, Widget child) {
    final custom = frameBuilder;
    if (custom != null) return custom(context, child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(padding: contentPadding, child: child),
    );
  }
}

/// The base dialogue box: the current line (typed so far) with its speaker
/// and optional portrait, the pending choice's options with the highlight,
/// and a continue hint.
///
/// Presentation only: it reads [state] and reports taps through
/// [onAdvance] (tap on the box, not while a choice is pending) and
/// [onChoiceSelected] (tap on an option). The owner turns those into
/// `DialogueAdvanceRequested` / `DialogueChoiceSelected` events.
class DialogueBoxWidget extends StatelessWidget {
  final DialogueState state;
  final DialogueBoxTheme theme;

  /// Display name for a line's `character` (e.g. an id → a localized name).
  /// Null, or returning null: the character as written.
  final String? Function(String character)? speakerLabel;

  /// The speaker's portrait, left of the text. Null: no portrait slot.
  final DialoguePortraitBuilder? portraitBuilder;

  /// Extra widget at the right of the header (e.g. an affinity meter).
  final Widget? headerTrailing;

  final VoidCallback? onAdvance;
  final ValueChanged<int>? onChoiceSelected;

  const DialogueBoxWidget({
    super.key,
    required this.state,
    this.theme = const DialogueBoxTheme(),
    this.speakerLabel,
    this.portraitBuilder,
    this.headerTrailing,
    this.onAdvance,
    this.onChoiceSelected,
  });

  /// Key of the box's tap target.
  static const Key boxKey = ValueKey('dialogue-box');

  /// Key of the speaker label.
  static const Key speakerKey = ValueKey('dialogue-speaker');

  @override
  Widget build(BuildContext context) {
    if (!state.isActive) return const SizedBox.shrink();

    final line = state.currentLine;
    final character = line?.character;
    final speaker = character == null
        ? null
        : (speakerLabel?.call(character) ?? character);
    final portrait = line == null ? null : portraitBuilder?.call(context, line);
    final waiting = state.isWaitingForChoice;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaker != null || headerTrailing != null) ...[
          Row(
            children: [
              if (speaker != null)
                Text(speaker, key: speakerKey, style: theme.speakerStyle),
              const Spacer(),
              ?headerTrailing,
            ],
          ),
          const SizedBox(height: 8),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.textMinHeight),
          child: Text(state.visibleText, style: theme.textStyle),
        ),
        if (waiting && state.choices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DialogueChoiceList(
              options: [for (final choice in state.choices) choice.text],
              cursorIndex: state.cursorIndex,
              theme: theme,
              onSelected: onChoiceSelected,
            ),
          ),
        if (!waiting && state.isLineComplete && theme.continueHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(theme.continueHint!, style: theme.continueHintStyle),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  color: theme.continueHintStyle.color,
                  size: 12,
                ),
              ],
            ),
          ),
      ],
    );

    return GestureDetector(
      key: boxKey,
      behavior: HitTestBehavior.opaque,
      onTap: waiting ? null : onAdvance,
      child: theme.frame(
        context,
        portrait == null
            ? content
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  portrait,
                  const SizedBox(width: 12),
                  Expanded(child: content),
                ],
              ),
      ),
    );
  }
}

/// A vertical list of options with one highlighted ([cursorIndex]); tapping
/// an option reports its index through [onSelected]. Used by
/// [DialogueBoxWidget] and reusable for any dialogue-styled prompt.
class DialogueChoiceList extends StatelessWidget {
  final List<String> options;
  final int cursorIndex;
  final DialogueBoxTheme theme;
  final ValueChanged<int>? onSelected;

  const DialogueChoiceList({
    super.key,
    required this.options,
    required this.cursorIndex,
    this.theme = const DialogueBoxTheme(),
    this.onSelected,
  });

  /// Key of option [index]'s tap target.
  static Key optionKey(int index) => ValueKey('dialogue-choice-$index');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            key: optionKey(i),
            behavior: HitTestBehavior.opaque,
            onTap: onSelected == null ? null : () => onSelected!(i),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: i == cursorIndex
                    ? theme.selectedChoiceFill
                    : Colors.transparent,
                border: Border.all(
                  color: i == cursorIndex
                      ? theme.selectedChoiceBorderColor
                      : theme.choiceBorderColor,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  if (i == cursorIndex)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.arrow_right,
                        color: theme.choiceCursorColor,
                        size: 16,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      options[i],
                      style: i == cursorIndex
                          ? theme.selectedChoiceStyle
                          : theme.choiceStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
