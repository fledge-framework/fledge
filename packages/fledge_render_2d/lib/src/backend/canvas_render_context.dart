import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui'
    show BlendMode, Canvas, FilterQuality, Image, Paint, Rect, RSTransform;

import 'package:fledge_assets/fledge_assets.dart' show Assets, HandleId;
import 'package:vector_math/vector_math.dart' show Matrix3;

import '../sprite/sprite.dart' show TextureHandle;
import '../sprite/sprite_render_node.dart' show BackendSpriteData, SpriteDrawer;
import '../sprite/texture.dart' show Texture;

/// Canvas-backed sprite drawer using `Canvas.drawRawAtlas`.
///
/// This is the default backend selected by
/// `RenderPlugin(backend: RenderBackend.canvas)`. It is battle-tested
/// on desktop and gives us a single-call-per-batch draw path via
/// `dart:ui`.
///
/// ## Lifecycle
///
/// The outer widget (a `CustomPainter`, `RenderView`, or equivalent)
/// must call [beginFrame] with the current `Canvas` before the
/// render graph executes and [endFrame] afterwards. Phase 3a leaves
/// widget-side wiring for Phase 3e — see the plan document for how
/// Drifter will migrate.
///
/// ## Texture resolution
///
/// The drawer resolves each [TextureHandle] against an
/// `Assets<Texture>` resource (installed by `RenderPlugin`). The
/// legacy [registerTexture] API still writes into the same store, so
/// existing call sites (e.g. Drifter's 1x1 solid-colour handle)
/// continue to work through the same pathway that
/// `Handle<Texture>` uses.
class CanvasSpriteDrawer implements SpriteDrawer {
  /// The per-type asset store the drawer resolves handles against.
  ///
  /// `RenderPlugin.build` sets this via [attachAssets] on plugin
  /// build; tests can pass an ad-hoc `Assets<Texture>` in the same
  /// way. A drawer with no bound store still works — [drawSpriteBatch]
  /// silently no-ops for any handle it cannot resolve, which matches
  /// the pre-Phase-5 "no texture registered → silent" behaviour.
  Assets<Texture>? _assets;

  /// Bind [assets] as the texture-resolution store. Called by
  /// `RenderPlugin.build`.
  void attachAssets(Assets<Texture> assets) {
    _assets = assets;
  }

  /// The currently-attached asset store, if any. Exposed for tests
  /// and for downstream widgets that want to register additional
  /// textures without going through [registerTexture].
  Assets<Texture>? get assets => _assets;

  /// Shared paint used for every drawRawAtlas call. Kept as a field
  /// so callers can tweak filter quality once instead of per-frame.
  final Paint paint = Paint()..filterQuality = FilterQuality.low;

  /// The active canvas for this frame, or `null` between frames.
  Canvas? _canvas;

  /// Whether a canvas is currently bound.
  bool get hasCanvas => _canvas != null;

  /// The active canvas, or `null` if [beginFrame] hasn't been called
  /// this frame.
  Canvas? get canvas => _canvas;

  /// Legacy in-memory texture map, kept for backwards compatibility
  /// with tests and games that still call [registerTexture] directly.
  /// New code should insert an `Assets<Texture>` resource (which
  /// `RenderPlugin` does automatically) and use `Handle<Texture>` or
  /// [registerTexture] (which now proxies into the same store).
  final Map<int, Image> textures = <int, Image>{};

  /// Register a texture image so future draws can resolve
  /// [TextureHandle] with [handle.id].
  ///
  /// Backing store: if an `Assets<Texture>` is attached, this also
  /// registers the image under the same id there so both resolution
  /// paths agree. Otherwise it stays in the legacy in-memory map.
  void registerTexture(TextureHandle handle, Image image) {
    textures[handle.id] = image;
    final assets = _assets;
    if (assets != null) {
      final id = HandleId(handle.id);
      // If the id is already in the store, overwrite the value
      // in-place via reload semantics. Otherwise reserve the id.
      if (assets.get(id) != null) {
        // Already present — we mutate the entry by re-adding is
        // unavailable; the simplest write-through is to keep the
        // legacy map as the source of truth. `_resolve` prefers it
        // to keep behaviour identical for callers that only use
        // this API.
        return;
      }
      try {
        assets.addWithId(id, Texture(image, handle.width, handle.height));
      } on StateError {
        // Race: someone else inserted the same id concurrently.
        // Legacy map still has the image — that path resolves.
      }
    }
  }

