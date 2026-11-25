import 'package:go_router/go_router.dart';

import '../pages/demo_page.dart';
import '../pages/docs_page.dart';
import '../pages/drifter_page.dart';
import '../pages/home_page.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) => docsRedirect(state.uri.path),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/docs/:section/:page',
      builder: (context, state) => DocsPage(
        section: state.pathParameters['section']!,
        page: state.pathParameters['page']!,
        fragment: state.uri.fragment.isEmpty ? null : state.uri.fragment,
      ),
    ),
    GoRoute(
      path: '/demo/grid-game',
      builder: (context, state) => const DemoPage(),
    ),
    GoRoute(
      path: '/demo/drifter',
      builder: (context, state) => const DrifterPage(),
    ),
  ],
);

/// Where [path] should go instead, or null to stay.
///
/// Covers `/docs`, a bare `/docs/<section>` (its first page), and every URL
/// the site used before the 0.6 restructure ([legacyRedirects]), which
/// published package READMEs still link to.
String? docsRedirect(String path) {
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/docs') return DocNavigation.sections.first.firstLocation;
  final legacy = legacyRedirects[trimmed];
  if (legacy != null) return legacy;
  final parts = trimmed.split('/');
  if (parts.length == 3 && parts[1] == 'docs') {
    for (final section in DocNavigation.sections) {
      if (section.path == parts[2]) return section.firstLocation;
    }
  }
  return null;
}

/// Pre-0.6 docs URLs and where their content lives now.
const Map<String, String> legacyRedirects = {
  // Getting started
  '/docs/getting-started/hello-fledge': '/docs/getting-started/first-app',
  '/docs/getting-started/building-snake':
      '/docs/getting-started/tutorial-snake',
  '/docs/getting-started/quick-start': '/docs/getting-started/first-app',
  // Guides
  '/docs/guides': '/docs/ecs/entities-components',
  '/docs/guides/entities-components': '/docs/ecs/entities-components',
  '/docs/guides/systems': '/docs/ecs/systems',
  '/docs/guides/queries': '/docs/ecs/queries',
  '/docs/guides/resources': '/docs/ecs/resources',
  '/docs/guides/events': '/docs/ecs/events',
  '/docs/guides/scheduling': '/docs/scheduling/schedules',
  '/docs/guides/system-ordering': '/docs/scheduling/ordering-and-sets',
  '/docs/guides/states': '/docs/ecs/states-run-conditions',
  '/docs/guides/change-detection': '/docs/ecs/change-detection',
  '/docs/guides/hierarchies': '/docs/ecs/hierarchies',
  '/docs/guides/observers': '/docs/ecs/observers',
  '/docs/guides/app-plugins': '/docs/app/app-and-plugins',
  '/docs/guides/two-world-architecture': '/docs/rendering/overview',
  '/docs/guides/pixel-perfect-rendering': '/docs/rendering/pixel-art',
  // API reference (merged into the guides)
  '/docs/api': '/docs/ecs/entities-components',
  '/docs/api/world': '/docs/ecs/entities-components',
  '/docs/api/entity': '/docs/ecs/entities-components',
  '/docs/api/component': '/docs/ecs/entities-components',
  '/docs/api/system': '/docs/ecs/systems',
  '/docs/api/query': '/docs/ecs/queries',
  '/docs/api/schedule': '/docs/scheduling/schedules',
  '/docs/api/commands': '/docs/ecs/commands',
  '/docs/api/run-conditions': '/docs/ecs/states-run-conditions',
  '/docs/api/system-sets': '/docs/scheduling/ordering-and-sets',
  '/docs/api/state': '/docs/ecs/states-run-conditions',
  '/docs/api/change-detection': '/docs/ecs/change-detection',
  '/docs/api/hierarchy': '/docs/ecs/hierarchies',
  '/docs/api/observer': '/docs/ecs/observers',
  '/docs/api/reflection': '/docs/app/reflection',
  '/docs/api/app': '/docs/app/app-and-plugins',
  '/docs/api/plugin': '/docs/app/app-and-plugins',
  // Plugins
  '/docs/plugins': '/docs/app/packages',
  '/docs/plugins/overview': '/docs/app/packages',
  '/docs/plugins/assets': '/docs/app/assets',
  '/docs/plugins/render': '/docs/rendering/overview',
  '/docs/plugins/camera_2d': '/docs/rendering/cameras',
  '/docs/plugins/particles': '/docs/rendering/particles',
  '/docs/plugins/lighting_2d': '/docs/rendering/lighting',
  '/docs/plugins/tween': '/docs/rendering/tween',
  '/docs/plugins/ui': '/docs/ui/hud',
  '/docs/plugins/debug': '/docs/ui/debug',
  '/docs/plugins/audio': '/docs/platform/audio',
  '/docs/plugins/input': '/docs/platform/input',
  '/docs/plugins/window': '/docs/platform/window',
  '/docs/plugins/physics': '/docs/gameplay/physics',
  '/docs/plugins/save': '/docs/gameplay/save',
  '/docs/plugins/calendar': '/docs/gameplay/calendar',
  '/docs/plugins/tiled': '/docs/gameplay/tiled',
  '/docs/plugins/yarn': '/docs/gameplay/dialogue',
  '/docs/plugins/net': '/docs/networking/overview',
  // Examples
  '/docs/examples/movement': '/docs/ecs/systems',
  '/docs/examples/collision': '/docs/gameplay/physics',
};

