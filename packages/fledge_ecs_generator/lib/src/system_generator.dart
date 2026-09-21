import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Generates system wrappers for @system annotated functions.
///
/// Analyzes the function signature to determine:
/// - Which queries are used (from Query parameters)
/// - Which resources are accessed (from Res/ResMut parameters)
/// - Read vs write access patterns
///
/// Example input:
/// ```dart
/// @system
/// void movementSystem(Query2<Position, Velocity> query, Res<WallTime> time) {
///   for (final (_, pos, vel) in query.iter()) {
///     pos.x += vel.dx * time.value.delta;
///   }
/// }
/// ```
///
/// Example output:
/// ```dart
/// class MovementSystemWrapper implements System {
///   @override
///   SystemMeta get meta => SystemMeta(
///     name: 'movementSystem',
///     writes: {ComponentId.of<Position>()},
///     reads: {ComponentId.of<Velocity>()},
///     resourceReads: {WallTime},
///   );
///
///   @override
///   Future<void> run(World world) {
///     final query = world.query2<Position, Velocity>();
///     final time = Res<WallTime>(world.resource<WallTime>());
///     movementSystem(query, time);
///     return Future.value();
///   }
/// }
/// ```
class SystemGenerator extends GeneratorForAnnotation<SystemAnnotation> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@system can only be applied to top-level functions.',
        element: element,
      );
    }

    final functionName = element.name!;
    final className = _toClassName(functionName);
    final params = element.formalParameters;

    // Analyze parameters to extract component and resource access
    final analysis = _analyzeParameters(params);

    final buffer = StringBuffer();

    // Generate the system wrapper class
    buffer.writeln('/// Generated system wrapper for [$functionName].');
    buffer.writeln('class $className implements System {');

    // Generate meta
    buffer.writeln('  @override');
    buffer.writeln('  SystemMeta get meta => SystemMeta(');
    buffer.writeln("    name: '$functionName',");

    if (analysis.writes.isNotEmpty) {
      buffer.writeln('    writes: {${analysis.writes.join(', ')}},');
    }
    if (analysis.reads.isNotEmpty) {
      buffer.writeln('    reads: {${analysis.reads.join(', ')}},');
    }
    if (analysis.resourceReads.isNotEmpty) {
      buffer.writeln(
        '    resourceReads: {${analysis.resourceReads.join(', ')}},',
      );
    }
    if (analysis.resourceWrites.isNotEmpty) {
      buffer.writeln(
        '    resourceWrites: {${analysis.resourceWrites.join(', ')}},',
      );
    }
    if (analysis.eventReads.isNotEmpty) {
      buffer.writeln('    eventReads: {${analysis.eventReads.join(', ')}},');
    }
    if (analysis.eventWrites.isNotEmpty) {
      buffer.writeln('    eventWrites: {${analysis.eventWrites.join(', ')}},');
    }

    buffer.writeln('  );');
    buffer.writeln();

    // Generate runCondition getter
    buffer.writeln('  @override');
    buffer.writeln('  RunCondition? get runCondition => null;');
    buffer.writeln();

    // Generate shouldRun method
    buffer.writeln('  @override');
    buffer.writeln(
      '  bool shouldRun(World world) => runCondition?.call(world) ?? true;',
    );
    buffer.writeln();

    // Generate run method
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> run(World world) {');

    // Generate query/resource setup
    for (final param in analysis.parameterSetup) {
      buffer.writeln('    $param');
    }

    // Call the original function
    final args = params.map((p) => p.name!).join(', ');
    buffer.writeln('    $functionName($args);');
    buffer.writeln('    return Future.value();');
    buffer.writeln('  }');

    buffer.writeln('}');

    return buffer.toString();
  }

  String _toClassName(String functionName) {
    // Convert camelCase function name to PascalCase class name
    // e.g., movementSystem -> MovementSystemWrapper
    final pascal = functionName[0].toUpperCase() + functionName.substring(1);
    return '${pascal}Wrapper';
  }

  _ParameterAnalysis _analyzeParameters(List<FormalParameterElement> params) {
    final analysis = _ParameterAnalysis();

    for (final param in params) {
      final type = param.type;
      final paramName = param.name!;

      if (type is InterfaceType) {
        final typeName = type.element.name ?? '';

        // Check for Query / QueryMut types.
        //
        // We match both `QueryN<...>` (read-only intent marker) and
        // `QueryMutN<...>` (write intent marker). The distinction is decoded
        // inside [_analyzeQueryParameter] which routes the component types
        // into the reads or writes bucket accordingly.
        if (typeName.startsWith('Query')) {
          _analyzeQueryParameter(type, analysis, paramName);
        }
        // Check for World parameter - no setup needed, passed directly
        else if (typeName == 'World') {
          // World is passed directly, no setup needed
        }
        // Check for Commands parameter
        else if (typeName == 'Commands') {
          analysis.parameterSetup.add('final $paramName = Commands();');
          analysis.needsCommandsApply = true;
        }
        // Check for Res<T> parameter (read-only resource access)
        else if (typeName == 'Res') {
          _analyzeResParameter(type, analysis, paramName, isWrite: false);
        }
        // Check for ResMut<T> parameter (mutable resource access)
        else if (typeName == 'ResMut') {
          _analyzeResParameter(type, analysis, paramName, isWrite: true);
        }
        // Check for ResOption<T> parameter
        else if (typeName == 'ResOption') {
          _analyzeResOptionParameter(type, analysis, paramName);
        }
        // Check for EventReader<T> parameter
        else if (typeName == 'EventReader') {
          _analyzeEventReaderParameter(type, analysis, paramName);
        }
        // Check for EventWriter<T> parameter
        else if (typeName == 'EventWriter') {
          _analyzeEventWriterParameter(type, analysis, paramName);
        }
        // Check for EventReadWriter<T> parameter
        else if (typeName == 'EventReadWriter') {
          _analyzeEventReadWriterParameter(type, analysis, paramName);
        }
      }
    }

    return analysis;
  }

  void _analyzeResParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName, {
    required bool isWrite,
  }) {
    final typeArgs = type.typeArguments;
    if (typeArgs.isEmpty) return;

    final resourceType = typeArgs.first;
    if (resourceType is InterfaceType) {
      final resourceTypeName = resourceType.element.name!;

      if (isWrite) {
        analysis.resourceWrites.add(resourceTypeName);
      } else {
        analysis.resourceReads.add(resourceTypeName);
      }

      final wrapperType = isWrite ? 'ResMut' : 'Res';
      analysis.parameterSetup.add(
        'final $paramName = $wrapperType<$resourceTypeName>(world.getResource<$resourceTypeName>()!);',
      );
    }
  }

  void _analyzeResOptionParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName,
  ) {
    final typeArgs = type.typeArguments;
    if (typeArgs.isEmpty) return;

    final resourceType = typeArgs.first;
    if (resourceType is InterfaceType) {
      final resourceTypeName = resourceType.element.name!;
      analysis.resourceReads.add(resourceTypeName);
      analysis.parameterSetup.add(
        'final $paramName = ResOption<$resourceTypeName>(world.getResource<$resourceTypeName>());',
      );
    }
  }

  void _analyzeEventReaderParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName,
  ) {
    final typeArgs = type.typeArguments;
    if (typeArgs.isEmpty) return;

    final eventType = typeArgs.first;
    if (eventType is InterfaceType) {
      final eventTypeName = eventType.element.name!;
      analysis.eventReads.add(eventTypeName);
      analysis.parameterSetup.add(
        'final $paramName = world.eventReader<$eventTypeName>();',
      );
    }
  }

  void _analyzeEventWriterParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName,
  ) {
    final typeArgs = type.typeArguments;
    if (typeArgs.isEmpty) return;

    final eventType = typeArgs.first;
    if (eventType is InterfaceType) {
      final eventTypeName = eventType.element.name!;
      analysis.eventWrites.add(eventTypeName);
      analysis.parameterSetup.add(
        'final $paramName = world.eventWriter<$eventTypeName>();',
      );
    }
  }

  void _analyzeEventReadWriterParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName,
  ) {
    final typeArgs = type.typeArguments;
    if (typeArgs.isEmpty) return;

    final eventType = typeArgs.first;
    if (eventType is InterfaceType) {
      final eventTypeName = eventType.element.name!;
      analysis.eventReads.add(eventTypeName);
      analysis.eventWrites.add(eventTypeName);
      analysis.parameterSetup.add(
        'final $paramName = EventReadWriter<$eventTypeName>(world.events.queue<$eventTypeName>());',
      );
    }
  }

  void _analyzeQueryParameter(
    InterfaceType type,
    _ParameterAnalysis analysis,
    String paramName,
  ) {
    // Distinguish read vs write intent by the parameter's declared type name.
    //
    // `QueryN<...>`    -> every T is a read.
    // `QueryMutN<...>` -> every T is a write.
    //
    // We deliberately do NOT try to infer access patterns from the function
    // body: mixed reads/writes on the same query are out of scope. Users
    // needing mixed access should split the query into two parameters (one
    // Query, one QueryMut) or hand-write SystemMeta on a class-based
    // `System` subclass.
    final typeName = type.element.name ?? '';
    final isMut = typeName.startsWith('QueryMut');
    final typeArgs = type.typeArguments;

    final componentTypes = <String>[];
    for (final arg in typeArgs) {
      if (arg is InterfaceType) {
        componentTypes.add(arg.element.name!);
      }
    }

    final bucket = isMut ? analysis.writes : analysis.reads;
    for (final t in componentTypes) {
      bucket.add('ComponentId.of<$t>()');
    }

    // Generate query setup: pick the queryN or queryMutN factory based on
    // the parameter's declared type.
    if (typeArgs.isNotEmpty) {
      final typeArgsStr = typeArgs
          .map((t) {
            if (t is InterfaceType) {
              return t.element.name!;
            }
            return t.toString();
          })
          .join(', ');

      final method = isMut
          ? 'queryMut${typeArgs.length}'
          : 'query${typeArgs.length}';
      analysis.parameterSetup.add(
        'final $paramName = world.$method<$typeArgsStr>();',
      );
    }
  }
}

class _ParameterAnalysis {
  final List<String> reads = [];
  final List<String> writes = [];
  final List<String> resourceReads = [];
  final List<String> resourceWrites = [];
  final List<String> eventReads = [];
  final List<String> eventWrites = [];
  final List<String> parameterSetup = [];
  bool needsCommandsApply = false;
}
