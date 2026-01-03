import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, theme, isDark),
            _buildFeatures(context, theme),
            _buildQuickStart(context, theme),
            _buildFooter(context, theme, isDark),
          ],
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
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Fledge',
            style: theme.textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
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
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => context.go('/docs/getting-started/introduction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: FledgeTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Get Started'),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => context.go('/docs/api/world'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('API Reference'),
              ),
            ],
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

  Widget _buildFooter(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'Fledge is open source and available under the MIT license.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Built with Flutter',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
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