/// The published packages, for the API reference links.
const List<String> fledgePackages = [
  'fledge_ecs',
  'fledge_ecs_annotations',
  'fledge_ecs_generator',
  'fledge_assets',
  'fledge_render_2d',
  'fledge_camera_2d',
  'fledge_lighting_2d',
  'fledge_particles',
  'fledge_tween',
  'fledge_ui',
  'fledge_debug',
  'fledge_input',
  'fledge_window',
  'fledge_audio',
  'fledge_physics',
  'fledge_tiled',
  'fledge_yarn',
  'fledge_save',
  'fledge_calendar',
  'fledge_net',
  'fledge_net_steam',
];

/// Navigation structure for the documentation sidebar, prev/next links,
/// search index and sitemap. Each page is
/// `assets/docs/<section>/<page>.md` unless it is a demo or an external
/// link.
class DocNavigation {
  static const List<NavSection> sections = [
    NavSection(
      group: 'Learn',
      title: 'Getting Started',
      path: 'getting-started',
      pages: [
        NavPage(title: 'Introduction', path: 'introduction'),
        NavPage(title: 'Installation', path: 'installation'),
        NavPage(title: 'Your First App', path: 'first-app'),
        NavPage(title: 'Core Concepts', path: 'core-concepts'),
        NavPage(title: 'Tutorial: Snake', path: 'tutorial-snake'),
      ],
    ),
    NavSection(
      group: 'Core',
      title: 'ECS',
      path: 'ecs',
      pages: [
        NavPage(title: 'Entities & Components', path: 'entities-components'),
        NavPage(title: 'Queries', path: 'queries'),
        NavPage(title: 'Systems', path: 'systems'),
        NavPage(title: 'Resources', path: 'resources'),
        NavPage(title: 'Events', path: 'events'),
        NavPage(title: 'Commands', path: 'commands'),
        NavPage(title: 'Hierarchies', path: 'hierarchies'),
        NavPage(title: 'Observers', path: 'observers'),
        NavPage(title: 'Change Detection', path: 'change-detection'),
        NavPage(
          title: 'States & Run Conditions',
          path: 'states-run-conditions',
        ),
      ],
    ),
    NavSection(
      group: 'Core',
      title: 'Scheduling & Time',
      path: 'scheduling',
      pages: [
        NavPage(title: 'Schedules & the Frame', path: 'schedules'),
        NavPage(title: 'Ordering & Sets', path: 'ordering-and-sets'),
        NavPage(title: 'Time & Fixed Timestep', path: 'time'),
      ],
    ),
    NavSection(
      group: 'Core',
      title: 'App & Tooling',
      path: 'app',
      pages: [
        NavPage(title: 'App & Plugins', path: 'app-and-plugins'),
        NavPage(title: 'Package Catalog', path: 'packages'),
        NavPage(title: 'Code Generation', path: 'codegen'),
        NavPage(title: 'Assets', path: 'assets'),
        NavPage(title: 'Reflection & Serialization', path: 'reflection'),
      ],
    ),
    NavSection(
      group: 'Engine',
      title: 'Rendering',
      path: 'rendering',
      pages: [
        NavPage(title: 'Rendering Overview', path: 'overview'),
        NavPage(title: 'Sprites & Animation', path: 'sprites-animation'),
        NavPage(title: 'Transforms', path: 'transforms'),
        NavPage(title: 'Cameras', path: 'cameras'),
        NavPage(title: 'Pixel Art', path: 'pixel-art'),
        NavPage(title: 'Lighting', path: 'lighting'),
        NavPage(title: 'Particles', path: 'particles'),
        NavPage(title: 'Tweens', path: 'tween'),
        NavPage(title: 'Render Graph (Advanced)', path: 'render-graph'),
      ],
    ),
    NavSection(
      group: 'Engine',
      title: 'UI & Tools',
      path: 'ui',
      pages: [
        NavPage(title: 'HUD', path: 'hud'),
        NavPage(title: 'Controller Menus', path: 'controller-menus'),
        NavPage(title: 'Debug Tools', path: 'debug'),
      ],
    ),
    NavSection(
      group: 'Engine',
      title: 'Platform',
      path: 'platform',
      pages: [
        NavPage(title: 'Input', path: 'input'),
        NavPage(title: 'Window', path: 'window'),
        NavPage(title: 'Audio', path: 'audio'),
      ],
    ),
    NavSection(
      group: 'Features',
      title: 'Gameplay',
      path: 'gameplay',
      pages: [
        NavPage(title: 'Physics & Collision', path: 'physics'),
        NavPage(title: 'Pathfinding', path: 'pathfinding'),
        NavPage(title: 'Tiled Maps', path: 'tiled'),
        NavPage(title: 'Rendering Tilemaps', path: 'tiled-rendering'),
        NavPage(title: 'Tile Placement', path: 'placement'),
        NavPage(title: 'Dialogue (Yarn)', path: 'dialogue'),
        NavPage(title: 'Save & Load', path: 'save'),
        NavPage(title: 'Calendar', path: 'calendar'),
      ],
    ),
    NavSection(
      group: 'Features',
      title: 'Networking',
      path: 'networking',
      pages: [
        NavPage(title: 'Networking Overview', path: 'overview'),
        NavPage(title: 'Replication', path: 'replication'),
        NavPage(title: 'Configuration', path: 'configuration'),
        NavPage(title: 'Security & Identity', path: 'security-identity'),
        NavPage(title: 'Steam', path: 'steam'),
        NavPage(title: 'Low-Level API', path: 'low-level'),
      ],
    ),
    NavSection(
      group: 'More',
      title: 'Examples',
      path: 'examples',
      pages: [
        NavPage(title: 'Basic ECS', path: 'basic-ecs'),
        NavPage(title: 'Advanced ECS', path: 'advanced-ecs'),
        NavPage(title: 'Drifter', path: 'drifter'),
      ],
    ),
    NavSection(
      group: 'More',
      title: 'Interactive Demos',
      path: 'demos',
      routePrefix: '/demo',
      pages: [
        NavPage(title: 'Grid Game', path: 'grid-game'),
        NavPage(title: 'Drifter', path: 'drifter'),
      ],
    ),
    NavSection(
      group: 'More',
      title: 'API Reference',
      path: 'api-reference',
      pages: [
        NavPage(
          title: 'fledge_ecs',
          path: 'fledge_ecs',
          externalUrl: 'https://pub.dev/documentation/fledge_ecs/latest/',
        ),
        NavPage(
          title: 'fledge_ecs_annotations',
          path: 'fledge_ecs_annotations',
          externalUrl:
              'https://pub.dev/documentation/fledge_ecs_annotations/latest/',
        ),
        NavPage(
          title: 'fledge_ecs_generator',
          path: 'fledge_ecs_generator',
          externalUrl:
              'https://pub.dev/documentation/fledge_ecs_generator/latest/',
        ),
        NavPage(
          title: 'fledge_assets',
          path: 'fledge_assets',
          externalUrl: 'https://pub.dev/documentation/fledge_assets/latest/',
        ),
        NavPage(
          title: 'fledge_render_2d',
          path: 'fledge_render_2d',
          externalUrl: 'https://pub.dev/documentation/fledge_render_2d/latest/',
        ),
        NavPage(
          title: 'fledge_camera_2d',
          path: 'fledge_camera_2d',
          externalUrl: 'https://pub.dev/documentation/fledge_camera_2d/latest/',
        ),
        NavPage(
          title: 'fledge_lighting_2d',
          path: 'fledge_lighting_2d',
          externalUrl:
              'https://pub.dev/documentation/fledge_lighting_2d/latest/',
        ),
        NavPage(
          title: 'fledge_particles',
          path: 'fledge_particles',
          externalUrl: 'https://pub.dev/documentation/fledge_particles/latest/',
        ),
        NavPage(
          title: 'fledge_tween',
          path: 'fledge_tween',
          externalUrl: 'https://pub.dev/documentation/fledge_tween/latest/',
        ),
        NavPage(
          title: 'fledge_ui',
          path: 'fledge_ui',
          externalUrl: 'https://pub.dev/documentation/fledge_ui/latest/',
        ),
        NavPage(
          title: 'fledge_debug',
          path: 'fledge_debug',
          externalUrl: 'https://pub.dev/documentation/fledge_debug/latest/',
        ),
        NavPage(
          title: 'fledge_input',
          path: 'fledge_input',
          externalUrl: 'https://pub.dev/documentation/fledge_input/latest/',
        ),
        NavPage(
          title: 'fledge_window',
          path: 'fledge_window',
          externalUrl: 'https://pub.dev/documentation/fledge_window/latest/',
        ),
        NavPage(
          title: 'fledge_audio',
          path: 'fledge_audio',
          externalUrl: 'https://pub.dev/documentation/fledge_audio/latest/',
        ),
        NavPage(
          title: 'fledge_physics',
          path: 'fledge_physics',
          externalUrl: 'https://pub.dev/documentation/fledge_physics/latest/',
        ),
        NavPage(
          title: 'fledge_tiled',
          path: 'fledge_tiled',
          externalUrl: 'https://pub.dev/documentation/fledge_tiled/latest/',
        ),
        NavPage(
          title: 'fledge_yarn',
          path: 'fledge_yarn',
          externalUrl: 'https://pub.dev/documentation/fledge_yarn/latest/',
        ),
        NavPage(
          title: 'fledge_save',
          path: 'fledge_save',
          externalUrl: 'https://pub.dev/documentation/fledge_save/latest/',
        ),
        NavPage(
          title: 'fledge_calendar',
          path: 'fledge_calendar',
          externalUrl: 'https://pub.dev/documentation/fledge_calendar/latest/',
        ),
        NavPage(
          title: 'fledge_net',
          path: 'fledge_net',
          externalUrl: 'https://pub.dev/documentation/fledge_net/latest/',
        ),
        NavPage(
          title: 'fledge_net_steam',
          path: 'fledge_net_steam',
          externalUrl: 'https://pub.dev/documentation/fledge_net_steam/latest/',
        ),
      ],
    ),
  ];

