# Installation

This guide will walk you through installing Fledge and setting up your development environment.

## Requirements

Before installing Fledge, ensure you have:

- **Dart SDK** 3.0 or higher
- **Flutter** 3.10 or higher (for rendering)
- A supported platform: **Windows**, **macOS**, or **Linux**

## Adding Fledge to Your Project

### 1. Add Dependencies

Add Fledge packages to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_ecs: ^0.1.0
  fledge_ecs_annotations: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
  fledge_ecs_generator: ^0.1.0
```

Then run:

```bash
flutter pub get
```

### 2. Configure Build Runner

Create or update your `build.yaml` to configure code generation:

```yaml
targets:
  $default:
    builders:
      fledge_ecs_generator|fledge_ecs:
        enabled: true
```

### 3. Run Code Generation

After defining your components and systems, run the build runner:

```bash
dart run build_runner build
```

Or use watch mode during development:

```bash
dart run build_runner watch
```

## Project Structure

We recommend organizing your Fledge project like this:

```
my_game/
├── lib/
│   ├── main.dart           # App entry point
│   ├── components/         # Component definitions
│   │   ├── position.dart
│   │   ├── velocity.dart
│   │   └── components.dart # Barrel file
│   ├── systems/            # System definitions
│   │   ├── movement.dart
│   │   ├── rendering.dart
│   │   └── systems.dart    # Barrel file
│   ├── resources/          # Global resources
│   │   └── time.dart
│   └── plugins/            # Game plugins
│       └── core_plugin.dart
├── pubspec.yaml
└── build.yaml
```

## Verifying Installation

Create a simple test file to verify everything is working:

```dart-tabs
// @tab Annotations
// lib/test_ecs.dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'test_ecs.g.dart';

@component
class TestComponent {
  final String value;
  TestComponent(this.value);
}

void main() {
  final world = World();

  final entityCommands = world.spawn()
    ..insert(TestComponent('Hello, Fledge!'));
  final entity = entityCommands.entity;

  final component = world.get<TestComponent>(entity);
  print(component?.value); // Should print: Hello, Fledge!

  print('Fledge is working correctly!');
}
// @tab Plain Classes
// lib/test_ecs.dart
import 'package:fledge_ecs/fledge_ecs.dart';

// Components are just plain Dart classes - no annotation needed
class TestComponent {
  final String value;
  TestComponent(this.value);
}

void main() {
  final world = World();

  final entityCommands = world.spawn()
    ..insert(TestComponent('Hello, Fledge!'));
  final entity = entityCommands.entity;

  final component = world.get<TestComponent>(entity);
  print(component?.value); // Should print: Hello, Fledge!

  print('Fledge is working correctly!');
}
```

Run the test:

```bash
dart run build_runner build  # Only needed if using annotations
dart run lib/test_ecs.dart
```

If you see "Fledge is working correctly!", you're all set!

## Next Steps

Now that you have Fledge installed, continue to the [Quick Start](/docs/getting-started/quick-start) guide to build your first game.
