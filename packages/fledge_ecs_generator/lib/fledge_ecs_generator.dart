/// Code generator for the Fledge ECS framework.
///
/// This package provides build_runner generators that analyze
/// @component and @system annotations to generate:
///
/// - Component registration code
/// - System wrapper classes with dependency metadata
///
/// ## Usage
///
/// Add to your `pubspec.yaml`:
///
/// ```yaml
/// dependencies:
///   fledge_ecs: ^0.1.0
///   fledge_ecs_annotations: ^0.1.0
///
/// dev_dependencies:
///   build_runner: ^2.4.0
///   fledge_ecs_generator: ^0.1.0
/// ```
///
/// Then run:
///
/// ```bash
/// dart run build_runner build
/// ```
library fledge_ecs_generator;

export 'src/component_generator.dart';
export 'src/system_generator.dart';
