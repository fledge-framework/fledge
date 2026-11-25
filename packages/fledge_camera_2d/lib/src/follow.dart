import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        ActiveCameraView,
        GlobalTransform2D,
        PreviousTransform2D,
        Transform2D,
        TransformPropagateSystem;

import 'camera2d.dart';
import 'pixel_perfect.dart';
import 'parallax.dart';
import 'shake.dart';
import 'transitions.dart';
import 'viewport_size.dart';

/// Marker component that identifies the current camera-follow target.
///
/// Attach to any entity (typically the player) instead of hard-wiring
/// a specific `Entity` handle into [CameraFollow]. The follow system
/// picks the first entity carrying this marker each frame, so games
/// can spawn the camera before the player exists, hand off between
/// possessable characters, or point at the boss during a cutscene
/// just by moving the marker around.
///
/// Used only when [CameraFollow.target] is [Entity.placeholder]; if a
/// concrete target is set on the follow component that always wins,
/// so upgrading a game to use the marker is opt-in per-camera.
class CameraFollowTarget {
  const CameraFollowTarget();
}

/// Component making a [Camera2D] entity smoothly follow another entity.
///
/// Attach alongside `Camera2D` on the same entity. Each frame,
/// [CameraFollowSystem] moves the camera's `Transform2D.translation`
/// toward the target's `GlobalTransform2D` position plus [offset], in one
/// of two ways:
///
/// - **Damped** (the default): the camera covers the fraction [smoothing]
///   of the remaining distance per 1/60 s. `smoothing = 1.0` teleports
///   (instant); `0.15` gives a smooth, damped follow (roughly 100 ms
///   catch-up). Values outside `[0, 1]` are clamped.
/// - **Spring**: with [smoothTime] set, a critically damped spring that
///   eases in and out without overshooting, reaching the target in about
///   [smoothTime] seconds.
///
/// Both use `WallTime.delta`, so the follow feels the same at any refresh
/// rate and stays steady through uneven frames. Without a `WallTime`
/// resource the damped follow steps [smoothing] once per run.
///
/// The follow keeps its own unrounded position: with
/// `Camera2D.pixelPerfect`, only the camera's transform is snapped, so a
/// catch-up eases all the way in instead of stalling a pixel short.
///
/// ## Target resolution
///
/// - When [target] is a concrete entity handle (the default), the
///   follow tracks that entity directly.
/// - When [target] is [Entity.placeholder], the system falls back to
///   the first entity carrying a [CameraFollowTarget] marker. This is
///   the ergonomic form for games where the camera is built before
///   the player exists, or where the "possessed" entity changes.
class CameraFollow {
  /// Entity to follow. If the entity is despawned, the system logs a
  /// warning once and stops updating this camera. Set to
  /// [Entity.placeholder] to opt into marker-based targeting (see
  /// [CameraFollowTarget]).
  Entity target;

  /// Damping factor in `[0, 1]`: the fraction of the remaining distance
  /// covered per 1/60 s. 1 = instant snap, 0.1 = smooth catch-up. Higher
  /// values feel snappier; lower values feel more cinematic. Ignored while
  /// [smoothTime] is set.
  double smoothing;

  /// When set, a critically damped spring replaces [smoothing]: the
  /// camera eases in and out and settles on the target in about this many
  /// seconds, without overshooting.
  double? smoothTime;

  /// Optional world-space offset added to the target's position.
  ///
  /// Useful for offsetting the camera above/below the player, or
  /// looking ahead based on facing direction.
  Offset offset;

  /// Optional world-space area the camera's view must stay inside.
  ///
  /// The follow stops at the edges so nothing outside [bounds] shows. The
  /// view's size is what the widget render path shows: the size of the
  /// widget the camera last painted into (`ActiveCameraView.viewportSize`)
  /// divided by `Camera2D.widgetZoom` (so one world unit per logical pixel
  /// unless `Camera2D.scaleWidgetView` is on). Until the first paint, or
  /// when nothing paints through `FledgeRenderView`, the [ViewportSize]
  /// resource stands in for the widget's size; nothing updates it
  /// automatically, so keep it in step with your view in that case. On an
  /// axis where [bounds] is smaller than the view, the camera centres on
  /// [bounds] instead.
  Rect? bounds;