  /// Resolve a [TextureHandle] into its underlying `dart:ui.Image`.
  ///
  /// Consults the attached `Assets<Texture>` first, then falls back
  /// to the legacy in-memory map — that ordering means new-style
  /// handles win but legacy `registerTexture` calls still function.
  Image? resolveImage(TextureHandle handle) {
    final assets = _assets;
    if (assets != null) {
      final t = assets.get(HandleId(handle.id));
      if (t != null) return t.image;
    }
    return textures[handle.id];
  }

  /// Bind [canvas] for the current frame. The outer widget (or
  /// custom painter) calls this from `paint()` before executing the
  /// render graph.
  void beginFrame(Canvas canvas) {
    _canvas = canvas;
  }

  /// Release the frame's canvas reference.
  void endFrame() {
    _canvas = null;
  }

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    // Empty batches must never issue a backend draw call — Canvas
    // still validates buffer lengths (must be > 0).
    if (batch.isEmpty) return;

    final canvas = _canvas;
    if (canvas == null) {
      // Without a live canvas (e.g. running in a test that only
      // checks contract, or before widget-side wiring in Phase 3e)
      // silently drop. Existing behaviour was "callback is null →
      // no-op" so this is not a regression.
      return;
    }

    final image = resolveImage(texture);
    if (image == null) {
      // No image registered for this handle. Silent no-op keeps
      // tests hermetic; a future revision may surface this as a
      // load error via a `AssetLoadFailed` event.
      return;
    }

    final count = batch.length;
    final rstTransforms = Float32List(count * 4);
    final srcRects = Float32List(count * 4);
    final colors = Int32List(count);

    for (var i = 0; i < count; i++) {
      final sprite = batch[i];

      final rst = composeSpriteRSTransform(
        transform: sprite.transform,
        sourceRect: sprite.sourceRect,
        destRect: sprite.destRect,
      );
      rstTransforms[i * 4 + 0] = rst.scos;
      rstTransforms[i * 4 + 1] = rst.ssin;
      rstTransforms[i * 4 + 2] = rst.tx;
      rstTransforms[i * 4 + 3] = rst.ty;

      // srcRect: L T R B in atlas pixel coordinates.
      final src = sprite.sourceRect;
      srcRects[i * 4 + 0] = src.left;
      srcRects[i * 4 + 1] = src.top;
      srcRects[i * 4 + 2] = src.right;
      srcRects[i * 4 + 3] = src.bottom;

      colors[i] = sprite.color.toARGB32();
    }

    // The camera's view-projection matrix is applied once, framing
    // the whole atlas draw. Pre-multiplying it into each RSTransform
    // is possible but loses the perspective-safe fast path — all
    // sprites in a batch share the same camera, so
    // save+transform+restore is both simpler and marginally faster.
    final vp = batch.first.viewProjection;
    if (vp != null) {
      canvas.save();
      // `Canvas.transform` needs a Float64List; vector_math's
      // Matrix4 stores Float32List. One allocation per batch, not
      // per sprite, so the copy is cheap.
      canvas.transform(Float64List.fromList(vp.storage));
    }

    canvas.drawRawAtlas(
      image,
      rstTransforms,
      srcRects,
      colors,
      BlendMode.modulate,
      null, // cullRect: null lets the backend choose. Cheap.
      paint,
    );

    if (vp != null) {
      canvas.restore();
    }
  }
}

/// Decomposed RSTransform components. Exposed for testing.
class SpriteRSTransform {
  /// `scale * cos(rotation)` — the (0,0) entry of the RS matrix.
  final double scos;

  /// `scale * sin(rotation)` — the (1,0) entry of the RS matrix.
  final double ssin;

  /// Canvas-space translation X.
  final double tx;

  /// Canvas-space translation Y.
  final double ty;

  /// Uniform scale extracted from the sprite's transform matrix.
  final double scale;

