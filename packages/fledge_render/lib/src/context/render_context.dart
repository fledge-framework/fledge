/// Size of a render target in logical pixels.
class RenderSize {
  /// Width in logical pixels.
  final double width;

  /// Height in logical pixels.
  final double height;

  /// Creates a render size.
  const RenderSize(this.width, this.height);

  /// Creates a zero-sized render size.
  static const zero = RenderSize(0, 0);

  /// The aspect ratio (width / height).
  double get aspectRatio => height == 0 ? 0 : width / height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'RenderSize($width, $height)';
}

/// Abstract render context passed to render nodes for GPU operations.
///
/// This interface is implemented by backend-specific contexts
/// (e.g., GpuRenderContext, CanvasRenderContext) to provide
/// platform-specific rendering capabilities.
abstract class RenderContext {
  /// The size of the render target in logical pixels.
  RenderSize get screenSize;

  /// The current frame number.
  int get frameNumber;

  /// The time elapsed since the last frame in seconds.
  double get deltaTime;

  /// The total time elapsed since rendering started in seconds.
  double get totalTime;
}

/// Capabilities of the current render backend.
///
/// Used to query what features are available on the current platform.
class RenderCapabilities {
  /// Whether custom shaders are supported.
  final bool supportsShaders;

  /// Whether GPU instancing is supported.
  final bool supportsInstancing;

  /// Whether compute shaders are supported.
  final bool supportsComputeShaders;

  /// Maximum texture size in pixels.
  final int maxTextureSize;

  /// Maximum number of sprites per batch.
  final int maxBatchSize;

  /// Creates render capabilities.
  const RenderCapabilities({
    required this.supportsShaders,
    required this.supportsInstancing,
    required this.supportsComputeShaders,
    required this.maxTextureSize,
    required this.maxBatchSize,
  });

  /// Capabilities for the Canvas API backend.
  static const canvas = RenderCapabilities(
    supportsShaders: false,
    supportsInstancing: false,
    supportsComputeShaders: false,
    maxTextureSize: 4096,
    maxBatchSize: 1000,
  );

  /// Capabilities for the flutter_gpu backend.
  static const gpu = RenderCapabilities(
    supportsShaders: true,
    supportsInstancing: true,
    supportsComputeShaders: true,
    maxTextureSize: 8192,
    maxBatchSize: 10000,
  );

  @override
  String toString() => 'RenderCapabilities('
      'shaders: $supportsShaders, '
      'instancing: $supportsInstancing, '
      'compute: $supportsComputeShaders, '
      'maxTexture: $maxTextureSize, '
      'maxBatch: $maxBatchSize)';
}
