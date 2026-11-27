# Controller Menus

Menus, inventories and dialogs in a Fledge game are usually ordinary Flutter
widgets stacked over the game view. `fledge_input` makes them work on a
controller without per-widget code: `GamepadFocusBridge` turns the pad into
Flutter focus movement and intents, and `VirtualPointer` adds a stick-driven
mouse pointer for anything focus can't reach.

```yaml
dependencies:
  fledge_input: ^0.7.1
```

Flutter 3.50+ (Dart 3.14+); desktop first (Windows, macOS, Linux), web and
mobile best-effort. The bridge reads the `GamepadState` resource, which
`InputPlugin` inserts and `InputWidget` keeps up to date, so the game needs
both (see [Input](/docs/platform/input)).

## Two kinds of UI

- **Flutter widgets over the game** (pause menus, settings, inventories,
  dialogs). They get focus traversal, scrolling, text input and Material
  controls for free. Drive them with `GamepadFocusBridge`, as this page
  shows. This is the right choice for almost every menu.
- **HUD drawn by `fledge_ui`** (health, score, prompts). Its nodes aren't
  focusable and take no input. If an in-world menu must be drawn with it,
  keep the selection in a resource, move it from a system that reads
  `ActionState` (menu actions in their own `InputContext`), and draw the
  highlight from that resource.

Don't mix the two for one menu: a Flutter menu that also listens to
`ActionState` gets every press twice.

## A pause menu

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';
import 'package:material_ui/material_ui.dart';

class PauseMenu extends StatefulWidget {
  const PauseMenu({
    super.key,
    required this.world,
    required this.open,
    required this.onClose,
  });