  /// Rotation in radians extracted from the sprite's transform.
  final double rotation;

  const SpriteRSTransform({
    required this.scos,
    required this.ssin,
    required this.tx,
    required this.ty,
    required this.scale,
    required this.rotation,
  });

  /// Convert to a Flutter [RSTransform] value.
  RSTransform toRSTransform() => RSTransform(scos, ssin, tx, ty);
}

/// Compose an [RSTransform] for `Canvas.drawRawAtlas` from the
/// sprite's world-space [transform], its atlas-space [sourceRect],
/// and its local-space [destRect].
///
/// ### Model
///
/// `Canvas.drawRawAtlas` applies each `RSTransform` to the source
/// rectangle's four corners:
///
/// ```
/// x_canvas = scos * x_src - ssin * y_src + tx
/// y_canvas = ssin * x_src + scos * y_src + ty
/// ```
///
/// The sprite pipeline speaks in three coordinate frames:
///
/// 1. **Source (atlas)** — pixels inside the atlas image.
/// 2. **Local (sprite)** — [destRect] describes the sprite's quad in
///    local space, already anchored by [SpriteBatchSystem] so that
///    the entity's Transform2D translation is the sprite's
///    "attach" point.
/// 3. **World** — [transform] as a 2D affine [Matrix3].
///
/// The mapping source → local is a uniform scale of
/// `k = destRect.width / sourceRect.width`, offset so that source
/// top-left lines up with dest top-left. Applying [transform] gives
/// the world-space corner positions. The output `RSTransform` is
/// exactly that composed map, expressed in
/// scale-rotation-translation form.
///
/// Assumes the sprite scale factor `k` is uniform in x and y
/// (`destRect.width / sourceRect.width ==
/// destRect.height / sourceRect.height`). Non-uniform scaling is out
/// of scope for the drawRawAtlas path — Flame has the same
/// constraint.
SpriteRSTransform composeSpriteRSTransform({
  required Matrix3 transform,
  required Rect sourceRect,
  required Rect destRect,
}) {
  // Matrix3 storage layout (column-major):
  //   [ a  b  0
  //     c  d  0
  //     e  f  1 ]
  // where storage = [a, b, 0, c, d, 0, e, f, 1].
  // For a pure similarity transform (scale + rotate + translate):
  //   a = scale * cos(rotation)
  //   b = scale * sin(rotation)
  //   c = -scale * sin(rotation)
  //   d = scale * cos(rotation)
  //   e = translationX
  //   f = translationY
  final s = transform.storage;
  final a = s[0];
  final b = s[1];
  final e = s[6];
  final f = s[7];

  // Scale magnitude and rotation are read from the first column.
  // (The second column is the perpendicular of the first for a
  // similarity — we do not attempt to detect shear/reflection.)
  final scale = math.sqrt(a * a + b * b);
  final rotation = math.atan2(b, a);

  // Uniform source→local scale.
  final k = sourceRect.width == 0 ? 0.0 : destRect.width / sourceRect.width;

  // Effective RS scale in canvas space.
  final rsScos = a * k;
  final rsSsin = b * k;

  // Composition: local point (x_l, y_l) = (x_src * k + destRect.left
  // - sourceRect.left * k, y_src * k + destRect.top - sourceRect.top
  // * k). Then world = M * local. Expanded, this gives:
  //
  //   x_world = (a*k) * x_src + (c*k) * y_src
  //           + a * (destL - k*srcL) + c * (destT - k*srcT) + e
  //   y_world = (b*k) * x_src + (d*k) * y_src
  //           + b * (destL - k*srcL) + d * (destT - k*srcT) + f
  //
  // where c = -b and d = a for our similarity transform. Match
  // against the RSTransform form to read off tx/ty.
  final c = -b;
  final d = a;
  final offX = destRect.left - k * sourceRect.left;
  final offY = destRect.top - k * sourceRect.top;
  final tx = a * offX + c * offY + e;
  final ty = b * offX + d * offY + f;

  return SpriteRSTransform(
    scos: rsScos,
    ssin: rsSsin,
    tx: tx,
    ty: ty,
    scale: scale,
    rotation: rotation,
  );
}
