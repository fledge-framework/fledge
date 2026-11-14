/// Music, sound effects and 2D spatial audio for the Fledge ECS game
/// framework.
///
/// - Music with crossfades (native, on the audio thread), streamed from disk
/// - Sound effects, optionally positioned in the world
/// - 2D spatial sources that follow their `Transform2D`
/// - Volume channels (master, music, sfx, voice, ambient) that reach
///   what's already playing
/// - Pause on window focus loss
/// - Nothing ever holds up a frame: the engine starts and clips load in the
///   background
///
/// ```dart
/// final app = App()
///   ..addPlugin(WallTimePlugin())
///   ..addPlugin(AudioPlugin());
///
/// app.world
///   ..loadMusic('theme', 'assets/music/theme.ogg')
///   ..loadSound('door', 'assets/sounds/door.wav');
///
/// app.world.playMusic('theme', crossfade: Duration(seconds: 2));
/// app.world.playSfx('door', position: (120, 40));
/// ```
///
/// Everything above [AudioBackend] is engine-agnostic: [SoLoudBackend] is
/// the default, and tests pass a fake to `AudioPlugin(backend: ...)`.
library;

// Plugin
export 'src/plugin.dart';

// Engine
export 'src/backend/audio_backend.dart';
export 'src/backend/soloud_backend.dart';

// Config
export 'src/config/audio_config.dart';

// Clips
export 'src/assets/audio_clip.dart';

// Resources
export 'src/resources/audio_channels.dart';
export 'src/resources/audio_library.dart';
export 'src/resources/audio_pump.dart';
export 'src/resources/audio_state.dart';

// Components
export 'src/components/audio_listener.dart';
export 'src/components/audio_source.dart';

// Events
export 'src/events/audio_events.dart';

// Commands (World extensions)
export 'src/commands/audio_commands.dart';

// Systems (exported so games can order against their `systemName`)
export 'src/systems/audio_cleanup_system.dart';
export 'src/systems/audio_event_system.dart';
export 'src/systems/audio_focus_system.dart';
export 'src/systems/audio_init_system.dart';
export 'src/systems/channel_fade_system.dart';
export 'src/systems/music_volume_system.dart';
export 'src/systems/spatial_audio_system.dart';
