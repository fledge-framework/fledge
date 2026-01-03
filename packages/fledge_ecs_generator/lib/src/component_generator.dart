import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Generates registration code for @component annotated classes.
///
/// For each component class, generates:
/// - A ComponentId getter for type-safe access
///
/// Example input:
/// ```dart
/// @component
/// class Position {
///   double x, y;
///   Position(this.x, this.y);
/// }
/// ```
///
/// Example output:
/// ```dart
/// extension PositionComponentExtension on Position {
///   static ComponentId get componentId => ComponentId.of<Position>();
/// }
/// ```
class ComponentGenerator extends GeneratorForAnnotation<Component> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@component can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    final buffer = StringBuffer();

    // Generate extension with componentId getter
    buffer.writeln('/// Generated component extension for [$className].');
    buffer.writeln('extension ${className}ComponentExtension on $className {');
    buffer.writeln('  /// The unique [ComponentId] for this component type.');
    buffer.writeln(
        '  static ComponentId get componentId => ComponentId.of<$className>();');
    buffer.writeln('}');

    return buffer.toString();
  }
}
