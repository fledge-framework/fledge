// ignore_for_file: avoid_print
import 'package:fledge_render_flutter/fledge_render_flutter.dart';

void main() async {
  // Select the best available backend
  // Tries flutter_gpu first, falls back to Canvas
  final backend = await BackendSelector.selectBest();

  print('Using backend: ${backend.runtimeType}');

  // Or force Canvas backend (stable, works everywhere)
  final canvasBackend = CanvasBackend();
  await canvasBackend.initialize();

  print('Canvas backend initialized');

  // In a real app, you would:
  // 1. Create textures from images
  // 2. Begin a frame
  // 3. Draw sprite batches
  // 4. End the frame
  //
  // Example:
  // final texture = await backend.createTextureFromData(
  //   TextureDescriptor(width: 256, height: 256),
  //   imageData,
  // );
  // final frame = backend.beginFrame(size);
  // frame.drawSpriteBatch(batch);
  // backend.endFrame(frame);
}
