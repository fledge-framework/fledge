import 'dart:ui' show Color;

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlendMode', () {
    test('has all expected values', () {
      expect(BlendMode.values, contains(BlendMode.normal));
      expect(BlendMode.values, contains(BlendMode.additive));
      expect(BlendMode.values, contains(BlendMode.multiply));
      expect(BlendMode.values, contains(BlendMode.screen));
      expect(BlendMode.values, contains(BlendMode.none));
    });
  });

  group('ShaderHandle', () {
    test('creates with id and name', () {
      const handle = ShaderHandle(id: 1, name: 'my_shader');
      expect(handle.id, 1);
      expect(handle.name, 'my_shader');
    });

    test('equality based on id', () {
      const a = ShaderHandle(id: 1, name: 'shader_a');
      const b = ShaderHandle(id: 1, name: 'shader_b');
      const c = ShaderHandle(id: 2, name: 'shader_a');

      expect(a, equals(b)); // Same ID
      expect(a, isNot(equals(c))); // Different ID
    });
  });

  group('Uniform values', () {
    test('FloatUniform', () {
      const uniform = FloatUniform(3.14);
      expect(uniform.value, 3.14);
    });

    test('Vec2Uniform', () {
      const uniform = Vec2Uniform(1.0, 2.0);
      expect(uniform.x, 1.0);
      expect(uniform.y, 2.0);
    });

    test('Vec3Uniform', () {
      const uniform = Vec3Uniform(1.0, 2.0, 3.0);
      expect(uniform.x, 1.0);
      expect(uniform.y, 2.0);
      expect(uniform.z, 3.0);
    });

    test('Vec4Uniform', () {
      const uniform = Vec4Uniform(1.0, 2.0, 3.0, 4.0);
      expect(uniform.x, 1.0);
      expect(uniform.y, 2.0);
      expect(uniform.z, 3.0);
      expect(uniform.w, 4.0);
    });

    test('Vec4Uniform.fromColor', () {
      const color = Color(0x80FF8040); // ARGB
      final uniform = Vec4Uniform.fromColor(color);

      expect(uniform.x, closeTo(1.0, 0.01)); // R = 0xFF
      expect(uniform.y, closeTo(0.5, 0.01)); // G = 0x80
      expect(uniform.z, closeTo(0.25, 0.01)); // B = 0x40
      expect(uniform.w, closeTo(0.5, 0.01)); // A = 0x80
    });

    test('Mat4Uniform.identity', () {
      final uniform = Mat4Uniform.identity();
      expect(uniform.values[0], 1);
      expect(uniform.values[5], 1);
      expect(uniform.values[10], 1);
      expect(uniform.values[15], 1);
      // Off-diagonal should be 0
      expect(uniform.values[1], 0);
      expect(uniform.values[4], 0);
    });

    test('TextureUniform', () {
      const uniform = TextureUniform(5, samplerSlot: 2);
      expect(uniform.textureId, 5);
      expect(uniform.samplerSlot, 2);
    });
  });

  group('SpriteMaterial', () {
    test('creates with defaults', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final material = SpriteMaterial(texture: texture);

      expect(material.texture, texture);
      expect(material.tint.value, 0xFFFFFFFF);
      expect(material.blendMode, BlendMode.normal);
      expect(material.alphaThreshold, 0);
      expect(material.hasShader, isFalse);
      expect(material.supportsBatching, isTrue);
    });

    test('creates with custom values', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final material = SpriteMaterial(
        texture: texture,
        tint: const Color(0xFF00FF00),
        blendMode: BlendMode.additive,
        alphaThreshold: 0.5,
      );

      expect(material.tint.value, 0xFF00FF00);
      expect(material.blendMode, BlendMode.additive);
      expect(material.alphaThreshold, 0.5);
    });

    test('can batch with same texture and blend mode', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final a = SpriteMaterial(texture: texture);
      final b = SpriteMaterial(
        texture: texture,
        tint: const Color(0xFF0000FF), // Different tint is OK
      );

      expect(a.canBatchWith(b), isTrue);
    });

    test('cannot batch with different texture', () {
      const texture1 = TextureHandle(id: 1, width: 64, height: 64);
      const texture2 = TextureHandle(id: 2, width: 64, height: 64);

      final a = SpriteMaterial(texture: texture1);
      final b = SpriteMaterial(texture: texture2);

      expect(a.canBatchWith(b), isFalse);
    });

    test('cannot batch with different blend mode', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);

      final a = SpriteMaterial(texture: texture, blendMode: BlendMode.normal);
      final b = SpriteMaterial(texture: texture, blendMode: BlendMode.additive);

      expect(a.canBatchWith(b), isFalse);
    });

    test('cannot batch with different alpha threshold', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);

      final a = SpriteMaterial(texture: texture, alphaThreshold: 0);
      final b = SpriteMaterial(texture: texture, alphaThreshold: 0.5);

      expect(a.canBatchWith(b), isFalse);
    });

    test('cannot batch with non-SpriteMaterial', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final sprite = SpriteMaterial(texture: texture);
      final color = ColorMaterial(color: const Color(0xFFFFFFFF));

      expect(sprite.canBatchWith(color), isFalse);
    });

    test('copyWith creates modified copy', () {
      const texture1 = TextureHandle(id: 1, width: 64, height: 64);
      const texture2 = TextureHandle(id: 2, width: 128, height: 128);

      final original = SpriteMaterial(texture: texture1);
      final copy = original.copyWith(
        texture: texture2,
        tint: const Color(0xFF00FF00),
      );

      expect(copy.texture, texture2);
      expect(copy.tint.value, 0xFF00FF00);
      expect(original.texture, texture1); // Original unchanged
    });
  });

  group('ColorMaterial', () {
    test('creates with color', () {
      final material = ColorMaterial(color: const Color(0xFF0000FF));

      expect(material.color.value, 0xFF0000FF);
      expect(material.blendMode, BlendMode.normal);
      expect(material.hasShader, isFalse);
    });

    test('can batch with same blend mode', () {
      final a = ColorMaterial(color: const Color(0xFFFF0000));
      final b = ColorMaterial(color: const Color(0xFF00FF00));

      expect(a.canBatchWith(b), isTrue);
    });

    test('cannot batch with different blend mode', () {
      final a = ColorMaterial(
        color: const Color(0xFFFF0000),
        blendMode: BlendMode.normal,
      );
      final b = ColorMaterial(
        color: const Color(0xFFFF0000),
        blendMode: BlendMode.additive,
      );

      expect(a.canBatchWith(b), isFalse);
    });

    test('copyWith creates modified copy', () {
      final original = ColorMaterial(color: const Color(0xFFFF0000));
      final copy = original.copyWith(
        color: const Color(0xFF00FF00),
        blendMode: BlendMode.multiply,
      );

      expect(copy.color.value, 0xFF00FF00);
      expect(copy.blendMode, BlendMode.multiply);
    });
  });

  group('ShaderMaterial', () {
    test('creates with shader', () {
      const shader = ShaderHandle(id: 1, name: 'custom');
      const texture = TextureHandle(id: 1, width: 64, height: 64);

      final material = ShaderMaterial(
        shader: shader,
        texture: texture,
      );

      expect(material.shader, shader);
      expect(material.texture, texture);
      expect(material.hasShader, isTrue);
      expect(material.supportsBatching, isFalse);
    });

    test('each instance has unique id', () {
      const shader = ShaderHandle(id: 1, name: 'custom');

      final a = ShaderMaterial(shader: shader);
      final b = ShaderMaterial(shader: shader);

      expect(a.id, isNot(equals(b.id)));
    });

    test('cannot batch', () {
      const shader = ShaderHandle(id: 1, name: 'custom');

      final a = ShaderMaterial(shader: shader);
      final b = ShaderMaterial(shader: shader);

      expect(a.canBatchWith(b), isFalse);
      expect(a.canBatchWith(a), isFalse); // Not even with itself
    });

    test('setUniform and getUniform', () {
      const shader = ShaderHandle(id: 1, name: 'custom');
      final material = ShaderMaterial(shader: shader);

      material.setUniform('time', const FloatUniform(1.5));

      expect(material.hasUniform('time'), isTrue);
      expect(material.getUniform('time'), isA<FloatUniform>());
      expect((material.getUniform('time') as FloatUniform).value, 1.5);
    });

    test('convenience setters', () {
      const shader = ShaderHandle(id: 1, name: 'custom');
      final material = ShaderMaterial(shader: shader);

      material.setFloat('f', 1.0);
      material.setVec2('v2', 1.0, 2.0);
      material.setVec3('v3', 1.0, 2.0, 3.0);
      material.setVec4('v4', 1.0, 2.0, 3.0, 4.0);

      expect(material.getUniform('f'), isA<FloatUniform>());
      expect(material.getUniform('v2'), isA<Vec2Uniform>());
      expect(material.getUniform('v3'), isA<Vec3Uniform>());
      expect(material.getUniform('v4'), isA<Vec4Uniform>());
    });
  });

  group('ShaderEffects', () {
    const shader = ShaderHandle(id: 1, name: 'effect');
    const texture = TextureHandle(id: 1, width: 64, height: 64);

    test('grayscale', () {
      final material = ShaderEffects.grayscale(
        shader: shader,
        texture: texture,
        intensity: 0.8,
      );

      expect(material.hasUniform('intensity'), isTrue);
      expect(
        (material.getUniform('intensity') as FloatUniform).value,
        0.8,
      );
    });

    test('colorTint', () {
      final material = ShaderEffects.colorTint(
        shader: shader,
        texture: texture,
        r: 1.0,
        g: 0.5,
        b: 0.0,
      );

      expect(material.hasUniform('tintColor'), isTrue);
      expect(material.hasUniform('intensity'), isTrue);
    });

    test('waveDistortion', () {
      final material = ShaderEffects.waveDistortion(
        shader: shader,
        texture: texture,
        time: 2.5,
        amplitude: 0.2,
        frequency: 15,
      );

      expect(material.hasUniform('time'), isTrue);
      expect(material.hasUniform('amplitude'), isTrue);
      expect(material.hasUniform('frequency'), isTrue);
    });

    test('outline', () {
      final material = ShaderEffects.outline(
        shader: shader,
        texture: texture,
        thickness: 2.0,
        r: 1,
        g: 0,
        b: 0,
      );

      expect(material.hasUniform('thickness'), isTrue);
      expect(material.hasUniform('outlineColor'), isTrue);
    });

    test('glow', () {
      final material = ShaderEffects.glow(
        shader: shader,
        texture: texture,
        intensity: 2.0,
        radius: 4.0,
      );

      expect(material.blendMode, BlendMode.additive);
      expect(material.hasUniform('intensity'), isTrue);
      expect(material.hasUniform('radius'), isTrue);
      expect(material.hasUniform('glowColor'), isTrue);
    });

    test('pixelate', () {
      final material = ShaderEffects.pixelate(
        shader: shader,
        texture: texture,
        pixelSize: 8,
      );

      expect(material.hasUniform('pixelSize'), isTrue);
    });

    test('dissolve', () {
      final material = ShaderEffects.dissolve(
        shader: shader,
        texture: texture,
        threshold: 0.3,
        edgeWidth: 0.2,
      );

      expect(material.hasUniform('threshold'), isTrue);
      expect(material.hasUniform('edgeWidth'), isTrue);
      expect(material.hasUniform('edgeColor'), isTrue);
    });
  });
}
