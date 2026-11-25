# Fledge docs site

The Flutter web app behind [fledge-framework.dev](https://fledge-framework.dev):
the landing page, the documentation, and the interactive demos.

```bash
cd docs
flutter run -d chrome          # develop
flutter build web              # what CI builds
flutter test                   # navigation, sitemap and demo tests
dart run tool/check_snippets.dart   # analyze every code sample (also: melos run docs:check)
```

## Where things live

| Path | What |
|---|---|
| `assets/docs/<section>/<page>.md` | Documentation pages, served at `/docs/<section>/<page>` |
| `lib/app/router.dart` | `DocNavigation` (sidebar, prev/next, search, sitemap), routes, and `legacyRedirects` for old URLs |
| `lib/app/version.dart` | `kFledgeVersion`, shown on the home page; `scripts/release.dart` updates it |
| `lib/pages/` | Home, docs, and demo pages |
| `lib/samples/` | Code shown on the home page, as real analyzed files |
| `lib/demos/grid_game/` | The Grid Game demo; its walkthrough shows these files |
| `tool/check_snippets.dart` | Snippet and version-pin checker (runs in CI) |
| `web/sitemap.xml` | Generated from `DocNavigation`; see below |

## Adding or moving a page

1. Write `assets/docs/<section>/<page>.md`. A new section directory also goes
   under `flutter.assets` in `pubspec.yaml` (asset directories aren't
   recursive).
2. Add a `NavPage` to the section in `DocNavigation` (`lib/app/router.dart`).
3. Moving or deleting a page? Add its old URL to `legacyRedirects`. Package
   READMEs on pub.dev link to the site, so old URLs must keep working.
4. Regenerate the sitemap: `UPDATE_SITEMAP=1 flutter test test/navigation_test.dart`.

`test/navigation_test.dart` fails if a nav entry has no file, a file isn't in
the nav, a redirect points nowhere, or the sitemap is stale.

## Writing pages

- Describe what the code does today, checked against the source. Package
  READMEs are the source of truth for public API examples; keep them in step.
- Version pins are `^<current version>` (`fledge_ecs: ^0.6.0`). The checker
  fails on anything else, and the release script rewrites them.
- Register systems with `schedule: Schedules.x`, never the deprecated
  `stage:`. Order built-in systems by their `systemName` constants, never
  string literals. Import Material from `package:material_ui`.
- Systems are synchronous unless they truly await.
- Pages for Flutter packages say what they need (Flutter 3.50+, desktop
  platforms) near the top.
- Link to other pages as `/docs/<section>/<page>`, and to a heading as
  `#heading-text` or `/docs/<section>/<page>#heading-text` (lowercase, spaces
  become hyphens, punctuation dropped).

### Code samples

Every ` ```dart ` block, and every tab of a ` ```dart-tabs ` block, is
analyzed by `tool/check_snippets.dart`. Errors and warnings fail CI.

- A block without imports gets a prelude that imports `dart:async`,
  `dart:math as math`, `dart:typed_data`, `dart:ui` and every fledge package.
  A block with its own imports is analyzed exactly as written; use that for
  Flutter widget code.
- A block made of statements (no `main`, no declarations) is analyzed inside
  a function body, so `final app = App()..addPlugin(...);` works on its own.
  Don't mix top-level statements with declarations in one block.
- Code that later blocks on the page rely on (component classes and so on)
  goes in a hidden setup block. The site doesn't render HTML comments:

  ````markdown
  <!-- snippet-setup
  class Position { double x = 0, y = 0; }
  class Velocity { double dx = 0, dy = 0; }
  -->
  ````

- Partial code (`...`, a lone method, generated code that needs
  build_runner) is marked ` ```dart fragment ` and skipped.

```dart-tabs
// @tab First
print('tabs are split on "// @tab <label>" lines');
// @tab Second
print('and each tab is checked separately');
```
