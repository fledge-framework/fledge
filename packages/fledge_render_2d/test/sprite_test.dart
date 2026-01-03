import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Color', () {
    test('creates from value', () {
      const color = Color(0xFF112233);
      expect(color.value, 0xFF112233);
      expect(color.alpha, 0xFF);
      expect(color.red, 0x11);
      expect(color.green, 0x22);
      expect(color.blue, 0x33);
    });

    test('creates from ARGB', () {
      const color = Color.fromARGB(255, 128, 64, 32);
      expect(color.alpha, 255);
      expect(color.red, 128);
      expect(color.green, 64);
      expect(color.blue, 32);
    });

    test('calculates opacity', () {
      const opaque = Color(0xFFFFFFFF);
      expect(opaque.opacity, 1.0);

      const transparent = Color(0x00000000);
      expect(transparent.opacity, 0.0);

      const half = Color(0x80000000);
      expect(half.opacity, closeTo(0.5, 0.01));
    });

    test('equality', () {
      const a = Color(0xFF112233);
      const b = Color(0xFF112233);
      const c = Color(0xFF112234);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('Rect', () {
    test('creates from LTRB', () {
      const rect = Rect.fromLTRB(10, 20, 110, 70);
      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.right, 110);
      expect(rect.bottom, 70);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });

    test('creates from LTWH', () {
      const rect = Rect.fromLTWH(10, 20, 100, 50);
      expect(rect.left, 10);
      expect(rect.top, 20);
      expect(rect.width, 100);
      expect(rect.height, 50);
    });

    test('creates from center', () {
      final rect = Rect.fromCenter(
        center: const Offset(50, 50),
        width: 20,
        height: 10,
      );
      expect(rect.left, 40);
      expect(rect.top, 45);
      expect(rect.right, 60);
      expect(rect.bottom, 55);
    });

    test('provides corner offsets', () {
      const rect = Rect.fromLTRB(10, 20, 110, 70);
      expect(rect.topLeft, equals(const Offset(10, 20)));
      expect(rect.topRight, equals(const Offset(110, 20)));
      expect(rect.bottomLeft, equals(const Offset(10, 70)));
      expect(rect.bottomRight, equals(const Offset(110, 70)));
    });

    test('calculates center', () {
      const rect = Rect.fromLTRB(0, 0, 100, 50);
      expect(rect.center, equals(const Offset(50, 25)));
    });

    test('checks empty', () {
      expect(const Rect.fromLTRB(0, 0, 0, 0).isEmpty, isTrue);
      expect(const Rect.fromLTRB(0, 0, 10, 10).isEmpty, isFalse);
    });

    test('translates', () {
      const rect = Rect.fromLTRB(10, 20, 30, 40);
      final translated = rect.translate(5, 10);
      expect(translated.left, 15);
      expect(translated.top, 30);
      expect(translated.right, 35);
      expect(translated.bottom, 50);
    });

    test('contains point', () {
      const rect = Rect.fromLTRB(0, 0, 100, 100);
      expect(rect.contains(const Offset(50, 50)), isTrue);
      expect(rect.contains(const Offset(0, 0)), isTrue);
      expect(rect.contains(const Offset(100, 100)), isFalse); // Right edge exclusive
      expect(rect.contains(const Offset(-1, 50)), isFalse);
    });
  });

  group('Offset', () {
    test('creates with components', () {
      const offset = Offset(10, 20);
      expect(offset.dx, 10);
      expect(offset.dy, 20);
    });

    test('addition', () {
      const a = Offset(10, 20);
      const b = Offset(5, 10);
      expect(a + b, equals(const Offset(15, 30)));
    });

    test('subtraction', () {
      const a = Offset(10, 20);
      const b = Offset(5, 10);
      expect(a - b, equals(const Offset(5, 10)));
    });

    test('scaling', () {
      const offset = Offset(10, 20);
      expect(offset * 2, equals(const Offset(20, 40)));
      expect(offset / 2, equals(const Offset(5, 10)));
    });

    test('negation', () {
      const offset = Offset(10, -20);
      expect(-offset, equals(const Offset(-10, 20)));
    });
  });

  group('TextureHandle', () {
    test('creates with dimensions', () {
      const handle = TextureHandle(id: 1, width: 256, height: 128);
      expect(handle.id, 1);
      expect(handle.width, 256);
      expect(handle.height, 128);
    });

    test('provides full rect', () {
      const handle = TextureHandle(id: 1, width: 256, height: 128);
      final rect = handle.fullRect;
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, 256);
      expect(rect.height, 128);
    });

    test('equality based on id', () {
      const a = TextureHandle(id: 1, width: 256, height: 128);
      const b = TextureHandle(id: 1, width: 512, height: 512);
      const c = TextureHandle(id: 2, width: 256, height: 128);

      expect(a, equals(b)); // Same ID
      expect(a, isNot(equals(c))); // Different ID
    });
  });

  group('Sprite', () {
    test('creates with defaults', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final sprite = Sprite(texture: texture);

      expect(sprite.texture, texture);
      expect(sprite.sourceRect, isNull);
      expect(sprite.color.value, 0xFFFFFFFF);
      expect(sprite.flipX, isFalse);
      expect(sprite.flipY, isFalse);
      expect(sprite.anchor.x, 0.5);
      expect(sprite.anchor.y, 0.5);
    });

    test('effective source rect defaults to full texture', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final sprite = Sprite(texture: texture);

      expect(sprite.effectiveSourceRect.left, 0);
      expect(sprite.effectiveSourceRect.top, 0);
      expect(sprite.effectiveSourceRect.width, 64);
      expect(sprite.effectiveSourceRect.height, 64);
    });

    test('effective source rect uses custom rect', () {
      const texture = TextureHandle(id: 1, width: 256, height: 256);
      final sprite = Sprite(
        texture: texture,
        sourceRect: const Rect.fromLTWH(64, 64, 32, 32),
      );

      expect(sprite.effectiveSourceRect.left, 64);
      expect(sprite.effectiveSourceRect.top, 64);
      expect(sprite.effectiveSourceRect.width, 32);
      expect(sprite.effectiveSourceRect.height, 32);
    });

    test('size defaults to source rect dimensions', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final sprite = Sprite(texture: texture);

      expect(sprite.size.x, 64);
      expect(sprite.size.y, 64);
    });

    test('size uses custom size when set', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final sprite = Sprite(
        texture: texture,
        customSize: Vector2(128, 128),
      );

      expect(sprite.size.x, 128);
      expect(sprite.size.y, 128);
    });

    test('creates region sprite', () {
      const texture = TextureHandle(id: 1, width: 256, height: 256);
      final sprite = Sprite.region(
        texture: texture,
        region: const Rect.fromLTWH(0, 0, 32, 32),
      );

      expect(sprite.sourceRect, isNotNull);
      expect(sprite.sourceRect!.width, 32);
      expect(sprite.sourceRect!.height, 32);
    });
  });

  group('Visibility', () {
    test('defaults to visible', () {
      final visibility = Visibility();
      expect(visibility.isVisible, isTrue);
    });

    test('can be created invisible', () {
      final visibility = Visibility(false);
      expect(visibility.isVisible, isFalse);
    });

    test('hide and show', () {
      final visibility = Visibility();
      visibility.hide();
      expect(visibility.isVisible, isFalse);

      visibility.show();
      expect(visibility.isVisible, isTrue);
    });

    test('toggle', () {
      final visibility = Visibility();
      visibility.toggle();
      expect(visibility.isVisible, isFalse);

      visibility.toggle();
      expect(visibility.isVisible, isTrue);
    });
  });

  group('ExtractedSprite', () {
    test('computes flip flags', () {
      expect(ExtractedSprite.computeFlipFlags(false, false), 0);
      expect(ExtractedSprite.computeFlipFlags(true, false), 1);
      expect(ExtractedSprite.computeFlipFlags(false, true), 2);
      expect(ExtractedSprite.computeFlipFlags(true, true), 3);
    });

    test('reads flip flags', () {
      final world = World();
      const texture = TextureHandle(id: 1, width: 64, height: 64);

      final entity = world.spawn().entity;

      final extracted = ExtractedSprite(
        entity: entity,
        texture: texture,
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: 3, // Both flags set
        anchor: Vector2(0.5, 0.5),
        size: Vector2(64, 64),
      );

      expect(extracted.flipX, isTrue);
      expect(extracted.flipY, isTrue);
    });
  });

  group('SpriteBundle', () {
    test('creates with defaults', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final bundle = SpriteBundle(texture: texture);

      expect(bundle.sprite.texture, texture);
      expect(bundle.transform.translation.x, 0);
      expect(bundle.transform.translation.y, 0);
      expect(bundle.visibility, isNull);
    });

    test('creates with position', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final bundle = SpriteBundle(
        texture: texture,
        x: 100,
        y: 200,
      );

      expect(bundle.transform.translation.x, 100);
      expect(bundle.transform.translation.y, 200);
    });

    test('creates with visibility', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final bundle = SpriteBundle(
        texture: texture,
        visible: false,
      );

      expect(bundle.visibility, isNotNull);
      expect(bundle.visibility!.isVisible, isFalse);
    });

    test('spawns entity with components', () {
      final world = World();
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final bundle = SpriteBundle(texture: texture, x: 50, y: 100);

      final entity = bundle.spawn(world).entity;

      expect(world.get<Sprite>(entity), isNotNull);
      expect(world.get<Transform2D>(entity), isNotNull);
      expect(world.get<GlobalTransform2D>(entity), isNotNull);
    });
  });

  group('SpriteBatch', () {
    test('creates empty batch', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final batch = SpriteBatch(texture);

      expect(batch.texture, texture);
      expect(batch.isEmpty, isTrue);
      expect(batch.length, 0);
    });

    test('adds instances', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final batch = SpriteBatch(texture);

      batch.add(SpriteInstance(
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTWH(0, 0, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
      ));

      expect(batch.length, 1);
      expect(batch.isNotEmpty, isTrue);
    });

    test('clears instances', () {
      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final batch = SpriteBatch(texture);

      batch.add(SpriteInstance(
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTWH(0, 0, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
      ));

      batch.clear();
      expect(batch.isEmpty, isTrue);
    });
  });

  group('SpriteBatches', () {
    test('calculates total sprites', () {
      const texture1 = TextureHandle(id: 1, width: 64, height: 64);
      const texture2 = TextureHandle(id: 2, width: 64, height: 64);

      final batch1 = SpriteBatch(texture1);
      batch1.add(SpriteInstance(
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTWH(0, 0, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
      ));
      batch1.add(SpriteInstance(
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTWH(64, 0, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
      ));

      final batch2 = SpriteBatch(texture2);
      batch2.add(SpriteInstance(
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTWH(0, 64, 64, 64),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFFFFF),
      ));

      final batches = SpriteBatches([batch1, batch2]);

      expect(batches.batchCount, 2);
      expect(batches.totalSprites, 3);
    });
  });

  group('SpriteBatchSystem', () {
    test('batches extracted sprites by texture', () async {
      final world = World();
      final renderWorld = RenderWorld();

      // Create extracted sprites in render world
      const texture1 = TextureHandle(id: 1, width: 64, height: 64);
      const texture2 = TextureHandle(id: 2, width: 64, height: 64);

      final entity1 = world.spawn().entity;
      final entity2 = world.spawn().entity;
      final entity3 = world.spawn().entity;

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity1,
            texture: texture1,
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFFFFFFFF),
            sortKey: 100,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity2,
            texture: texture2,
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFFFFFFFF),
            sortKey: 200,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity3,
            texture: texture1, // Same texture as first sprite
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFFFFFFFF),
            sortKey: 300,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      // Run batch system
      final system = SpriteBatchSystem();
      await system.run(world, renderWorld);

      // Check batches were created
      final batches = renderWorld.getResource<SpriteBatches>();
      expect(batches, isNotNull);
      expect(batches!.batchCount, 2); // Two different textures
      expect(batches.totalSprites, 3);
    });

    test('sorts sprites by sort key', () async {
      final world = World();
      final renderWorld = RenderWorld();

      const texture = TextureHandle(id: 1, width: 64, height: 64);
      final entity1 = world.spawn().entity;
      final entity2 = world.spawn().entity;
      final entity3 = world.spawn().entity;

      // Add in reverse order of sort key
      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity3,
            texture: texture,
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFFFF0000), // Red
            sortKey: 300,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity1,
            texture: texture,
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFF00FF00), // Green
            sortKey: 100,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity2,
            texture: texture,
            sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
            transform: Matrix3.identity(),
            color: const Color(0xFF0000FF), // Blue
            sortKey: 200,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(64, 64),
          ));

      final system = SpriteBatchSystem();
      await system.run(world, renderWorld);

      final batches = renderWorld.getResource<SpriteBatches>();
      expect(batches, isNotNull);
      expect(batches!.all.length, 1);

      // Verify order by checking colors
      final instances = batches.all.first.instances;
      expect(instances[0].color.value, 0xFF00FF00); // Green (sort key 100)
      expect(instances[1].color.value, 0xFF0000FF); // Blue (sort key 200)
      expect(instances[2].color.value, 0xFFFF0000); // Red (sort key 300)
    });
  });

  group('SpriteExtractor', () {
    test('extracts sprites with visibility check', () {
      final world = World();
      final renderWorld = RenderWorld();

      const texture = TextureHandle(id: 1, width: 64, height: 64);

      // Visible sprite
      world.spawn()
        ..insert(Sprite(texture: texture))
        ..insert(GlobalTransform2D());

      // Invisible sprite
      world.spawn()
        ..insert(Sprite(texture: texture))
        ..insert(GlobalTransform2D())
        ..insert(Visibility(false));

      final extractor = SpriteExtractor();
      extractor.extract(world, renderWorld);

      // Count extracted sprites
      var count = 0;
      for (final _ in renderWorld.query1<ExtractedSprite>().iter()) {
        count++;
      }
      expect(count, 1); // Only visible sprite was extracted
    });

    test('computes sort key from Y position', () {
      final world = World();
      final renderWorld = RenderWorld();

      const texture = TextureHandle(id: 1, width: 64, height: 64);

      final globalTransform = GlobalTransform2D();
      globalTransform.translation = Vector2(100, 250);

      world.spawn()
        ..insert(Sprite(texture: texture))
        ..insert(globalTransform);

      final extractor = SpriteExtractor();
      extractor.extract(world, renderWorld);

      for (final (_, extracted) in renderWorld.query1<ExtractedSprite>().iter()) {
        // Sort key should be Y * 1000
        expect(extracted.sortKey, 250000);
      }
    });
  });
}
