# Installation

Fledge is a set of packages, all released together at the same version. You
add the ones your game needs.

## Requirements

| You're building | You need |
|---|---|
| A Flutter game (graphics, input, audio...) | Flutter 3.50 or newer (Dart 3.14+) |
| Pure Dart code: a headless server, a simulation, tools, tests | Dart 3.11 or newer |

The pure-Dart packages are `fledge_ecs`, `fledge_ecs_annotations`,
`fledge_ecs_generator`, `fledge_assets`, `fledge_calendar`, `fledge_net` and
`fledge_net_steam`. Every other package depends on Flutter. The
[Package Catalog](/docs/app/packages) lists them all.

Desktop (Windows, macOS, Linux) is the primary target. Web and mobile are
best-effort; check each package's page.

## A Flutter game

Create a desktop project:

```bash
flutter create --platforms=windows,macos,linux my_game
cd my_game
```

Then edit `pubspec.yaml`. Fledge's Flutter packages need the same floors, and
Material comes from the `material_ui` package:

```yaml
environment:
  sdk: ^3.14.0
  flutter: ">=3.50.0"

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.0
  fledge_ecs: ^0.7.0
  fledge_input: ^0.7.0       # keyboard, mouse and gamepad actions
  fledge_render_2d: ^0.7.0   # sprites, transforms, the render world
```

```bash
flutter pub get
```

**Material imports.** Material moved out of the Flutter SDK into
`package:material_ui`. On Flutter 3.50 `flutter create` already imports
`package:material_ui/material_ui.dart`. If your project (or an older
template) still has `import 'package:flutter/material.dart';` in
`lib/main.dart` or `test/widget_test.dart`, replace it with:

```dart
import 'package:material_ui/material_ui.dart';
```

and keep `material_ui` in your dependencies. The old import is deprecated.

**Name clashes.** `fledge_ecs` exports a `State<S>` resource for state
machines, which clashes with Flutter's `State<T>`. In files that define
widgets, hide one of them:

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:material_ui/material_ui.dart';
```

## A pure-Dart project

For a server, a simulation or tests that don't need Flutter:

```bash
dart create -t console my_sim
cd my_sim
dart pub add fledge_ecs:^0.7.0
```

```yaml
environment:
  sdk: ^3.11.0

dependencies:
  fledge_ecs: ^0.7.0
```

Check it works by replacing `bin/my_sim.dart` with:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Greeting {
  final String message;
  Greeting(this.message);
}

Future<void> main() async {
  final app = App()
    ..addSystem(
      FunctionSystem(
        'greet',
        run: (world) {
          for (final (_, greeting) in world.query1<Greeting>().iter()) {
            print(greeting.message);
          }
        },
      ),
    );

  app.world.spawnWith([Greeting('Hello from Fledge!')]);
  await app.tick();
}
```

```bash
dart run
```

```
Hello from Fledge!
```

## Code generation (optional)

`fledge_ecs_generator` turns annotated functions into system classes (see
[Code Generation](/docs/app/codegen)). Add it and `build_runner` as dev
dependencies:

```yaml
dependencies:
  fledge_ecs: ^0.7.0

dev_dependencies:
  build_runner: ^2.10.4
  fledge_ecs_generator: ^0.7.0
```

`fledge_ecs` re-exports the annotations (`@system`, `@component`), so you only
need a direct `fledge_ecs_annotations` dependency if you import
`package:fledge_ecs_annotations` yourself.

Run the generator after changing an annotated file, or keep it watching:

```bash
dart run build_runner build
dart run build_runner watch
```

Generated `*.g.dart` files are build output. Most projects don't commit them
(add `*.g.dart` to `.gitignore`), which means CI must run
`dart run build_runner build` before `dart analyze` or the tests.

## Project layout

There's no required structure. One that scales well:

```
lib/
  main.dart              runApp and the game widget
  game/
    components.dart      data
    resources.dart
    systems/             one file per system or group of systems
    game_plugin.dart     registers everything with the App
test/
  schedule_test.dart     checkScheduleOrdering() is empty
```

Next: [Your First App](/docs/getting-started/first-app).
