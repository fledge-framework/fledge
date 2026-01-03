import 'render_backend.dart';
import '../canvas/canvas_backend.dart';

/// Selects the best available render backend.
///
/// Tries backends in order of preference and returns the first available one.
class BackendSelector {
  /// Try backends in order of preference.
  ///
  /// If [preferGpu] is true (default), attempts to use flutter_gpu first.
  /// Falls back to Canvas API if flutter_gpu is not available.
  static Future<RenderBackend> selectBest({
    bool preferGpu = true,
  }) async {
    // TODO: Once flutter_gpu is more stable, add:
    // if (preferGpu && await GpuBackend.checkAvailability()) {
    //   final backend = GpuBackend();
    //   await backend.initialize();
    //   return backend;
    // }

    // Fallback to Canvas (always available)
    final backend = CanvasBackend();
    await backend.initialize();
    return backend;
  }

  /// Get a list of all available backends.
  static Future<List<String>> getAvailableBackends() async {
    final available = <String>['canvas'];

    // TODO: Check for flutter_gpu availability
    // if (await GpuBackend.checkAvailability()) {
    //   available.insert(0, 'flutter_gpu');
    // }

    return available;
  }
}
