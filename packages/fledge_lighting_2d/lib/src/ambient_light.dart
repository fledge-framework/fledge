import 'dart:ui' show Color;

/// How [AmbientLight] is applied to the scene by
/// [LitFledgeRenderView].
enum AmbientBlend {
  /// Legacy behaviour: paint the ambient fill *before* sprites, at
  /// normal blend. Sprites always draw at full brightness on top;
  /// the ambient only tints empty cells. Kept as the default so
  /// existing games are unaffected.
  underSprites,

  /// Paint the ambient fill *after* sprites, using `BlendMode.multiply`
  /// so it darkens (or tints) the sprite layer too. Additive lights
  /// then still brighten pixels on top. In this mode the pre-sprite
  /// ambient fill is skipped so empty cells are not double-darkened.
  overSprites,
}

/// Scene-wide ambient illumination.
///
/// Inserted as an ECS resource by [LightingPlugin] and consumed by
/// [LitFledgeRenderView]. By default the ambient rect is drawn as a
/// base fill *under* the sprite pass — set [blend] to
/// [AmbientBlend.overSprites] to have it darken the sprites as well.
///
/// A default of white at 0.5 intensity gives "everything is dim by
/// half"; set to [AmbientLight.dark] (or a fully black variant) for a
/// scene where sprites are only visible through the additive light
/// contributions.
class AmbientLight {
  /// Ambient color. In [AmbientBlend.underSprites] this is the color
  /// of the pre-sprite fill; in [AmbientBlend.overSprites] it is the
  /// tint the multiply blend darkens toward.
  final Color color;

  /// Intensity in `[0, 1]`.
  ///
  /// - [AmbientBlend.underSprites]: alpha multiplier on the pre-sprite
  ///   fill. `0` disables ambient, `1` fills at the color's literal
  ///   alpha.
  /// - [AmbientBlend.overSprites]: `lerp(white, color, intensity)` is
  ///   the multiply color. `0` leaves sprites unchanged, `1` fully
  ///   applies [color] as a multiply mask (so `color = black,
  ///   intensity = 1` produces pitch black under everything unlit).
  final double intensity;

  /// Where the ambient rect is drawn relative to sprites.
  final AmbientBlend blend;

  /// Creates an ambient-light resource.
  const AmbientLight({
    this.color = const Color(0xFFFFFFFF),
    this.intensity = 0.5,
    this.blend = AmbientBlend.underSprites,
  });

  /// A neutral half-lit ambient — everything visible, just dim.
  static const white = AmbientLight();

  /// Near-dark ambient — sprites are barely visible except where lit.
  static const dark = AmbientLight(color: Color(0xFF000000), intensity: 0.2);
}
