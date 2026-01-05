import 'package:go_router/go_router.dart';

import '../pages/demo_page.dart';
import '../pages/docs_page.dart';
import '../pages/home_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/docs',
      builder: (context, state) =>
          const DocsPage(section: 'getting-started', page: 'introduction'),
    ),
    GoRoute(
      path: '/docs/:section',
      builder: (context, state) {
        final section = state.pathParameters['section']!;
        return DocsPage(section: section, page: 'index');
      },
    ),
    GoRoute(
      path: '/docs/:section/:page',
      builder: (context, state) {
        final section = state.pathParameters['section']!;
        final page = state.pathParameters['page']!;
        return DocsPage(section: section, page: page);
      },
    ),
    GoRoute(
      path: '/demo/grid-game',
      builder: (context, state) => const DemoPage(),
    ),
  ],
);

/// Navigation structure for documentation sidebar
class DocNavigation {
  static const List<NavSection> sections = [
    NavSection(
      title: 'Getting Started',
      path: 'getting-started',
      pages: [
        NavPage(title: 'Introduction', path: 'introduction'),
        NavPage(title: 'Installation', path: 'installation'),
        NavPage(title: 'Quick Start', path: 'quick-start'),
        NavPage(title: 'Core Concepts', path: 'core-concepts'),
      ],
    ),
    NavSection(
      title: 'Guides',
      path: 'guides',
      pages: [
        NavPage(title: 'Entities & Components', path: 'entities-components'),
        NavPage(title: 'Systems', path: 'systems'),
        NavPage(title: 'Queries', path: 'queries'),
        NavPage(title: 'Resources', path: 'resources'),
        NavPage(title: 'Events', path: 'events'),
        NavPage(title: 'Scheduling', path: 'scheduling'),
        NavPage(title: 'System Ordering', path: 'system-ordering'),
        NavPage(title: 'States', path: 'states'),
        NavPage(title: 'Change Detection', path: 'change-detection'),
        NavPage(title: 'Hierarchies', path: 'hierarchies'),
        NavPage(title: 'Observers', path: 'observers'),
        NavPage(title: 'App & Plugins', path: 'app-plugins'),
        NavPage(
            title: 'Two-World Architecture', path: 'two-world-architecture'),
        NavPage(
            title: 'Pixel-Perfect Rendering', path: 'pixel-perfect-rendering'),
      ],
    ),
    NavSection(
      title: 'Plugins',
      path: 'plugins',
      pages: [
        NavPage(title: 'Overview', path: 'overview'),
        NavPage(title: 'Render Infrastructure', path: 'render_plugin'),
        NavPage(title: '2D Rendering', path: 'render'),
        NavPage(title: 'Audio', path: 'audio'),
        NavPage(title: 'Input Handling', path: 'input'),
        NavPage(title: 'Physics & Collision', path: 'physics'),
        NavPage(title: 'Window Management', path: 'window'),
        NavPage(title: 'Tiled Tilemaps', path: 'tiled'),
      ],
    ),
    NavSection(
      title: 'API Reference',
      path: 'api',
      pages: [
        NavPage(title: 'World', path: 'world'),
        NavPage(title: 'Entity', path: 'entity'),
        NavPage(title: 'Component', path: 'component'),
        NavPage(title: 'System', path: 'system'),
        NavPage(title: 'Query', path: 'query'),
        NavPage(title: 'Schedule', path: 'schedule'),
        NavPage(title: 'Commands', path: 'commands'),
        NavPage(title: 'Run Conditions', path: 'run-conditions'),
        NavPage(title: 'System Sets', path: 'system-sets'),
        NavPage(title: 'State', path: 'state'),
        NavPage(title: 'Change Detection', path: 'change-detection'),
        NavPage(title: 'Hierarchy', path: 'hierarchy'),
        NavPage(title: 'Observer', path: 'observer'),
        NavPage(title: 'Reflection', path: 'reflection'),
        NavPage(title: 'App', path: 'app'),
        NavPage(title: 'Plugin', path: 'plugin'),
      ],
    ),
    NavSection(
      title: 'Examples',
      path: 'examples',
      pages: [
        NavPage(title: 'Basic ECS', path: 'basic-ecs'),
        NavPage(title: 'Advanced ECS', path: 'advanced-ecs'),
        NavPage(title: 'Movement System', path: 'movement'),
        NavPage(title: 'Collision Detection', path: 'collision'),
      ],
    ),
    NavSection(
      title: 'Interactive Demos',
      path: 'demos',
      pages: [
        NavPage(title: 'Grid Game', path: 'grid-game'),
      ],
    ),
  ];
}

class NavSection {
  final String title;
  final String path;
  final List<NavPage> pages;

  const NavSection({
    required this.title,
    required this.path,
    required this.pages,
  });
}

class NavPage {
  final String title;
  final String path;

  const NavPage({
    required this.title,
    required this.path,
  });
}
