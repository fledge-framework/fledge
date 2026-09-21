import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show DrawLayer, TextureHandle;
import 'package:vector_math/vector_math.dart';

import 'emitter.dart';
import 'particle.dart';

/// Factory presets for [ParticleEmitter].
///
/// Each preset returns a fully-configured emitter with a matching
/// [ParticleTemplate] and a modestly-sized [ParticlePool]. Games are
/// expected to override fields on the returned emitter for local
/// tweaks — pool capacity, emit rate, the template's ranges — since
/// the defaults are intentionally conservative.
extension ParticleEmitterPresets on ParticleEmitter {
  /// Orange-to-red flame particles with an upward velocity and a
  /// medium lifetime.
  ///
  /// Suitable for torches, campfires, and other steady-state flames.
  /// Set [emitRate] high (~60/s) for a dense fire, lower (~15/s) for a
  /// candle.
  static ParticleEmitter fire({
    required TextureHandle texture,
    double emitRate = 60.0,
    int capacity = 128,
    DrawLayer layer = DrawLayer.particles,
    int layerSubOrder = 0,
    math.Random? rng,
  }) {
    final template = ParticleTemplate(
      lifetimeMin: 0.6,
      lifetimeMax: 1.2,
      velocityMin: Vector2(-12, -80),
      velocityMax: Vector2(12, -40),
      acceleration: Vector2(0, -10),
      sizeMin: 6,
      sizeMax: 10,
      sizeStartToEnd: 0.2,
      colorStart: const Color(0xFFFFC060),
      colorEnd: const Color(0x00E03020),
      angularVelocityMin: -1.0,
      angularVelocityMax: 1.0,
    );
    return ParticleEmitter(
      template: template,
      emitRate: emitRate,
      texture: texture,
      pool: ParticlePool(capacity),
      layer: layer,
      layerSubOrder: layerSubOrder,
      rng: rng,
    );
  }

  /// Gray, slow-drifting smoke particles with a long lifetime and an
  /// alpha fade to zero.
  ///
  /// Pairs well with [fire] as a chimney/plume layer or as its own
  /// steam/exhaust effect.
  static ParticleEmitter smoke({
    required TextureHandle texture,
    double emitRate = 20.0,
    int capacity = 96,
    DrawLayer layer = DrawLayer.particles,
    int layerSubOrder = 0,
    math.Random? rng,
  }) {
    final template = ParticleTemplate(
      lifetimeMin: 1.5,
      lifetimeMax: 3.0,
      velocityMin: Vector2(-8, -30),
      velocityMax: Vector2(8, -18),
      acceleration: Vector2(0, -4),
      sizeMin: 10,
      sizeMax: 18,
      sizeStartToEnd: 2.0,
      colorStart: const Color(0xB0808080),
      colorEnd: const Color(0x00505050),
      angularVelocityMin: -0.5,
      angularVelocityMax: 0.5,
    );
    return ParticleEmitter(
      template: template,
      emitRate: emitRate,
      texture: texture,
      pool: ParticlePool(capacity),
      layer: layer,
      layerSubOrder: layerSubOrder,
      rng: rng,
    );
  }

  /// Bright, short-lived spark particles that fall under gravity.
  ///
  /// Meant for impact effects, muzzle flashes, and hit reactions —
  /// short lifetime, wide velocity spread, positive gravity so they
  /// arc downward.
  static ParticleEmitter spark({
    required TextureHandle texture,
    double emitRate = 200.0,
    int capacity = 64,
    DrawLayer layer = DrawLayer.particles,
    int layerSubOrder = 0,
    math.Random? rng,
  }) {
    final template = ParticleTemplate(
      lifetimeMin: 0.15,
      lifetimeMax: 0.4,
      velocityMin: Vector2(-140, -140),
      velocityMax: Vector2(140, 60),
      acceleration: Vector2(0, 240),
      sizeMin: 2,
      sizeMax: 4,
      sizeStartToEnd: 0.6,
      colorStart: const Color(0xFFFFF0A0),
      colorEnd: const Color(0x00FF8020),
      angularVelocityMin: -4.0,
      angularVelocityMax: 4.0,
    );
    return ParticleEmitter(
      template: template,
      emitRate: emitRate,
      texture: texture,
      pool: ParticlePool(capacity),
      layer: layer,
      layerSubOrder: layerSubOrder,
      rng: rng,
    );
  }

  /// Trail particles that sit roughly on-position and fade quickly.
  ///
  /// Meant to be attached to a moving entity — the emitter's own
  /// motion (via its `GlobalTransform2D`) supplies the trailing
  /// spatial spread; per-particle velocity stays near zero so
  /// particles stick where they were dropped.
  static ParticleEmitter trail({
    required TextureHandle texture,
    double emitRate = 45.0,
    int capacity = 80,
    DrawLayer layer = DrawLayer.particles,
    int layerSubOrder = 0,
    math.Random? rng,
  }) {
    final template = ParticleTemplate(
      lifetimeMin: 0.3,
      lifetimeMax: 0.6,
      velocityMin: Vector2(-4, -4),
      velocityMax: Vector2(4, 4),
      acceleration: Vector2.zero(),
      sizeMin: 4,
      sizeMax: 6,
      sizeStartToEnd: 0.0,
      colorStart: const Color(0xFFC0E0FF),
      colorEnd: const Color(0x0060A0FF),
    );
    return ParticleEmitter(
      template: template,
      emitRate: emitRate,
      texture: texture,
      pool: ParticlePool(capacity),
      layer: layer,
      layerSubOrder: layerSubOrder,
      rng: rng,
    );
  }
}
