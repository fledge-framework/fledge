import '../action/input_binding.dart' show GamepadStick;

/// Which family a controller belongs to, for naming its buttons.
enum GamepadFamily {
  /// Xbox and XInput pads (also Steam's virtual pad and most third-party
  /// pads in XInput mode).
  xbox,

  /// DualShock and DualSense.
  playStation,

  /// Switch Pro Controller and Joy-Cons.
  nintendo,

  /// Anything else: named like an Xbox pad, the common layout.
  generic,
}

/// USB vendor ids that settle the family on their own.
const _vendors = {
  0x045E: GamepadFamily.xbox, // Microsoft
  0x054C: GamepadFamily.playStation, // Sony
  0x057E: GamepadFamily.nintendo, // Nintendo
};

/// The family of a pad from what the platform reports: its USB [vendorId]
/// where known (the surest sign), else its [name]. Steam Input presents
/// every pad as an Xbox 360 one, so a game that shows prompts may want a
/// player-facing override.
GamepadFamily detectGamepadFamily(
  String name, {
  int? vendorId,
  int? productId,
}) {
  final byVendor = vendorId == null ? null : _vendors[vendorId];
  if (byVendor != null) return byVendor;
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['xbox', 'xinput', 'x-box'])) return GamepadFamily.xbox;
  if (has(['dualsense', 'dualshock', 'playstation', 'ps4', 'ps5', 'ps3'])) {
    return GamepadFamily.playStation;
  }
  // Sony's pads call themselves just "Wireless Controller" on some
  // platforms; nobody else does.
  if (n.trim() == 'wireless controller') return GamepadFamily.playStation;
  if (has(['pro controller', 'joy-con', 'joycon', 'nintendo', 'switch'])) {
    return GamepadFamily.nintendo;
  }
  return GamepadFamily.generic;
}

/// What a button is called on a [family] pad, for its standard key (`a`,
/// `left_bumper`, `start`; see `GamepadButtonBinding`): "A" / "Cross" /
/// "B" for `a`.
///
/// Keys name positions, so on a Nintendo pad the bottom face button (`a`)
/// is labelled "B" and the right one (`b`) "A": the label follows the
/// button where it sits, which is what the player sees.
String gamepadButtonLabel(String key, GamepadFamily family) {
  final labels = switch (family) {
    GamepadFamily.playStation => _playStation,
    GamepadFamily.nintendo => _nintendo,
    GamepadFamily.xbox || GamepadFamily.generic => _xbox,
  };
  return labels[key] ?? _shared[key] ?? key;
}

/// What a stick is called ("Left stick").
String gamepadStickLabel(GamepadStick stick, GamepadFamily family) =>
    stick == GamepadStick.left ? 'Left stick' : 'Right stick';

const _shared = {
  'dpad_up': 'D-pad up',
  'dpad_down': 'D-pad down',
  'dpad_left': 'D-pad left',
  'dpad_right': 'D-pad right',
};

const _xbox = {
  'a': 'A',
  'b': 'B',
  'x': 'X',
  'y': 'Y',
  'left_bumper': 'LB',
  'right_bumper': 'RB',
  'left_trigger': 'LT',
  'right_trigger': 'RT',
  'back': 'View',
  'start': 'Menu',
  'home': 'Guide',
  'left_stick': 'LS',
  'right_stick': 'RS',
};

const _playStation = {
  'a': 'Cross',
  'b': 'Circle',
  'x': 'Square',
  'y': 'Triangle',
  'left_bumper': 'L1',
  'right_bumper': 'R1',
  'left_trigger': 'L2',
  'right_trigger': 'R2',
  'back': 'Share',
  'start': 'Options',
  'home': 'PS',
  'touchpad': 'Touchpad',
  'left_stick': 'L3',
  'right_stick': 'R3',
};

const _nintendo = {
  // By position: the bottom button is B, the right one A.
  'a': 'B',
  'b': 'A',
  'x': 'Y',
  'y': 'X',
  'left_bumper': 'L',
  'right_bumper': 'R',
  'left_trigger': 'ZL',
  'right_trigger': 'ZR',
  'back': '-',
  'start': '+',
  'home': 'Home',
  'left_stick': 'LS',
  'right_stick': 'RS',
};
