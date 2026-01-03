// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_audio/fledge_audio.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(AudioPlugin());

  // Initialize systems
  await app.tick();

  // Load audio assets
  // final assets = app.world.audioAssets!;
  // await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
  // await assets.loadMusic('theme', 'assets/music/theme.mp3');

  // Play sound effects
  // app.world.playSfx('explosion');

  // Play music with crossfade
  // app.world.playMusic('theme', crossfade: Duration(seconds: 2));

  // Control volume channels
  // app.world.setVolume(AudioChannel.master, 0.8);
  // app.world.setVolume(AudioChannel.music, 0.6);

  // For spatial audio, add components to entities:
  // world.spawn()
  //   ..insert(Transform2D.from(0, 0))
  //   ..insert(AudioListener());
  //
  // world.spawn()
  //   ..insert(Transform2D.from(100, 50))
  //   ..insert(AudioSource(
  //     soundKey: 'engine',
  //     looping: true,
  //     autoPlay: true,
  //   ));

  print('Audio plugin configured');
  print('See package README for full usage examples');
}
