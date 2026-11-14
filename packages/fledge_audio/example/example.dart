// ignore_for_file: avoid_print
import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(AudioPlugin());

  // Register clips straight away: they load in the background once the
  // engine has started (nothing waits on them).
  app.world
    ..loadMusic('theme', 'assets/music/theme.ogg')
    ..loadSound('explosion', 'assets/sounds/explosion.wav');

  // Music waits for its clip, so it can be asked for before it has loaded.
  app.world.playMusic('theme', crossfade: const Duration(seconds: 2));

  // Sound effects play if their clip is ready (else AudioFailed says why).
  // app.world.playSfx('explosion', position: (120, 40));

  // Channel volumes apply to music that's already playing, too.
  // app.world.setVolume(AudioChannel.music, 0.6);
  // app.world.setVolume(AudioChannel.music, 0.2, fade: Duration(seconds: 2));

  // Spatial audio: a listener, and sources that follow their Transform2D.
  // world.spawn()
  //   ..insert(Transform2D.from(0, 0))
  //   ..insert(AudioListener());
  // world.spawn()
  //   ..insert(Transform2D.from(100, 50))
  //   ..insert(AudioSource(soundKey: 'engine', looping: true, autoPlay: true));

  await app.tick();
  print('Audio plugin configured; see the README for more.');
}
