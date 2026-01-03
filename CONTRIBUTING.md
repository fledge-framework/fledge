# Contributing to Fledge

Thank you for your interest in contributing to Fledge! This document provides guidelines and information for contributors.

## Code of Conduct

Please be respectful and constructive in all interactions. We want Fledge to be a welcoming community for everyone.

## Getting Started

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) (3.0.0 or higher)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 or higher)
- [Melos](https://melos.invertase.dev/) for monorepo management

### Setting Up the Development Environment

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/fledge.git
   cd fledge
   ```

2. Install Melos globally:
   ```bash
   dart pub global activate melos
   ```

3. Bootstrap the workspace:
   ```bash
   melos bootstrap
   ```

4. Verify everything works:
   ```bash
   melos analyze
   melos test
   ```

## Development Workflow

### Branch Naming

Use descriptive branch names with prefixes:
- `feature/` - New features (e.g., `feature/add-audio-effects`)
- `fix/` - Bug fixes (e.g., `fix/memory-leak-in-query`)
- `docs/` - Documentation changes (e.g., `docs/improve-getting-started`)
- `refactor/` - Code refactoring (e.g., `refactor/simplify-scheduler`)
- `chore/` - Maintenance tasks (e.g., `chore/update-dependencies`)

### Making Changes

1. Create a new branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes, following the [code style guidelines](#code-style)

3. Run the checks locally before committing:
   ```bash
   melos format      # Format code
   melos analyze     # Check for issues
   melos test        # Run tests
   ```

4. Write meaningful commit messages following [Conventional Commits](https://www.conventionalcommits.org/) (see [Commit Message Guidelines](#commit-message-guidelines))

5. Push your branch and open a Pull Request

### Pull Request Guidelines

- Fill out the PR template completely
- Link any related issues
- Ensure all CI checks pass
- Keep PRs focused - one feature or fix per PR
- Add tests for new functionality
- Update documentation if needed

## Code Style

### Formatting

All code must be formatted with `dart format`. Run before committing:
```bash
melos format
```

### Analysis

Code must pass `dart analyze` with no errors or warnings:
```bash
melos analyze
```

### Documentation

- Add doc comments to all public APIs
- Use `///` for documentation comments
- Include code examples where helpful
- Escape angle brackets in doc comments with backticks: `` `List<T>` ``

### Testing

- Write tests for new functionality
- Maintain or improve code coverage
- Place tests in the `test/` directory of each package
- Use descriptive test names

## Commit Message Guidelines

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. This enables automatic changelog generation for each package and makes it easier to understand the project history.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Changes that do not affect the meaning of the code (formatting, etc.) |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `perf` | A code change that improves performance |
| `test` | Adding missing tests or correcting existing tests |
| `chore` | Changes to the build process or auxiliary tools |

### Scope

The scope should be the name of the package affected (e.g., `fledge_ecs`, `fledge_input`, `fledge_tiled`). For changes affecting multiple packages or the root project, you can omit the scope or use `*`.

### Examples

```bash
# Feature in a specific package
feat(fledge_ecs): add support for system ordering constraints

# Bug fix with scope
fix(fledge_input): correct gamepad axis normalization

# Documentation change (no scope)
docs: update installation instructions in README

# Breaking change (use ! after scope)
feat(fledge_ecs)!: rename Query.iter() to Query.iterate()

# Chore affecting multiple packages
chore(*): update dependencies to latest versions

# Multi-line commit with body
fix(fledge_tiled): handle missing tileset properties gracefully

Previously, missing properties would cause a null reference error.
Now returns a default value when the property is not defined.

Closes #123
```

### Why Conventional Commits?

- **Automatic changelogs**: Each package gets its own changelog generated from commit history
- **Clear communication**: The nature of changes is immediately apparent
- **Semantic versioning**: Commit types help determine version bumps
- **Better history**: Easy to filter and search through project history

## Package Architecture

### Core Packages

| Package | Description |
|---------|-------------|
| `fledge_ecs` | Core ECS implementation |
| `fledge_ecs_annotations` | Annotations for code generation |
| `fledge_ecs_generator` | Code generator for components/systems |

### Render Packages

| Package | Description |
|---------|-------------|
| `fledge_render` | Core render infrastructure |
| `fledge_render_2d` | 2D rendering components |
| `fledge_render_flutter` | Flutter integration |

### Plugin Packages

| Package | Description |
|---------|-------------|
| `fledge_audio` | Audio and sound effects |
| `fledge_input` | Input handling |
| `fledge_window` | Window management |
| `fledge_tiled` | Tiled map integration |

### Dependency Order

When making changes that affect multiple packages, be aware of the dependency order:
1. `fledge_ecs_annotations`
2. `fledge_ecs`
3. `fledge_render`
4. `fledge_render_2d`
5. `fledge_render_flutter`
6. `fledge_input`, `fledge_audio`, `fledge_window` (parallel)
7. `fledge_tiled`
8. `fledge_ecs_generator`

## Adding New Features

### Components

1. Define the component class with `@component` annotation
2. Run `melos build_runner` to generate code
3. Add tests
4. Document the component

### Systems

Use one of these patterns:
- `FunctionSystem` for simple systems
- `@system` annotation for generated wrappers
- Class implementing `System` for complex cases

### Plugins

1. Create a class implementing the plugin pattern
2. Register systems in the appropriate stages
3. Add resources the plugin provides
4. Document usage in the package README

## Documentation

### User-Facing Documentation

Add documentation to the docs app, not CLAUDE.md:
- Location: `docs/assets/docs/{section}/{page}.md`
- Format: Markdown files
- Update navigation in `docs/lib/app/router.dart`

### API Documentation

- Use `///` doc comments on all public APIs
- Include examples where helpful
- Run `dart doc` to verify documentation builds

## Releasing

Releases are handled automatically via GitHub Actions when a version tag is pushed. Only maintainers can create releases.

## Getting Help

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check existing issues before creating new ones

## License

By contributing to Fledge, you agree that your contributions will be licensed under the same license as the project.
