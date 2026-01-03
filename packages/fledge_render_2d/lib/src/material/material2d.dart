import 'dart:ui' show Color;

/// Blend mode for sprite rendering.
enum BlendMode {
  /// Normal alpha blending (default).
  normal,

  /// Additive blending (for glow effects).
  additive,

  /// Multiply blending (for shadows).
  multiply,

  /// Screen blending (for lightening).
  screen,

  /// No blending (opaque).
  none,
}

/// Base class for 2D materials.
///
/// Materials define how sprites are rendered, including blending,
/// texturing, and shader effects.
///
/// Materials are compared by [id] for batching purposes - sprites
/// with the same material ID can be batched together.
abstract class Material2D {
  /// Unique identifier for this material.
  ///
  /// Materials with the same ID can potentially be batched.
  Object get id;

  /// The blend mode for this material.
  BlendMode get blendMode => BlendMode.normal;

  /// Whether this material uses custom shaders.
  ///
  /// Materials with shaders may require different render paths.
  bool get hasShader => false;

  /// Whether this material supports batching with other instances.
  ///
  /// Some materials (e.g., with unique uniforms) cannot be batched.
  bool get supportsBatching => true;

  /// Compare if two materials can be batched together.
  ///
  /// By default, materials can batch if they have the same ID.
  bool canBatchWith(Material2D other) => id == other.id;

  @override
  bool operator ==(Object other) =>
      other is Material2D && other.runtimeType == runtimeType && other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

/// Reference to a shader program.
///
/// Wraps a shader that can be used for custom rendering effects.
class ShaderHandle {
  /// Unique identifier for this shader.
  final int id;

  /// The shader name or path.
  final String name;

  /// Creates a shader handle.
  const ShaderHandle({
    required this.id,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ShaderHandle && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ShaderHandle($id, $name)';
}

/// Uniform value that can be passed to shaders.
abstract class UniformValue {
  const UniformValue();
}

/// Float uniform value.
class FloatUniform extends UniformValue {
  final double value;
  const FloatUniform(this.value);
}

/// Vec2 uniform value.
class Vec2Uniform extends UniformValue {
  final double x;
  final double y;
  const Vec2Uniform(this.x, this.y);
}

/// Vec3 uniform value.
class Vec3Uniform extends UniformValue {
  final double x;
  final double y;
  final double z;
  const Vec3Uniform(this.x, this.y, this.z);
}

/// Vec4 uniform value.
class Vec4Uniform extends UniformValue {
  final double x;
  final double y;
  final double z;
  final double w;
  const Vec4Uniform(this.x, this.y, this.z, this.w);

  /// Create from color.
  factory Vec4Uniform.fromColor(Color color) {
    return Vec4Uniform(
      color.red / 255.0,
      color.green / 255.0,
      color.blue / 255.0,
      color.alpha / 255.0,
    );
  }
}

/// Matrix4 uniform value.
class Mat4Uniform extends UniformValue {
  final List<double> values;

  /// Creates a matrix uniform from 16 values (column-major).
  const Mat4Uniform(this.values) : assert(values.length == 16);

  /// Creates an identity matrix uniform.
  Mat4Uniform.identity()
      : values = const [
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ];
}

/// Texture uniform value.
class TextureUniform extends UniformValue {
  final int textureId;
  final int samplerSlot;

  const TextureUniform(this.textureId, {this.samplerSlot = 0});
}
