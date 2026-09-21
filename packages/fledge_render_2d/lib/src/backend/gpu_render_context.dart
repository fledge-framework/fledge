import '../sprite/sprite.dart' show TextureHandle;
import '../sprite/sprite_render_node.dart' show BackendSpriteData, SpriteDrawer;

/// `flutter_gpu`-backed sprite drawer. **Stub.**
///
/// Reserved for the Impeller-based fast path. Selected by
/// `RenderPlugin(backend: RenderBackend.gpu)`. Every draw call
/// currently throws [UnimplementedError] — the interface exists so a
/// future GPU implementation drops in without touching the render
/// graph or the batch pipeline.
///
/// The plan (as of Phase 3a): implement this with a fragment shader
/// (`FragmentProgram`) and instanced quad draws once
/// `Canvas.drawRawAtlas` becomes a bottleneck. Until then the Canvas
/// backend covers desktop-primary targets comfortably (5k–20k
/// sprites @ 60 FPS per the render audit).
class GpuSpriteDrawer implements SpriteDrawer {
  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    throw UnimplementedError('flutter_gpu backend not yet wired');
  }
}