  final World world;
  final bool open;
  final VoidCallback onClose;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> {
  final _pointer = VirtualPointerController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // The virtual pointer sends mouse events; don't let them count as
    // the player switching to the mouse.
    widget.world
        .getResource<ActiveInputDevice>()
        ?.gamepadPointerDevices
        .add(VirtualPointer.device);
  }

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();
    return GamepadFocusBridge(
      gamepads: () => widget.world.getResource<GamepadState>(),
      enabled: widget.open,
      pointer: _pointer,
      child: VirtualPointer(
        controller: _pointer,
        child: Actions(
          actions: {
            // B closes the menu.
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                widget.onClose();
                return null;
              },
            ),
            // LB / RB switch tabs.
            GamepadTabIntent: CallbackAction<GamepadTabIntent>(
              onInvoke: (intent) {
                setState(() => _tab = (_tab + intent.delta) % 3);
                return null;
              },
            ),
          },
          child: FocusScope(
            autofocus: true,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tab ${_tab + 1} of 3'),
                  // A activates the focused button (ActivateIntent).
                  ElevatedButton(
                    autofocus: true,
                    onPressed: widget.onClose,
                    child: const Text('Resume'),
                  ),
                  ElevatedButton(onPressed: () {}, child: const Text('Settings')),
                  ElevatedButton(onPressed: () {}, child: const Text('Quit')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Stack it over the game, and stop the game taking keyboard focus while it's
open:

```dart fragment
Stack(children: [
  InputWidget(
    world: app.world,
    claimFocus: !menuOpen, // the menu keeps keyboard focus
    child: FledgeRenderView(app: app),
  ),
  PauseMenu(world: app.world, open: menuOpen, onClose: closeMenu),
])
```

Also stop gameplay reacting to the pad while the menu is open: pause the
world (stop ticking it, or gate systems on a paused state) or switch to an
`InputContext` with no gameplay actions. The bridge reads the pads every
Flutter frame with its own ticker, so it keeps working while the world is
paused.

## What the pad does

| Input | Becomes |
|---|---|
| D-pad, left stick | A `GamepadDirectionIntent(direction, repeat:)` offered to the focused widget; if no enabled action takes it, a `DirectionalFocusIntent` that moves focus and scrolls the newly focused widget into view. Held directions repeat. |
| A | `ActivateIntent` (Material buttons and `FocusableActionDetector` already handle it). |
| B | `DismissIntent`. |
| LB / RB | `GamepadTabIntent(-1)` / `GamepadTabIntent(1)`. |
| LT / RT | `GamepadPageIntent(-1)` / `GamepadPageIntent(1)`, whether the platform reports the triggers as buttons or only as axes. |
| X, Y, Start, Back | `GamepadButtonIntent('x')` and so on, for your own actions (split a stack, sort). |
| Right stick | A `GamepadScrollIntent(delta)` (logical pixels this frame); unhandled, it scrolls (see below). |
| Right stick click | Shows or hides the virtual pointer, if you passed one. |

Intents go to the widget with primary focus when it's inside the bridge,
otherwise to the bridge's child, and travel up the tree to the nearest
`Actions` that handles them. Handle them with `Actions` and `CallbackAction`
as above.

The button-to-intent map is the `buttons` argument
(`GamepadFocusBridge.defaultButtons` by default), keyed by standard button
names; the d-pad, sticks and triggers aren't in it:

```dart fragment
GamepadFocusBridge(
  gamepads: () => world.getResource<GamepadState>(),
  buttons: {
    ...GamepadFocusBridge.defaultButtons,
    'y': const GamepadButtonIntent('details'),
  },
  child: menu,
)
```

### Left and right on a value

A slider or a "Volume: ◀ 7 ▶" row should take left and right itself and let
up and down move focus. Give it an action for `GamepadDirectionIntent` that is
only enabled for the horizontal directions:

```dart
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/widgets.dart';

class AdjustValue extends Action<GamepadDirectionIntent> {
  AdjustValue(this.onStep);
  final void Function(int step) onStep;

  @override
  bool isEnabled(GamepadDirectionIntent intent) =>
      intent.direction == TraversalDirection.left ||
      intent.direction == TraversalDirection.right;

  @override
  Object? invoke(GamepadDirectionIntent intent) {
    onStep(intent.direction == TraversalDirection.right ? 1 : -1);
    return null;
  }
}

Widget volumeRow(int volume, void Function(int) change) => Actions(
  actions: {GamepadDirectionIntent: AdjustValue(change)},
  child: Focus(child: Text('Volume: $volume')),
);
```

`intent.repeat` tells a held direction's repeats from the first push, if
repeats should step faster or not at all.

### Scrolling

The right stick sends `GamepadScrollIntent` to the focus first. Unhandled, it
scrolls the nearest `Scrollable` around the focused widget that can move the
way the stick pushes. One that can't (it scrolls on the other axis, is
already at its end, or has nothing to scroll) passes the push out to the
next `Scrollable` around it, so a short list inside a long page still lets
the page scroll.

## Opening and closing

When `enabled` turns true, the bridge forgets every press made before, and a
direction already held must be let go first: the A that opened a screen, or a
B held to run, never acts inside it. When it turns false, the virtual pointer
is hidden. With `enabled: false` the bridge does nothing at all.

## The virtual pointer

Some UI isn't in focus order: a map you click on, drag-and-drop between
grids, a widget you left out of traversal on purpose. Pass a
`VirtualPointerController` as `pointer` and wrap the menu in
`VirtualPointer(controller: ...)`:

- Clicking the right stick shows the pointer (where it last was, the middle
  of the view the first time). While it's showing it has the pad to itself.
- The right stick moves it (up to `pointerSpeed` logical pixels a second).
- A clicks, and drags while held; X right-clicks.
- B, the right stick click, the d-pad or the left stick put it away and
  return to focus navigation.

`VirtualPointer` sends real mouse events from device `VirtualPointer.device`
through Flutter's gesture binding, so `MouseRegion`, `GestureDetector` and
drags respond exactly as they do to a mouse. Add that device to
`ActiveInputDevice.gamepadPointerDevices` (as in the example) so it never
counts as the mouse. `cursor` and `hotSpot` replace the default arrow. The
controller also works on its own: `show(at:)`, `hide()`, `moveBy(delta)`,
`press(button)` and `release(button)`.

## Tuning

| Argument | Default | Meaning |
|---|---|---|
| `repeatDelay` | 380 ms | How long a direction is held before it repeats. |
| `repeatInterval` | 90 ms | Time between repeats. |
| `stickPress` | 0.5 | Left-stick deflection that counts as a direction. |
| `stickRelease` | 0.35 | Deflection below which a held stick direction lets go. |
| `scrollSpeed` | 900 | Right-stick scrolling at full tilt, logical px/s. |
| `pointerToggle` | `'right_stick'` | Button that shows and hides the pointer. |
| `pointerSpeed` | 1100 | Pointer speed at full tilt, logical px/s. |

## Keyboard focus and InputWidget

`InputWidget` takes keyboard focus on mount, when the mouse enters it and on
every click, so the game hears keys. That fights a menu with its own focus.
`InputWidget(claimFocus: false)` stops it taking focus at all; the game then
hears no keys. When `claimFocus` turns back to true, it takes focus again and
catches the keyboard up (`KeyboardState.sync`), so a key let go while the menu
had focus isn't stuck down, and one pressed there doesn't fire in the game.

While the game does have focus, `InputWidget` handles only keys bound in the
active `InputMap` and lets the rest bubble to ancestor `Focus` widgets, so
app-level shortcuts keep working.

To show the right button prompts ("A: confirm" or "Cross: confirm"), listen
to the `ActiveInputDevice` resource and name buttons with
`gamepadButtonLabel`; see [Input](/docs/platform/input).

See the [API reference](https://pub.dev/documentation/fledge_input/latest/)
for every member.
