import 'dart:typed_data';
import 'dart:ui' show Color, Rect, Size;

/// Descriptor for creating a texture.
class TextureDescriptor {
  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Texture format.
  final TextureFormat format;

  /// Whether this texture will be used as a render target.
  final bool isRenderTarget;

  /// Creates a texture descriptor.
  const TextureDescriptor({
    required this.width,
    required this.height,
    this.format = TextureFormat.rgba8,
    this.isRenderTarget = false,
  });
}

/// Texture formats.
enum TextureFormat {
  /// 8-bit RGBA.
  rgba8,

  /// 16-bit RGBA (floating point).
  rgba16f,

  /// 32-bit RGBA (floating point).
  rgba32f,

  /// Depth texture.
  depth,
}

/// Descriptor for creating a buffer.
class BufferDescriptor {
  /// Size in bytes.
  final int size;

  /// Buffer usage.
  final BufferUsage usage;

  /// Creates a buffer descriptor.
  const BufferDescriptor({
    required this.size,
    this.usage = BufferUsage.vertex,
  });
}

/// Buffer usage types.
enum BufferUsage {
  /// Vertex buffer.
  vertex,

  /// Index buffer.
  indices,

  /// Uniform buffer.
  uniform,
}

/// Abstract texture handle.
abstract class BackendTexture {
  /// Width in pixels.
  int get width;

  /// Height in pixels.
  int get height;

  /// Dispose the texture.
  void dispose();
}

/// Abstract buffer handle.
abstract class BackendBuffer {
  /// Size in bytes.
  int get size;

  /// Update buffer data.
  void update(ByteData data);

  /// Dispose the buffer.
  void dispose();
}

/// Blend modes for rendering.
enum BlendMode {
  /// No blending.
  none,

  /// Alpha blending.
  alpha,

  /// Additive blending.
  additive,

  /// Multiply blending.
  multiply,
}

/// Data for a sprite batch draw call.
class SpriteBatchData {
  /// The texture to use.
  final BackendTexture texture;

  /// Individual sprite instances.
  final List<SpriteInstanceData> sprites;

  /// Creates sprite batch data.
  const SpriteBatchData({
    required this.texture,
    required this.sprites,
  });
}

/// Data for a single sprite instance.
class SpriteInstanceData {
  /// Source rectangle in texture.
  final Rect sourceRect;

  /// Destination rectangle on screen.
  final Rect destRect;

  /// Tint color.
  final Color color;

  /// Rotation in radians.
  final double rotation;

  /// Creates sprite instance data.
  const SpriteInstanceData({
    required this.sourceRect,
    required this.destRect,
    this.color = const Color(0xFFFFFFFF),
    this.rotation = 0,
  });
}

/// Frame rendering context.
///
/// Provides methods for issuing draw calls during a frame.
abstract class FrameContext {
  /// Draw a batch of sprites.
  void drawSpriteBatch(SpriteBatchData batch);

  /// Set the current blend mode.
  void setBlendMode(BlendMode mode);

  /// Clear the current render target.
  void clear(Color color);
}

/// Capabilities of the current render backend.
class BackendCapabilities {
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

  /// Creates backend capabilities.
  const BackendCapabilities({
    required this.supportsShaders,
    required this.supportsInstancing,
    required this.supportsComputeShaders,
    required this.maxTextureSize,
    required this.maxBatchSize,
  });

  /// Capabilities for the Canvas API backend.
  static const canvas = BackendCapabilities(
    supportsShaders: false,
    supportsInstancing: false,
    supportsComputeShaders: false,
    maxTextureSize: 4096,
    maxBatchSize: 1000,
  );

  /// Capabilities for the flutter_gpu backend.
  static const gpu = BackendCapabilities(
    supportsShaders: true,
    supportsInstancing: true,
    supportsComputeShaders: true,
    maxTextureSize: 8192,
    maxBatchSize: 10000,
  );

  @override
  String toString() => 'BackendCapabilities('
      'shaders: $supportsShaders, '
      'instancing: $supportsInstancing, '
      'compute: $supportsComputeShaders, '
      'maxTexture: $maxTextureSize, '
      'maxBatch: $maxBatchSize)';
}

/// Abstract rendering backend.
///
/// Implementations provide either flutter_gpu (experimental, high-performance)
/// or Canvas API (stable, fallback) rendering.
///
/// Example:
/// ```dart
/// final backend = await BackendSelector.selectBest();
/// await backend.initialize();
///
/// // During each frame:
/// final frame = backend.beginFrame(size);
/// frame.drawSpriteBatch(batch);
/// backend.endFrame(frame);
/// ```
abstract class RenderBackend {
  /// Backend identifier.
  String get name;

  /// Check if this backend is available on the current platform.
  Future<bool> isAvailable();

  /// Initialize the backend.
  ///
  /// Must be called before any other methods.
  Future<void> initialize();

  /// Dispose backend resources.
  void dispose();

  /// Create a texture from image data.
  Future<BackendTexture> createTexture(TextureDescriptor descriptor);

  /// Create a texture from raw pixel data.
  Future<BackendTexture> createTextureFromData(
    TextureDescriptor descriptor,
    Uint8List data,
  );

  /// Create a vertex/index buffer.
  BackendBuffer createBuffer(BufferDescriptor descriptor);

  /// Begin a frame.
  ///
  /// Returns a [FrameContext] for issuing draw calls.
  FrameContext beginFrame(Size size);

  /// Submit frame for presentation.
  void endFrame(FrameContext context);

  /// Get backend capabilities.
  BackendCapabilities get capabilities;
}
