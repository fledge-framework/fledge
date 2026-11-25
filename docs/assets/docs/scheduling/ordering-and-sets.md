# Ordering & Sets

Within a schedule, systems run one at a time in an order the scheduler works
out once from the dependency graph. This page covers how to control that
order, why you should, and how to check it.

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Paused {
  bool value = false;
}

class ReadInputSystem extends System {
  static const String systemName = 'readInput';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Velocity>()},
  );

  @override
  void run(World world) {}
}

class MoveSystem extends System {
  static const String systemName = 'move';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
  );

  @override
  void run(World world) {}
}

class CollideSystem extends System {
  static const String systemName = 'collide';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
  );

  @override
  void run(World world) {}
}
-->

## How the order is decided

1. **Explicit edges**: `before:`/`after:` on systems, and set constraints from
   `configureSet`, directly or transitively.
2. **Conflict fallback**: two systems **conflict** when one writes a component,
   resource or event type the other reads or writes (or either is
   `exclusive`). A conflicting pair that no explicit edge orders runs in
   **registration order**.
3. Systems that neither conflict nor have an edge between them have no
   guaranteed order.

Explicit edges always win over the fallback. A cycle among explicit edges
throws a `StateError` when the system (or set configuration) that closes it is
added, naming the systems involved.

## `before` and `after`

Name the systems to run before or after in `SystemMeta`. Reference their
`systemName` constants, never string literals:

```dart
class ClampToArenaSystem extends System {
  static const String systemName = 'clampToArena';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Position>()},
    after: [MoveSystem.systemName],
    before: [CollideSystem.systemName],
  );

  @override
  void run(World world) {}
}
```

`FunctionSystem` takes the same `before:`/`after:` parameters.

- A reference matches **every** system with that name and every member of a
  set with that name. Two systems sharing a name both get the edge.
- A name that matches nothing is ignored, silently. A typo produces no error,
  which is one more reason to use constants.
- Edges only apply within one schedule. A system in `update` that says
  `after: [WallTimeUpdateSystem.systemName]` gets nothing from it; the frame
  order already puts `first` before `update`.

## The registration-order trap

```dart
final app = App()
  ..addSystem(MoveSystem())
  ..addSystem(CollideSystem());
```

`MoveSystem` and `CollideSystem` both write `Position`, so they conflict.
Neither names the other, so they run in registration order: move, then
collide. It works, until someone adds the plugin that registers
`CollideSystem` earlier during setup. Now collision runs before movement and
the player walks through walls, with no error anywhere.

Fix it by stating the intent in the system that cares:

```dart
class SafeCollideSystem extends System {
  static const String systemName = 'safeCollide';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
    after: [MoveSystem.systemName],
  );

  @override
  void run(World world) {}
}
```

## Checking with `checkScheduleOrdering`

`App.checkScheduleOrdering()` returns every conflicting pair that only
registration order keeps apart. Run it in a test, or in a debug build at
startup:

```dart
final app = App()
  ..addSystem(MoveSystem())
  ..addSystem(CollideSystem());

for (final issue in app.checkScheduleOrdering()) {
  print(issue);
  // OrderingAmbiguity(stage=update): move runs before collide by
  // registration order only. Reasons: ... Add
  // `before: [CollideSystem.systemName]` to move, or
  // `after: [MoveSystem.systemName]` to collide, ...
}
```

Each `OrderingAmbiguity` has:

| Field | Meaning |
|---|---|
| `schedule` (also `stage`) | The schedule name |
| `systemA` | Runs first under the current registration |
| `systemB` | Runs second |
| `reasons` | Why they conflict, e.g. `both write component Position` |
| `systemAClass`, `systemBClass` | The systems' class names, when they're public class-based systems; otherwise `null` |
| `suggestion` | The fix, naming `systemName` constants: `before: [CollideSystem.systemName]` when the class is known, `<collide's systemName>` when it isn't (a `FunctionSystem`) |

A test that asserts the list is empty catches the trap the moment it's
introduced:

```dart
final app = App()
  ..addSystem(ReadInputSystem())
  ..addSystem(MoveSystem())
  ..addSystem(
    FunctionSystem(
      'collide',
      writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
      after: [MoveSystem.systemName, ReadInputSystem.systemName],
      run: (world) {},
    ),
  );

assert(app.checkScheduleOrdering().isEmpty, '${app.checkScheduleOrdering()}');
```

Here `ReadInputSystem` (writes `Velocity`) and `MoveSystem` (reads it) still
conflict, so the assert fails until one of them names the other.

`fledge_debug` refreshes a `ScheduleOrderingReport` resource on the first tick
and shows it in its overlay (see [Debug Tools](/docs/ui/debug)).

## System sets

A **set** is a named group. Ordering a set orders all its members, and a set
can carry a run condition. A system joins a set in two ways:

- declare it in its meta: `SystemMeta(sets: ['physics'])` or
  `FunctionSystem(..., sets: ['physics'])`;
- register it with `app.addSystemToSet(system, 'physics', schedule: ...)`.

Configure the set with `app.configureSet`. Set names work anywhere a system
name does, in `before:`/`after:` on systems and on other sets:

```dart
const input = 'input';
const physics = 'physics';
const presentation = 'presentation';

final app = App()
  ..insertResource(Paused())
  ..configureSet(
    physics,
    (s) => s
        .after(input)
        .before(presentation)
        .runIf((world) => !world.getResource<Paused>()!.value),
  )
  ..addSystemToSet(ReadInputSystem(), input, schedule: Schedules.fixedUpdate)
  ..addSystemToSet(MoveSystem(), physics, schedule: Schedules.fixedUpdate)
  ..addSystemToSet(CollideSystem(), physics, schedule: Schedules.fixedUpdate)
  ..addSystem(
    FunctionSystem(
      'syncSprites',
      sets: [presentation],
      reads: {ComponentId.of<Position>()},
      run: (world) {},
    ),
    schedule: Schedules.fixedUpdate,
  );
```

Every `input` member runs before every `physics` member, which runs before
every `presentation` member, in whatever order they were registered. Some
rules:

- Configuration applies to members added before **or** after
  `configureSet`.
- Set constraints are transitive: if `a` is before `b` and `b` before `c`, `a`
  is before `c` even when `b` has no members in that schedule.
- Sets are shared across schedules; each schedule orders whichever members it
  has.
- Ordering a set doesn't order systems *inside* it. `MoveSystem` and
  `CollideSystem` above both write `Position` and are still left to
  registration order, so one of them needs an `after:`.
- A set's `runIf` gates every member, however it joined. A member with its
  own run condition runs only when both allow it.

The standard `FirstSets` and `UpdateSets` phases are sets like these; see
[Schedules & the Frame](/docs/scheduling/schedules#phases-of-first-and-update).

## Ordering against other packages

If your package depends on another, order against its `systemName`
constants. If it doesn't (two plugins that shouldn't know about each other),
use the standard phases: join `FirstSets.input`, run `after:
[FirstSets.content]`, join `UpdateSets.simulate`. Never order across packages
with string literals.

## Tips

- Declare reads and writes honestly. Under-declaring hides conflicts from the
  checker; over-declaring creates ones you'll have to resolve.
- Put `after:` on the system that depends on the other's result.
- Prefer a short chain (`a` → `b` → `c`) to edges from everything to
  everything.
- Use `exclusive: true` only for a system that really touches everything,
  such as one that rebuilds the world. It conflicts with every system in its
  schedule.

## See also

- [Schedules & the Frame](/docs/scheduling/schedules)
- [Systems](/docs/ecs/systems)
- [States & Run Conditions](/docs/ecs/states-run-conditions)
