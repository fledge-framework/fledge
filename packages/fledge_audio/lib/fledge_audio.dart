/// A full-featured audio plugin for the Fledge ECS game framework.
///
/// This package provides:
/// - Background music with crossfading
/// - Sound effects with volume control
/// - 2D spatial/positional audio
/// - Volume channels (master, music, sfx, voice, ambient)
/// - Pause on window focus loss
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_audio/fledge_audio.dart';
///
/// // Setup
/// await App()
///   .addPlugin(TimePlugin())
///   .addPlugin(AudioPlugin())
///   .run();
///
/// // Load assets
/// final assets = world.audioAssets!;
/// await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
/// await assets.loadMusic('theme', 'assets/music/theme.mp3');
///
/// // Play audio
/// world.playSfx('explosion');
/// world.playMusic('theme', crossfade: Duration(seconds: 2));
/// ```
///
/// ## Spatial Audio
///
/// ```dart
/// // Add listener to player/camera
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(AudioListener());
///
/// // Add audio source to entities
/// world.spawn()
///   ..insert(Transform2D.from(100, 50))
///   ..insert(AudioSource(
///     soundKey: 'engine',
///     looping: true,
///     autoPlay: true,
///   ));
/// ```
library;

// Plugin
export 'src/plugin.dart';

// Config
export 'src/config/audio_config.dart';

// Assets
export 'src/assets/audio_assets.dart';

// Resources
export 'src/resources/audio_state.dart';
export 'src/resources/audio_channels.dart';

// Components
export 'src/components/audio_listener.dart';
export 'src/components/audio_source.dart';

// Events
export 'src/events/audio_events.dart';

// Commands (World extensions)
export 'src/commands/audio_commands.dart';
