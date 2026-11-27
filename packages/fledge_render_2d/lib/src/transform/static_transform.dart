/// Marks scenery that never moves, so per-frame work can skip it.
///
/// The contract: once spawned, the entity's `Transform2D` won't change, nor
/// will its place in the hierarchy. On a root with children it covers the
/// whole subtree. Everything else may still change: a `Sprite`'s texture,
/// colour, source rect and flips, and `Visibility`. A child spawned under a
/// frozen entity later is computed from it once and frozen too, and a
/// `Sprite` added to a frozen entity later is found by the extractors.
///
/// [TransformPropagateSystem] computes a static root (and its subtree) once,
/// then marks every entity in it [TransformFrozen] and never visits them
/// again; `SpriteExtractor` and `AtlasSpriteExtractor` keep frozen sprites in
/// a spatial grid and only look at the ones near the view. In debug builds propagation checks now
/// and then that frozen entities really haven't moved, and fails an assert
/// naming the one that did: give anything that moves (even a little, like a
/// shake) no [StaticTransform].
class StaticTransform {
  const StaticTransform();
}

/// Set by [TransformPropagateSystem] on a [StaticTransform] root and every
/// entity below it once their global transforms are computed: they are
/// skipped from then on. Don't insert it yourself; filter on it (an
/// extractor that only wants what can move uses `Without<TransformFrozen>`).
class TransformFrozen {
  const TransformFrozen();
}

/// How often frozen entities have been added: bumped by
/// [TransformPropagateSystem] whenever it freezes some, so caches of frozen
/// entities (the sprite extractor's grid) know to rebuild.
class StaticTransforms {
  int generation = 0;
}
