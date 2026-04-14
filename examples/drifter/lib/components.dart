/// Marker components for Drifter entities.
///
/// Game logic identifies entities via zero-size marker components rather
/// than inspecting shape data — standard ECS practice. Queries like
/// `world.query1<Transform2D>(filter: With<Player>())` stay fast because
/// markers don't add per-entity data.
class Player {
  const Player();
}

class Wall {
  const Wall();
}

class Pickup {
  const Pickup();
}
