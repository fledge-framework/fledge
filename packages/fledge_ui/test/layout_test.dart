import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LayoutSystem — anchor calculations', () {
    late World world;
    late LayoutSystem system;

    setUp(() {
      world = World();
      world.insertResource(ViewportSize(width: 800, height: 600));
      system = LayoutSystem();
    });

    Entity spawnNode({
      required UiAnchor anchor,
      UiSize? size,
      UiOffset? offset,
    }) {
      final commands = world.spawn()
        ..insert(const UiNode())
        ..insert(UiAnchorComponent(anchor));
      if (size != null) commands.insert(size);
      if (offset != null) commands.insert(offset);
      return commands.entity;
    }

    test('topLeft anchor: rect origin equals viewport origin plus offset',
        () async {
      final entity = spawnNode(
        anchor: UiAnchor.topLeft,
        size: const UiSize(width: 100, height: 50),
        offset: const UiOffset(x: 10, y: 20),
      );

      await system.run(world);

      final rect = world.get<UiComputedRect>(entity)!.rect;
      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });

    test('center anchor places rect centred inside the viewport', () async {
      final entity = spawnNode(
        anchor: UiAnchor.center,
        size: const UiSize(width: 200, height: 100),
      );

      await system.run(world);

      final rect = world.get<UiComputedRect>(entity)!.rect;
      // Viewport is 800×600; rect is 200×100 centred → (300, 250).
      expect(rect.left, 300);
      expect(rect.top, 250);
    });

    test('bottomRight anchor pins rect against the viewport far corner',
        () async {
      final entity = spawnNode(
        anchor: UiAnchor.bottomRight,
        size: const UiSize(width: 120, height: 60),
      );

      await system.run(world);

      final rect = world.get<UiComputedRect>(entity)!.rect;
      // 800 - 120 = 680; 600 - 60 = 540.
      expect(rect.left, 680);
      expect(rect.top, 540);
    });

    test('offset shifts the rect relative to the anchor', () async {
      final entity = spawnNode(
        anchor: UiAnchor.topRight,
        size: const UiSize(width: 50, height: 30),
        offset: const UiOffset(x: -8, y: 4),
      );

      await system.run(world);

      final rect = world.get<UiComputedRect>(entity)!.rect;
      // topRight base: 800-50 = 750, 0. Offset (-8, 4) → (742, 4).
      expect(rect.left, 742);
      expect(rect.top, 4);
    });
  });

  group('LayoutSystem — containers', () {
    late World world;
    late LayoutSystem system;

    setUp(() {
      world = World();
      world.insertResource(ViewportSize(width: 800, height: 600));
      system = LayoutSystem();
    });

    test('row container lays out children left-to-right respecting gap',
        () async {
      final container = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 300, height: 60))
            ..insert(const UiContainer(mode: LayoutMode.row, gap: 10)))
          .entity;

      final a = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 40, height: 20)))
          .entity;
      final b = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 60, height: 20)))
          .entity;
      world.setParent(a, container);
      world.setParent(b, container);

      await system.run(world);

      final rectA = world.get<UiComputedRect>(a)!.rect;
      final rectB = world.get<UiComputedRect>(b)!.rect;

      // First child starts at container's top-left interior.
      expect(rectA.left, 0);
      // Second child starts after first child's width + gap.
      expect(rectB.left, 40 + 10);
    });

    test('column container lays out children top-to-bottom', () async {
      final container = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 100, height: 400))
            ..insert(const UiContainer(mode: LayoutMode.column, gap: 5)))
          .entity;

      final a = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 40, height: 20)))
          .entity;
      final b = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 40, height: 30)))
          .entity;
      world.setParent(a, container);
      world.setParent(b, container);

      await system.run(world);

      expect(world.get<UiComputedRect>(a)!.rect.top, 0);
      expect(world.get<UiComputedRect>(b)!.rect.top, 20 + 5);
    });

    test('padding is subtracted from the interior of a stack container',
        () async {
      final container = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft))
            ..insert(const UiSize(width: 200, height: 100))
            ..insert(const UiContainer.padded(padding: 10)))
          .entity;

      final child = (world.spawn()
            ..insert(const UiNode())
            ..insert(const UiAnchorComponent(UiAnchor.topLeft)))
          // No size — should fill the container's padded interior.
          .entity;
      world.setParent(child, container);

      await system.run(world);

      final rect = world.get<UiComputedRect>(child)!.rect;
      // Container starts at (0,0), padded interior = (10,10) to (190,90).
      expect(rect.left, 10);
      expect(rect.top, 10);
      expect(rect.width, 180);
      expect(rect.height, 80);
    });
  });

  test('layout is idempotent — running twice produces the same rect', () async {
    final world = World();
    world.insertResource(ViewportSize(width: 400, height: 300));
    final entity = (world.spawn()
          ..insert(const UiNode())
          ..insert(const UiAnchorComponent(UiAnchor.center))
          ..insert(const UiSize(width: 80, height: 40)))
        .entity;

    final system = LayoutSystem();
    await system.run(world);
    final first = world.get<UiComputedRect>(entity)!.rect;
    await system.run(world);
    final second = world.get<UiComputedRect>(entity)!.rect;

    expect(first, second);
  });
}
