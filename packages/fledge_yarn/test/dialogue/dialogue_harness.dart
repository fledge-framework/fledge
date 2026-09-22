import 'dart:io';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';

/// Reads a .yarn file from the repo (fixtures).
String readYarn(String path) => File(path).readAsStringSync();

/// The generic dialogue core alone, headless: [YarnPlugin] +
/// [DialogueCorePlugin], [WallTime] driven by [tick]'s `dt`, and a `log`
/// Yarn command recording its arguments into [commandLog].
///
/// [events] is every dialogue notification in order. Like fledge events
/// themselves, a notification is seen the tick after it was sent; within
/// a tick they're listed Started, ChoiceMade, LineShown, ChoicesReady,
/// Ended.
class DialogueHarness {
  final App app;
  final List<String> commandLog = [];
  final List<Object> events = [];

  DialogueHarness({
    List<String> yarnFiles = const ['test/dialogue/fixtures/core.yarn'],
    double charactersPerSecond = 40,
  }) : app = App()
         ..insertResource(WallTime())
         ..addPlugin(YarnPlugin())
         ..addPlugin(
           DialogueCorePlugin(charactersPerSecond: charactersPerSecond),
         ) {
    for (final path in yarnFiles) {
      project.parse(readYarn(path));
    }
    commands.register('log', (command, args) {
      commandLog.add(args.join(' '));
      return true;
    });
  }

  World get world => app.world;
  DialogueState get state => world.getResource<DialogueState>()!;
  YarnProject get project => world.getResource<YarnProject>()!;
  VariableStorage get variables => world.getResource<VariableStorage>()!;
  CommandHandler get commands => world.getResource<CommandHandler>()!;

  void send<T>(T event) => world.eventWriter<T>().send(event);

  Future<void> tick([double dt = 1 / 60]) async {
    world.getResource<WallTime>()!.delta = dt;
    await app.tick();
    _collect<DialogueStarted>();
    _collect<DialogueChoiceMade>();
    _collect<DialogueLineShown>();
    _collect<DialogueChoicesReady>();
    _collect<DialogueEnded>();
  }

  Future<void> ticks(int n, [double dt = 1 / 60]) async {
    for (var i = 0; i < n; i++) {
      await tick(dt);
    }
  }

  void _collect<T>() => events.addAll(world.eventReader<T>().read().cast());

  /// Sends [event] and ticks once (the core applies it on that tick).
  Future<void> request<T>(T event, [double dt = 1 / 60]) {
    send<T>(event);
    return tick(dt);
  }

  /// Starts [node] (applied on the next tick).
  Future<void> start(String node, {Object? context}) =>
      request(DialogueStartRequested(node, context: context));

  /// Advances past typing: one advance to complete the line, one to move on.
  Future<void> advanceLine() async {
    if (!state.isLineComplete) {
      await request(const DialogueAdvanceRequested());
    }
    await request(const DialogueAdvanceRequested());
  }

  /// A compact trace of [events]: `started:intro`, `line:Guide:Hello there!`,
  /// `choices:3`, `made:0`, `ended:intro` (`ended*` when skipped).
  List<String> get trace => [
    for (final e in events)
      switch (e) {
        DialogueStarted(:final node) => 'started:$node',
        DialogueLineShown(:final line) => 'line:$line',
        DialogueChoicesReady(:final choices) => 'choices:${choices.length}',
        DialogueChoiceMade(:final index) => 'made:$index',
        DialogueEnded(:final node, :final skipped) =>
          skipped ? 'ended*:$node' : 'ended:$node',
        _ => '$e',
      },
  ];
}