  /// Every markdown-backed page, in reading order.
  static Iterable<(NavSection, NavPage)> get markdownPages sync* {
    for (final section in sections) {
      for (final page in section.pages) {
        if (section.isMarkdown && page.externalUrl == null) {
          yield (section, page);
        }
      }
    }
  }

  /// Every page with an in-site route (markdown pages and demos), in
  /// reading order. Drives prev/next and the sitemap.
  static Iterable<(NavSection, NavPage)> get routedPages sync* {
    for (final section in sections) {
      for (final page in section.pages) {
        if (page.externalUrl == null) yield (section, page);
      }
    }
  }
}

class NavSection {
  /// Sidebar group heading this section sits under.
  final String group;
  final String title;
  final String path;
  final List<NavPage> pages;

  /// Route prefix for pages that are not markdown (e.g. `/demo`). Null for
  /// markdown sections, whose pages live under `/docs/<path>/`.
  final String? routePrefix;

  const NavSection({
    required this.group,
    required this.title,
    required this.path,
    required this.pages,
    this.routePrefix,
  });

  /// Whether pages here are `assets/docs/<path>/<page>.md` files.
  bool get isMarkdown => routePrefix == null;

  /// The in-site location of [page], or null for an external link.
  String? locationOf(NavPage page) {
    if (page.externalUrl != null) return null;
    return routePrefix == null
        ? '/docs/$path/${page.path}'
        : '$routePrefix/${page.path}';
  }

  /// The location of the first in-site page.
  String get firstLocation =>
      pages.map(locationOf).firstWhere((l) => l != null, orElse: () => '/')!;
}

class NavPage {
  final String title;
  final String path;

  /// When set, the sidebar opens this URL in a new tab instead of a page.
  final String? externalUrl;

  const NavPage({required this.title, required this.path, this.externalUrl});
}
