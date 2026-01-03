/// Stages of the render pipeline.
///
/// The render pipeline is divided into stages that run in sequence:
///
/// 1. [extract] - Copy data from main world to render world
/// 2. [prepare] - Prepare GPU resources (buffers, textures)
/// 3. [queue] - Queue draw calls and sort for rendering
/// 4. [render] - Execute the render graph
/// 5. [cleanup] - Clean up temporary resources
///
/// Each stage can have multiple systems that run within it.
enum RenderStage {
  /// Extract data from main world to render world.
  ///
  /// Systems in this stage query the main world and create
  /// corresponding entities in the render world.
  extract,

  /// Prepare GPU resources.
  ///
  /// Systems in this stage create and update GPU resources
  /// like vertex buffers and texture uploads.
  prepare,

  /// Queue draw calls and sort.
  ///
  /// Systems in this stage collect draw calls, sort them
  /// by material/depth, and batch where possible.
  queue,

  /// Execute the render graph.
  ///
  /// Systems in this stage run the render graph nodes
  /// to perform actual GPU rendering.
  render,

  /// Clean up temporary resources.
  ///
  /// Systems in this stage release temporary resources
  /// that are no longer needed.
  cleanup,
}
