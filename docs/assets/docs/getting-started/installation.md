# Installation

Let's set up a new Fledge project. We'll create a Flutter desktop application with the core ECS packages.

## Requirements

- **Flutter** 3.10 or higher
- **Dart** 3.0 or higher
- A desktop platform: **Windows**, **macOS**, or **Linux**

## Create a New Project

First, create a new Flutter project with desktop support:

```bash
flutter create my_game --platforms=windows,macos,linux
cd my_game
```

## Add Dependencies

Open `pubspec.yaml` and add the Fledge packages:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Core ECS framework
  fledge_ecs: ^0.1.0

  # Optional: Annotations for code generation
  fledge_ecs_annotations: ^0.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

  # Optional: Code generator (if using annotations)
  build_runner: ^2.4.0
  fledge_ecs_generator: ^0.1.0
```

Then install:

```bash
flutter pub get
```

## Two Approaches: Annotations vs Plain Classes

Fledge supports two ways to define components and systems:

### 1. Annotations (Recommended for beginners)

Less boilerplate, code generation handles the details:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'components.g.dart';

@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@system
void movementSystem(World world) {
  // Your logic here
}
```

Run code generation:

```bash
dart run build_runner build
```

### 2. Plain Classes (Full control)

No code generation needed, explicit metadata:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

// Components are just classes
class Position {
  double x, y;
  Position(this.x, this.y);
}

// Systems implement the System interface
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    writes: {ComponentId.of<Position>()},
  );

  @override
  Future<void> run(World world) async {
    // Your logic here
  }
}
```

Both approaches are fully compatible. Use whichever you prefer!

## Verify Installation

Let's make sure everything works. Create a test file:

```dart
// lib/test_fledge.dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Greeting {
  final String message;
  Greeting(this.message);
}

void main() {
  final world = World();

  // Spawn an entity with a component
  final commands = world.spawn()
    ..insert(Greeting('Hello from Fledge!'));
  final entity = commands.entity;

  // Read the component back
  final greeting = world.get<Greeting>(entity);
  print(greeting?.message);

  print('Fledge is ready!');
}
```

Run it:

```bash
dart run lib/test_fledge.dart
```

You should see:

```
Hello from Fledge!
Fledge is ready!
```

## Recommended Project Structure

As your game grows, organize your code like this:

```
my_game/
├── lib/
│   ├── main.dart              # App entry point
│   ├── game/
│   │   ├── components/        # Component definitions
│   │   │   ├── position.dart
│   │   │   ├── velocity.dart
│   │   │   └── components.dart    # Barrel file
│   │   ├── systems/           # System definitions
│   │   │   ├── movement.dart
│   │   │   ├── collision.dart
│   │   │   └── systems.dart       # Barrel file
│   │   ├── resources/         # Global resources
│   │   │   └── game_config.dart
│   │   └── plugins/           # Game plugins
│   │       └── game_plugin.dart
│   └── ui/                    # Flutter widgets
│       └── game_screen.dart
├── pubspec.yaml
└── build.yaml                 # If using code generation
```

## What's Next?

Your project is set up! Let's write some actual code in [Hello Fledge](/docs/getting-started/hello-fledge) where we'll get something moving on screen.
