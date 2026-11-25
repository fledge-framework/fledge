# Hierarchies

Entities can form parent-child trees: a ship and its turrets, a UI panel and
its buttons. Fledge stores the links as two components, `Parent` and
`Children`, and keeps them consistent through world and command methods.

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Name {
  final String value;
  Name(this.value);
}
-->

## Building a tree

```dart
final world = World();

final ship = world.spawnWith([Name('ship'), Position(0, 0)]);

// Link two existing entities.
final turret = world.spawnWith([Name('turret'), Position(0, 8)]);
world.setParent(turret, ship);

// Or spawn straight into the tree. Returns EntityCommands.
final engine = world.spawnChild(ship)
  ..insert(Name('engine'))
  ..insert(Position(0, -8));
final engineId = engine.entity;
```

`setParent(child, parent)` does nothing if either entity is dead. Calling it on
an entity that already has a parent moves it: it's removed from the old
parent's `Children` first.

## The components

| Component | On | Contents |
|---|---|---|
| `Parent` | each child | `entity`: the parent |
| `Children` | each parent | the child list |

`Children` exposes `children` (an `Iterable<Entity>`), `list` (an unmodifiable
copy), `length`, `isEmpty`/`isNotEmpty` and `contains`. It also has `add` and
`remove`, but they only edit the list. Use `setParent`/`removeParent` so
`Parent` stays in step.

Because they're ordinary components, you can query them:

```dart
final world = World();

// Root entities with children.
for (final (entity, children) in world.query1<Children>(
  filter: const Without<Parent>(),
).iter()) {
  print('$entity has ${children.length} children');
}
```

## Traversal

```dart
final world = World();
final root = world.spawnWith([Name('root')]);
final mid = world.spawnChild(root).entity;
final leaf = world.spawnChild(mid).entity;

world.getParent(leaf); // mid (null for a root)
world.getChildren(root); // direct children only
world.hasParent(leaf); // true
world.hasChildren(root); // true
world.root(leaf); // root (an entity with no parent is its own root)

for (final ancestor in world.ancestors(leaf)) {
  print(ancestor); // mid, then root
}
for (final d in world.descendants(root)) {
  print(d); // depth-first: mid, then leaf
}
```

## Detaching and despawning

```dart
final world = World();
final parent = world.spawnWith([Name('parent')]);
final child = world.spawnChild(parent).entity;

world.removeParent(child); // child becomes a root
world.setParent(child, parent); // and back again

world.despawnRecursive(parent); // parent, child and everything below
```

`despawnRecursive` also removes the entity from its own parent's `Children`,
then despawns from the leaves up. When a parent loses its last child, its
`Children` component is removed.

Plain `despawn` keeps the hierarchy consistent without removing anything
else:

- `despawn(child)` removes the child from its parent's `Children`.
- `despawn(parent)` leaves its children alive and turns them into roots
  (their `Parent` is removed).

Use `despawnRecursive` when the children should go too.

## In systems: commands

`Commands` has the same operations, deferred:

```dart
final world = World();
final ship = world.spawnWith([Name('ship')]);
final commands = Commands();

final shield = commands.spawnChild(ship)..insert(Name('shield'));
commands.apply(world);

print(shield.entity); // set only after apply
commands
  ..despawnRecursive(ship)
  ..apply(world);
```

`commands.spawnChild(parent)` takes just the parent; add components with
`..insert`. Its `entity` is null until `apply`, so don't read it with `!`
before then. If the parent is dead when the command applies, nothing is
spawned.

There's no `setParent` command; queue one with
`commands.custom((world) => world.setParent(child, parent))`.

## Transforms

`fledge_ecs` only stores the links. Propagating positions down a tree is the
job of `fledge_render_2d`'s transform systems, which read `Parent` and
`Children`; see [Transforms](/docs/rendering/transforms).

## See also

- [Commands](/docs/ecs/commands)
- [Entities & Components](/docs/ecs/entities-components)
- [Transforms](/docs/rendering/transforms)