  /// Internal: `true` once we've logged the "target despawned"
  /// warning so we don't spam the console.
  bool warnedMissingTarget = false;

  /// Internal: the follow's own, unrounded camera position (the
  /// transform may be snapped to pixels), null until the first update.
  Offset? position;

  /// Internal: the spring's velocity, in world units per second.
  Offset velocity = Offset.zero;

  /// Internal: what the follow last wrote to the transform. If the
  /// transform has moved since (a transition, a teleport), the follow
  /// picks up from there.
  Offset? _written;

  /// Creates a camera-follow component with an explicit target.
  CameraFollow({
    required this.target,
    this.smoothing = 0.15,
    this.smoothTime,
    this.offset = Offset.zero,
    this.bounds,
  });

  /// Creates a camera-follow component that tracks whichever entity
  /// currently carries [CameraFollowTarget].
  CameraFollow.marker({
    this.smoothing = 0.15,
    this.smoothTime,
    this.offset = Offset.zero,
    this.bounds,
  }) : target = Entity.placeholder;
}

/// One axis of a critically damped spring (the usual "smooth damp"):
/// [current] moves toward [target] with [velocity], settling in about
/// [smoothTime] seconds without overshooting. Returns the new value and
/// velocity.
(double, double) _smoothDamp(
  double current,
  double target,
  double velocity,
  double smoothTime,
  double dt,
) {
  final omega = 2 / math.max(smoothTime, 1e-4);
  final x = omega * dt;
  final decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
  final change = current - target;
  final temp = (velocity + omega * change) * dt;
  var next = target + (change + temp) * decay;
  var nextVelocity = (velocity - omega * temp) * decay;
  // Never past the target.
  if ((target - current > 0) == (next > target)) {
    next = target;
    nextVelocity = 0;
  }
  return (next, nextVelocity);
}

