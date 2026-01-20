import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _githubUrl = 'https://github.com/mattrltrent/fledge';
  static const _pubDevUrl = 'https://pub.dev/packages/fledge_ecs';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, theme, isDark),
              _buildExternalLinks(context, theme, isDark),
              _buildFeatures(context, theme),
              _buildQuickStart(context, theme),
              _buildCallToAction(context, theme, isDark),
              _buildFooter(context, theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FledgeTheme.primaryColor,
            FledgeTheme.secondaryColor,
            FledgeTheme.primaryColor.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'v0.1.10 - Early Preview',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Fledge',
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A Bevy-inspired ECS game framework for Flutter',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Build performant desktop games with clean architecture',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/docs/getting-started/introduction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: FledgeTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.rocket_launch, size: 20),
                label: const Text('Get Started'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/demo/grid-game'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Try the Demo'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/docs/api/world'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.menu_book, size: 20),
                label: const Text('API Reference'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExternalLinks(
      BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? FledgeTheme.surfaceDark : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Wrap(
        spacing: 32,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          _ExternalLinkChip(
            icon: Icons.code,
            label: 'View on GitHub',
            onTap: () => _launchUrl(_githubUrl),
          ),
          _ExternalLinkChip(
            icon: Icons.inventory_2,
            label: 'pub.dev',
            onTap: () => _launchUrl(_pubDevUrl),
          ),
          _ExternalLinkChip(
            icon: Icons.description,
            label: 'Documentation',
            onTap: () => context.go('/docs/getting-started/introduction'),
          ),
          _ExternalLinkChip(
            icon: Icons.sports_esports,
            label: 'Interactive Demo',
            onTap: () => context.go('/demo/grid-game'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Why Fledge?',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _FeatureCard(
                icon: Icons.grid_view_rounded,
                title: 'Entity Component System',
                description:
                    'Clean separation of data and logic with archetype-based storage for excellent cache locality.',
              ),
              _FeatureCard(
                icon: Icons.code_rounded,
                title: 'Code Generation',
                description:
                    'Minimal boilerplate with annotation-based code generation. Define components and systems with simple decorators.',
              ),
              _FeatureCard(
                icon: Icons.speed_rounded,
                title: 'Parallel Execution',
                description:
                    'Automatic parallel system execution based on dependency analysis. Get concurrency without the complexity.',
              ),
              _FeatureCard(
                icon: Icons.extension_rounded,
                title: 'Modular Design',
                description:
                    'Compose your game from reusable plugins. Add only what you need, extend with your own modules.',
              ),
              _FeatureCard(
                icon: Icons.check_circle_rounded,
                title: 'Type Safe',
                description:
                    'Full type safety with compile-time checks. Catch errors before runtime with Dart\'s strong typing.',
              ),
              _FeatureCard(
                icon: Icons.desktop_windows_rounded,
                title: 'Desktop First',
                description:
                    'Optimized for Windows, macOS, and Linux. Build performant desktop games with Flutter.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStart(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark ? FledgeTheme.surfaceDark : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Quick Example',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 32),
          Container(
            constraints: const BoxConstraints(maxWidth: 700),
            decoration: BoxDecoration(
              color: isDark ? FledgeTheme.phantom : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? FledgeTheme.secondaryColor.withValues(alpha: 0.3)
                    : Colors.grey.shade300,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              '''// Define components
@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@component
class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

// Define systems
@system
void movementSystem(Query2<Position, Velocity> query) {
  for (final (entity, pos, vel) in query.iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}

// Run the game
void main() {
  final world = World();

  // Spawn entities
  world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(1, 1));

  // Run systems
  final schedule = Schedule()
    ..addSystem(FunctionSystem(movementSystem));

  schedule.run(world);
}''',
              style: FledgeTheme.codeStyle.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallToAction(
      BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FledgeTheme.secondaryColor.withValues(alpha: isDark ? 0.3 : 0.1),
            FledgeTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.05),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Ready to build your game?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Follow our step-by-step tutorial and build a complete Snake game\nfrom scratch using Fledge.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    context.go('/docs/getting-started/building-snake'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FledgeTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.school, size: 20),
                label: const Text('Start the Tutorial'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _launchUrl(_githubUrl),
                icon: const Icon(Icons.code, size: 18),
                label: const Text('GitHub'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              TextButton.icon(
                onPressed: () => _launchUrl(_pubDevUrl),
                icon: const Icon(Icons.inventory_2, size: 18),
                label: const Text('pub.dev'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              TextButton.icon(
                onPressed: () => _launchUrl('$_githubUrl/issues'),
                icon: const Icon(Icons.bug_report, size: 18),
                label: const Text('Report Issue'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Fledge is open source and available under the Apache 2.0 license.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Built with ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
              Icon(
                Icons.favorite,
                size: 14,
                color: FledgeTheme.primaryColor.withValues(alpha: 0.7),
              ),
              Text(
                ' and Flutter',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExternalLinkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExternalLinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: FledgeTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 40,
            color: FledgeTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
