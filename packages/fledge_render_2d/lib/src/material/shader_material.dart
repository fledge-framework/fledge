import '../sprite/sprite.dart';
import 'material2d.dart';

/// Material that uses a custom shader program.
///
/// Shader materials allow for custom visual effects through GPU shaders.
/// They only work with backends that support shaders (e.g., flutter_gpu).
/// On backends that don't support shaders, shader materials gracefully
/// fall back to a basic sprite material.
///
/// Example:
/// ```dart
/// final waterShader = ShaderMaterial(
///   shader: waterEffectShader,
///   texture: waterTexture,
///   uniforms: {
///     'time': FloatUniform(elapsed),
///     'waveStrength': FloatUniform(0.05),
///   },
/// );
/// ```
class ShaderMaterial extends Material2D {
  /// The custom shader program.
  final ShaderHandle shader;

  /// Optional texture for the shader.
  final TextureHandle? texture;

  /// Uniform values to pass to the shader.
  final Map<String, UniformValue> uniforms;

  @override
  final BlendMode blendMode;

  /// Instance ID for batching uniqueness.
  ///
  /// Since shader materials often have unique uniforms, each instance
  /// gets a unique ID to prevent incorrect batching.
  final int _instanceId;

  static int _nextInstanceId = 0;

  /// Creates a shader material.
  ShaderMaterial({
    required this.shader,
    this.texture,
    Map<String, UniformValue>? uniforms,
    this.blendMode = BlendMode.normal,
  })  : uniforms = uniforms ?? {},
        _instanceId = _nextInstanceId++;

  @override
  Object get id => (ShaderMaterial, _instanceId);

  @override
  bool get hasShader => true;

  @override
  bool get supportsBatching => false;

  @override
  bool canBatchWith(Material2D other) => false;

  /// Set a uniform value.
  void setUniform(String name, UniformValue value) {
    uniforms[name] = value;
  }

  /// Set a float uniform.
  void setFloat(String name, double value) {
    uniforms[name] = FloatUniform(value);
  }

  /// Set a vec2 uniform.
  void setVec2(String name, double x, double y) {
    uniforms[name] = Vec2Uniform(x, y);
  }

  /// Set a vec3 uniform.
  void setVec3(String name, double x, double y, double z) {
    uniforms[name] = Vec3Uniform(x, y, z);
  }

  /// Set a vec4 uniform.
  void setVec4(String name, double x, double y, double z, double w) {
    uniforms[name] = Vec4Uniform(x, y, z, w);
  }

  /// Get a uniform value.
  UniformValue? getUniform(String name) => uniforms[name];

  /// Whether a uniform is set.
  bool hasUniform(String name) => uniforms.containsKey(name);

  @override
  String toString() => 'ShaderMaterial(shader: $shader, uniforms: $uniforms)';
}

/// Pre-built shader effects for common use cases.
///
/// These provide easy access to common shader effects without
/// writing custom shader code.
class ShaderEffects {
  ShaderEffects._();

  /// Create a grayscale effect material.
  static ShaderMaterial grayscale({
    required ShaderHandle shader,
    required TextureHandle texture,
    double intensity = 1.0,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'intensity': FloatUniform(intensity),
      },
    );
  }

  /// Create a color tint effect material.
  static ShaderMaterial colorTint({
    required ShaderHandle shader,
    required TextureHandle texture,
    required double r,
    required double g,
    required double b,
    double intensity = 1.0,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'tintColor': Vec3Uniform(r, g, b),
        'intensity': FloatUniform(intensity),
      },
    );
  }

  /// Create a wave distortion effect material.
  static ShaderMaterial waveDistortion({
    required ShaderHandle shader,
    required TextureHandle texture,
    double time = 0,
    double amplitude = 0.1,
    double frequency = 10,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'time': FloatUniform(time),
        'amplitude': FloatUniform(amplitude),
        'frequency': FloatUniform(frequency),
      },
    );
  }

  /// Create an outline effect material.
  static ShaderMaterial outline({
    required ShaderHandle shader,
    required TextureHandle texture,
    double thickness = 1.0,
    double r = 0,
    double g = 0,
    double b = 0,
    double a = 1,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'thickness': FloatUniform(thickness),
        'outlineColor': Vec4Uniform(r, g, b, a),
      },
    );
  }

  /// Create a glow effect material.
  static ShaderMaterial glow({
    required ShaderHandle shader,
    required TextureHandle texture,
    double intensity = 1.0,
    double radius = 2.0,
    double r = 1,
    double g = 1,
    double b = 1,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      blendMode: BlendMode.additive,
      uniforms: {
        'intensity': FloatUniform(intensity),
        'radius': FloatUniform(radius),
        'glowColor': Vec3Uniform(r, g, b),
      },
    );
  }

  /// Create a pixelate effect material.
  static ShaderMaterial pixelate({
    required ShaderHandle shader,
    required TextureHandle texture,
    double pixelSize = 4,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'pixelSize': FloatUniform(pixelSize),
      },
    );
  }

  /// Create a dissolve effect material.
  static ShaderMaterial dissolve({
    required ShaderHandle shader,
    required TextureHandle texture,
    TextureHandle? noiseTexture,
    double threshold = 0.5,
    double edgeWidth = 0.1,
    double r = 1,
    double g = 0.5,
    double b = 0,
  }) {
    return ShaderMaterial(
      shader: shader,
      texture: texture,
      uniforms: {
        'threshold': FloatUniform(threshold),
        'edgeWidth': FloatUniform(edgeWidth),
        'edgeColor': Vec3Uniform(r, g, b),
        if (noiseTexture != null) 'noiseTexture': TextureUniform(noiseTexture.id, samplerSlot: 1),
      },
    );
  }
}
