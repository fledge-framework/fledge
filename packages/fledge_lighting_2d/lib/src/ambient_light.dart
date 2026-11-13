import 'dart:ui' show Color, Rect;

/// How [AmbientLight] is applied to the scene (by the lighting view pass
/// that `LightingPlugin` adds to every `FledgeRenderView`).
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
  ///
  /// The lights are *added* over the darkened scene, so they paint a
  /// glow rather than reveal what's under them; prefer [lightMap].
  overSprites,

  /// The usual 2D lighting model, and the one to reach for: the ambient
  /// colour and every light are added into a light map, and the sprites
  /// are multiplied by it. A pixel ends up as its sprite colour × (ambient
  /// + the lights reaching it), so a lamp at night shows the ground in its
  /// true colours around it, and nothing gets brighter than it's drawn.
  /// `Sprite.emissive` sprites draw after the light map, at full
  /// brightness. Lights' `glow` halos are added on top.
  ///
  /// [AmbientLight.intensity] works as in [overSprites]: the map's base is
  /// `lerp(white, color, intensity)`, so `0` is full daylight.
  lightMap,
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

  /// Optional **world-space** rectangle that limits where the ambient
  /// rect is drawn.
  ///
  /// - `null` (the default): the ambient rect covers the full
  ///   viewport, matching the behaviour before this field existed.
  /// - non-null: clip the ambient fill to this rect. Useful when the
  ///   camera can look past a map's edge and the game doesn't want
  ///   the ambient tint to hang off into empty screen space
  ///   (Batch 6 item 25 — Porios's `computerStore` map exposed the
  ///   50 px "interact highlight" fringe past the map bounds).
  ///
  /// The rect is in world coordinates; the widget applies the active
  /// camera transform to it before painting.
  final Rect? bounds;

  /// Creates an ambient-light resource.
  const AmbientLight({
    this.color = const Color(0xFFFFFFFF),
    this.intensity = 0.5,
    this.blend = AmbientBlend.underSprites,
    this.bounds,
  });

  /// A neutral half-lit ambient — everything visible, just dim.
  static const white = AmbientLight();

  /// Near-dark ambient — sprites are barely visible except where lit.
  static const dark = AmbientLight(color: Color(0xFF000000), intensity: 0.2);
}
