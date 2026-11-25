# fledge_yarn

## Purpose
Yarn Spinner dialogue system: parser, runner, variable storage, custom commands, and an ECS dialogue layer (`DialogueCorePlugin`) with a Flutter dialogue box widget.

## Status: Functional

## Stats
- Source: 16 files, ~3,320 LOC
- Tests: 7 files (+ `test/dialogue/dialogue_harness.dart`, fixtures) — expression evaluator, variable storage, runner jumps, pausing commands, dialogue core/hold, dialogue box widget
- TODOs in code: 0

## What Works
- Yarn script parser (nodes, lines, options, commands)
- Dialogue runner with node traversal and option selection
- Variable storage (get/set typed variables)
- Custom command registration and invocation, including pausing commands (`CommandHandler.registerPausing`)
- Conditional branching (`<<if>>`, `<<else>>`)
- Expression evaluator with full arithmetic, comparison, and boolean support
  at standard precedence (`src/expression.dart`)
- ECS dialogue layer: typewriter `DialogueState`, request/notification events, holding commands, built-in `<<declare>>`
- `DialogueBoxWidget` / `DialogueChoiceList` with `DialogueBoxTheme`

## Gaps
- **[P1]** Parser still lacks direct unit tests (covered indirectly via runner/dialogue tests)
- **[P2]** No string interpolation support (`{$variable}` syntax)

## Action Items
1. Add unit tests for the parser
2. Implement `{$variable}` string interpolation in dialogue lines

## Architecture Notes
- **Entry point**: `lib/fledge_yarn.dart` (barrel export)
- **YarnPlugin** (`lib/src/plugin.dart`): Inserts `YarnProject`, `VariableStorage`, `CommandHandler` (optionally parsing `initialContent` / loading `initialVariables`). Registers **no systems**.
- **DialogueCorePlugin** (`lib/src/dialogue/dialogue_core_plugin.dart`): Requires `YarnPlugin` added first (throws `StateError` otherwise). Inserts `DialogueState`, registers the `Dialogue*Requested` / notification events, registers `<<declare>>`, and adds `DialogueStartSystem` → `DialogueAdvanceSystem` (advance declares `after:` start) to a configurable `schedule` (default `Schedules.update`). Options: `charactersPerSecond`, `commandAccess` (`DialogueCommandAccess` — resources/events your command handlers write, so the scheduler can order against consumers), `timeSource` (`DialogueTimeSource.wallTime` default).
- **System names**: `DialogueStartSystem.systemName` (`'DialogueStartSystem'`), `DialogueAdvanceSystem.systemName` (`'DialogueAdvanceSystem'`); `dialogueCoreSystemNames` lists both for `before:` / `after:`.
- **Holding commands**: `registerHoldingCommand(...)` (`lib/src/dialogue/dialogue_systems.dart`) — the dialogue waits until a matching `DialogueHoldReleased` event.
- **Parser** (`lib/src/yarn_parser.dart`): Tokenizes and parses `.yarn` files into `YarnNode`s of sealed `YarnLine`s (`DialogueLine`, `ChoiceSet`, `CommandLine`, `ConditionalBlock`, `JumpLine`). `YarnProject` holds the parsed nodes.
- **DialogueRunner** (`lib/src/dialogue_runner.dart`): Walks the node graph, emitting lines and options to the game. Handles jumps between nodes and option selection callbacks.
- **VariableStorage**: Key-value store for dialogue variables (strings, numbers, bools). Accessed by expressions and set by `<<set>>` commands.
- **Commands** (`lib/src/command_handler.dart`): Game-defined functions callable from Yarn scripts via `<<command args>>`, registered on the `CommandHandler` resource.
- **Expression evaluator** (`src/expression.dart`): Recursive-descent parser over a tiny tokenizer. Precedence (low → high): `or` → `and` → `not` → comparisons → `+` `-` → `*` `/` `%` → unary → primary. Variables resolved via a callback so the parser is decoupled from `VariableStorage`. `VariableStorage` swallows `FormatException`s from malformed expressions so dialogue doesn't crash mid-run — use `ExpressionEvaluator` directly when you want strict errors.
- **Tests**: Flutter package — run with `flutter test`.
