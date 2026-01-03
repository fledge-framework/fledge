import 'dart:typed_data';
import 'dart:ui' as ui;

import '../backend/render_backend.dart';

/// Canvas API backend implementation.
///
/// Provides stable, production-ready rendering using Flutter's Canvas API.
/// Works on all platforms without experimental features.
class CanvasBackend implements RenderBackend {
  bool _initialized = false;

  @override
  String get name => 'canvas';

  @override
  Future<bool> isAvailable() async => true; // Always available

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  void dispose() {
    _initialized = false;
  }

  @override
  Future<BackendTexture> createTexture(TextureDescriptor descriptor) async {
    // Create an empty image of the specified size
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, descriptor.width.toDouble(),
          descriptor.height.toDouble()),
      ui.Paint()..color = const ui.Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(descriptor.width, descriptor.height);

    return CanvasTexture(image);
  }

  @override
  Future<BackendTexture> createTextureFromData(
    TextureDescriptor descriptor,
    Uint8List data,
  ) async {
    // Decode the image data
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return CanvasTexture(frame.image);
  }

  @override
  BackendBuffer createBuffer(BufferDescriptor descriptor) {
    return CanvasBuffer(descriptor.size);
  }

  @override
  FrameContext beginFrame(ui.Size size) {
    _checkInitialized();
    return CanvasFrameContext(size);
  }

  @override
  void endFrame(FrameContext context) {
    // No-op for canvas - drawing happens immediately
  }

  @override
  BackendCapabilities get capabilities => BackendCapabilities.canvas;

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError('CanvasBackend not initialized');
    }
  }
}

/// Canvas-backed texture.
class CanvasTexture implements BackendTexture {
  final ui.Image _image;
  bool _disposed = false;

  /// Creates a canvas texture from a ui.Image.
  CanvasTexture(this._image);

  /// The underlying ui.Image.
  ui.Image get image {
    _checkDisposed();
    return _image;
  }

  @override
  int get width => _image.width;

  @override
  int get height => _image.height;

  @override
  void dispose() {
    if (!_disposed) {
      _image.dispose();
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('CanvasTexture has been disposed');
    }
  }
}

/// Canvas-backed buffer (CPU-side storage).
class CanvasBuffer implements BackendBuffer {
  ByteData _data;
  bool _disposed = false;

  /// Creates a canvas buffer.
  CanvasBuffer(int size) : _data = ByteData(size);

  /// The underlying data.
  ByteData get data {
    _checkDisposed();
    return _data;
  }

  @override
  int get size => _data.lengthInBytes;

  @override
  void update(ByteData data) {
    _checkDisposed();
    if (data.lengthInBytes != _data.lengthInBytes) {
      _data = ByteData(data.lengthInBytes);
    }
    // Copy data
    for (var i = 0; i < data.lengthInBytes; i++) {
      _data.setUint8(i, data.getUint8(i));
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('CanvasBuffer has been disposed');
    }
  }
}

/// Canvas frame rendering context.
class CanvasFrameContext implements FrameContext {
  final ui.Size size;
  final List<_CanvasDrawCommand> _commands = [];
  BlendMode _blendMode = BlendMode.alpha;

  /// Creates a canvas frame context.
  CanvasFrameContext(this.size);

  /// The number of recorded draw commands.
  int get commandCount => _commands.length;

  /// The current blend mode.
  BlendMode get blendMode => _blendMode;

  @override
  void drawSpriteBatch(SpriteBatchData batch) {
    final texture = batch.texture;
    if (texture is! CanvasTexture) {
      throw ArgumentError('Expected CanvasTexture, got ${texture.runtimeType}');
    }

    for (final sprite in batch.sprites) {
      _commands.add(_DrawImageCommand(
        image: texture.image,
        src: sprite.sourceRect,
        dst: sprite.destRect,
        color: sprite.color,
        rotation: sprite.rotation,
        blendMode: _blendMode,
      ));
    }
  }

  @override
  void setBlendMode(BlendMode mode) {
    _blendMode = mode;
  }

  @override
  void clear(ui.Color color) {
    _commands.add(_ClearCommand(color));
  }

  /// Render all commands to a canvas.
  void render(ui.Canvas canvas) {
    for (final cmd in _commands) {
      cmd.execute(canvas);
    }
  }
}

/// Base class for canvas draw commands.
abstract class _CanvasDrawCommand {
  void execute(ui.Canvas canvas);
}

/// Command to draw an image.
class _DrawImageCommand extends _CanvasDrawCommand {
  final ui.Image image;
  final ui.Rect src;
  final ui.Rect dst;
  final ui.Color color;
  final double rotation;
  final BlendMode blendMode;

  _DrawImageCommand({
    required this.image,
    required this.src,
    required this.dst,
    required this.color,
    required this.rotation,
    required this.blendMode,
  });

  @override
  void execute(ui.Canvas canvas) {
    final paint = ui.Paint()
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.modulate);

    // Apply blend mode
    switch (blendMode) {
      case BlendMode.none:
        paint.blendMode = ui.BlendMode.src;
      case BlendMode.alpha:
        paint.blendMode = ui.BlendMode.srcOver;
      case BlendMode.additive:
        paint.blendMode = ui.BlendMode.plus;
      case BlendMode.multiply:
        paint.blendMode = ui.BlendMode.multiply;
    }

    if (rotation != 0) {
      canvas.save();
      final center = dst.center;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawImageRect(image, src, dst, paint);

    if (rotation != 0) {
      canvas.restore();
    }
  }
}

/// Command to clear the canvas.
class _ClearCommand extends _CanvasDrawCommand {
  final ui.Color color;

  _ClearCommand(this.color);

  @override
  void execute(ui.Canvas canvas) {
    canvas.drawPaint(ui.Paint()..color = color);
  }
}
