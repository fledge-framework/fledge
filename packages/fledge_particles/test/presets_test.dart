import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

TextureHandle _tex() => const TextureHandle(id: 42, width: 8, height: 8);

void main() {
  group('ParticleEmitter presets', () {
    test('fire returns a configured emitter with sane defaults', () {
      final e = ParticleEmitterPresets.fire(texture: _tex());
      expect(e.emitRate, greaterThan(0));
      expect(e.pool.capacity, greaterThan(0));
      expect(e.layer, DrawLayer.particles);
      expect(e.template.lifetimeMax, greaterThan(e.template.lifetimeMin));
      // Fire drifts upward on a Y-down world (negative Y).
      expect(e.template.velocityMax.y, lessThan(0));
    });

    test('smoke has a longer lifetime and grows in size', () {
      final e = ParticleEmitterPresets.smoke(texture: _tex());
      expect(e.template.lifetimeMin, greaterThan(1.0));
      expect(e.template.sizeStartToEnd, greaterThan(1.0));
      expect(e.layer, DrawLayer.particles);
    });

    test('spark has short lifetime and gravity pulls down', () {
      final e = ParticleEmitterPresets.spark(texture: _tex());
      expect(e.template.lifetimeMax, lessThan(1.0));
      // Positive Y acceleration = pulls down on a Y-down world.
      expect(e.template.acceleration.y, greaterThan(0));
    });

    test('trail spawns near-stationary particles that fade to zero', () {
      final e = ParticleEmitterPresets.trail(texture: _tex());
      // Velocity range is small — trail relies on emitter motion.
      final vmax = e.template.velocityMax;
      expect(vmax.x.abs(), lessThan(20));
      expect(vmax.y.abs(), lessThan(20));
      expect(e.template.colorEnd.a, 0);
    });

    test('each preset can override capacity, rate, layerSubOrder', () {
      final e = ParticleEmitterPresets.fire(
        texture: _tex(),
        emitRate: 5,
        capacity: 8,
        layerSubOrder: 42,
      );
      expect(e.emitRate, 5);
      expect(e.pool.capacity, 8);
      expect(e.layerSubOrder, 42);
    });
  });
}