/// System that updates every camera with a [CameraFollow] component.
///
/// Runs in `Schedules.postUpdate`. Declares `after:
/// [TransformPropagateSystem.systemName]` so it reads a fresh
/// `GlobalTransform2D` on the follow target.
///
/// **Root-camera fast path.** When the camera entity has no [Parent]
/// (the common case — a top-level camera), the system also writes
/// the camera's own `GlobalTransform2D` at the end of the follow
/// update. That means downstream world-space consumers running in
/// the same tick — a second sprite pass, a debug overlay drawn in
/// world space, a widget that clips around the camera — see the
/// fresh camera position without a second `TransformPropagateSystem`
/// pass. Hierarchical cameras still need propagation to run after
/// this system.
///
/// Also declares `before: [CameraShakeSystem.systemName]`. Shake is a
/// render-time offset kept on the `CameraShake` component, so the follow
/// never sees it as an external move of the camera.
///
/// When `Camera2D.pixelPerfect` is set on the followed camera, the
/// system snaps the resulting `Transform2D.translation` to whole
/// pixels so pixel-art tiles don't develop seams from sub-pixel
/// camera positions.
class CameraFollowSystem implements System {
  /// The `SystemMeta.name` of [CameraFollowSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'CameraFollowSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {
      ComponentId.of<Transform2D>(),
      ComponentId.of<GlobalTransform2D>(),
    },
    reads: {
      ComponentId.of<CameraFollow>(),
      ComponentId.of<Camera2D>(),
      ComponentId.of<CameraFollowTarget>(),
      ComponentId.of<Parent>(),
    },
    resourceReads: {ViewportSize, ActiveCameraView, WallTime},
    after: const [TransformPropagateSystem.systemName],
    before: const [
      CameraShakeSystem.systemName,
      ParallaxSystem.systemName,
      CameraTransitionSystem.systemName,
    ],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final ft = world.getResource<FixedTimestep>();
    final alpha = ft?.alpha ?? 1.0;
    final time = world.getResource<WallTime>();
    final dt = time?.delta ?? 0.0;

    // Cached marker lookup — resolve once per frame instead of once
    // per CameraFollow entity. `null` means "not looked up yet"; a
    // sentinel `Entity.placeholder` means "looked up, none found."
    Entity? markerTarget;
    Entity resolveMarker() {
      if (markerTarget != null) return markerTarget!;
      for (final (entity, _) in world.query1<CameraFollowTarget>().iter()) {
        markerTarget = entity;
        return entity;
      }
      markerTarget = Entity.placeholder;
      return markerTarget!;
    }

    for (final (cameraEntity, follow, camera, transform)
        in world.query3<CameraFollow, Camera2D, Transform2D>().iter()) {
      // Resolve the follow target. Explicit target wins; otherwise
      // fall back to the CameraFollowTarget marker.
      final markerMode = follow.target == Entity.placeholder;
      Entity target = follow.target;
      if (markerMode) {
        target = resolveMarker();
      }
      if (target == Entity.placeholder) {
        // Explicit-target mode with no target: user error, warn once.
        // Marker mode with no marker yet: the normal camera-before-
        // player start-up. Skip silently — the moment the marker
        // appears the camera picks it up.
        if (!markerMode && !follow.warnedMissingTarget) {
          // ignore: avoid_print
          print(
            '[fledge_camera_2d] CameraFollow has no target: neither '
            'CameraFollow.target nor a CameraFollowTarget marker was set. '
            'Camera will not update.',
          );
          follow.warnedMissingTarget = true;
        }
        continue;
      }

      final targetTransform = world.get<GlobalTransform2D>(target);
      if (targetTransform == null) {
        if (!follow.warnedMissingTarget) {
          // ignore: avoid_print
          print(
            '[fledge_camera_2d] CameraFollow.target ($target) has '
            'no GlobalTransform2D; skipping this camera.',
          );
          follow.warnedMissingTarget = true;
        }
        continue;
      }
      // Reset the warning if the target reappears.
      follow.warnedMissingTarget = false;

      // If the target opted into render interpolation, follow the
      // interpolated position instead of the raw current one. Keeps
      // the camera-follow feel smooth on displays running faster than
      // the physics fixed step.
      double tx = targetTransform.x + follow.offset.dx;
      double ty = targetTransform.y + follow.offset.dy;
      if (alpha < 1.0) {
        final prev = world.get<PreviousTransform2D>(target);
        final cur = world.get<Transform2D>(target);
        if (prev != null && cur != null) {
          final ix =
              prev.translation.x +
              (cur.translation.x - prev.translation.x) * alpha;
          final iy =
              prev.translation.y +
              (cur.translation.y - prev.translation.y) * alpha;
          tx = ix + follow.offset.dx;
          ty = iy + follow.offset.dy;
        }
      }

      // Work on the follow's own unrounded position. If something else
      // moved the transform since our last write (a transition, a
      // teleport), pick up from where it is now.
      final current = Offset(transform.translation.x, transform.translation.y);
      var position = follow.position;
      if (position == null || follow._written != current) {
        position = current;
        follow.velocity = Offset.zero;
      }

      final smoothTime = follow.smoothTime;
      if (smoothTime != null) {
        if (dt > 0) {
          final (x, vx) = _smoothDamp(
            position.dx,
            tx,
            follow.velocity.dx,
            smoothTime,
            dt,
          );
          final (y, vy) = _smoothDamp(
            position.dy,
            ty,
            follow.velocity.dy,
            smoothTime,
            dt,
          );
          position = Offset(x, y);
          follow.velocity = Offset(vx, vy);
        }
      } else {
        final smoothing = follow.smoothing.clamp(0.0, 1.0);
        // The same fraction per 1/60 s whatever the frame rate; one step
        // per run without a clock.
        final factor = smoothing >= 1.0
            ? 1.0
            : dt > 0
            ? 1 - math.pow(1 - smoothing, dt * 60).toDouble()
            : time == null
            ? smoothing
            : 0.0;
        position = Offset(
          position.dx + (tx - position.dx) * factor,
          position.dy + (ty - position.dy) * factor,
        );
      }

      // The view is clamped at the size the widget render path shows it:
      // the size of the widget it last painted into (recorded on
      // ActiveCameraView), at the camera's widget zoom (1:1 unless
      // scaleWidgetView). Before the first paint, or without a widget,
      // the ViewportSize resource stands in for the widget's size.
      final shown = world.getResource<ActiveCameraView>();
      final drawn = shown?.viewportSize;
      final viewport = world.getResource<ViewportSize>() ?? ViewportSize();
      final shownSize = drawn ?? viewport.size;
      // At the display scaling it was drawn at, as the view itself is: a
      // pixel-perfect zoom under 125 % or 150 % scaling differs from the
      // 1x one, and the bounds would clamp to the wrong visible size.
      final widgetZoom = camera.widgetZoom(
        shownSize,
        devicePixelRatio: drawn != null ? shown!.devicePixelRatio : 1,
      );

      final bounds = follow.bounds;
      if (bounds != null) {
        final x = _clampAxis(
          position.dx,
          bounds.left,
          bounds.right,
          shownSize.width / widgetZoom / 2,
        );
        final y = _clampAxis(
          position.dy,
          bounds.top,
          bounds.bottom,
          shownSize.height / widgetZoom / 2,
        );
        // Held at an edge, the spring doesn't keep winding up.
        follow.velocity = Offset(
          x == position.dx ? follow.velocity.dx : 0,
          y == position.dy ? follow.velocity.dy : 0,
        );
        position = Offset(x, y);
      }
      follow.position = position;
      transform.translation.x = position.dx;
      transform.translation.y = position.dy;

      // Pixel-perfect camera: snap the follow output to whole pixels
      // so pixel-art tiles don't develop seams from sub-pixel camera
      // positions. Only applies when the camera opted in; games that
      // want a smooth non-integer camera keep pixelPerfect=false.
      //
      // With a scaled widget view the snap is to whole *screen* pixels
      // (1 / zoom world units). Art on whole world units still lands on
      // whole screen pixels, and the camera moves in finer steps, so a
      // follow at a speed that isn't a whole number of world units per
      // frame doesn't judder between 1- and 2-unit jumps.
      // A sub-pixel scrolling camera is snapped by the render instead.
      if (camera.pixelPerfect && !camera.subpixelScroll) {
        transform.translation.x =
            snapToPixel(transform.translation.x * widgetZoom) / widgetZoom;
        transform.translation.y =
            snapToPixel(transform.translation.y * widgetZoom) / widgetZoom;
      }
      follow._written = Offset(
        transform.translation.x,
        transform.translation.y,
      );

      // Root-camera fast path: if the camera has no Parent, its
      // GlobalTransform2D IS its local Transform2D. Write it in place
      // so downstream world-space consumers in the same tick see the
      // fresh camera position without a second TransformPropagateSystem
      // pass. Hierarchical cameras skip this: propagation must still
      // run after this system to compose the parent chain.
      if (!world.has<Parent>(cameraEntity)) {
        final cameraGlobal = world.get<GlobalTransform2D>(cameraEntity);
        if (cameraGlobal != null) {
          cameraGlobal.matrix.setFrom(transform.toMatrix());
        } else {
          world.insert(cameraEntity, GlobalTransform2D(transform.toMatrix()));
        }
      }
    }
  }

  /// Keeps a view of half-size [half] centred at [value] inside
  /// [low]..[high], or centres it when the range is narrower than the view.
  static double _clampAxis(double value, double low, double high, double half) {
    if (high - low <= half * 2) return (low + high) / 2;
    return value.clamp(low + half, high - half);
  }
}
