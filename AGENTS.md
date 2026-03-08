# Agent Instructions

## Project Overview

Flutter application (`flutter_cleanapp`) targeting Android, iOS, Linux, macOS, Web, and Windows.

- **Dart SDK**: ^3.11.1
- **Flutter SDK**: 3.41.4 (stable channel)
- **Linting**: `flutter_lints` 6.0.0 (includes `lints/recommended.yaml` and `lints/core.yaml`)
- **Package ID**: `com.example.flutter_cleanapp`

## Issue Tracking (Beads)

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Build / Run / Test Commands

```bash
# Get dependencies (run after cloning or changing pubspec.yaml)
flutter pub get

# Run the app (debug mode)
flutter run

# Build
flutter build apk          # Android APK
flutter build linux         # Linux desktop
flutter build web           # Web

# Static analysis (linting) — MUST pass before committing
flutter analyze

# Format code — MUST pass before committing
dart format .                         # Format all files in-place
dart format --set-exit-if-changed .   # Check formatting (CI mode, no writes)
dart format lib/some_file.dart        # Format a single file

# Run ALL tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run a single test by name
flutter test --name "some test description"

# Run tests with coverage
flutter test --coverage

# Code generation (if using build_runner in the future)
dart run build_runner build --delete-conflicting-outputs
```

### Quality Gate (run before every commit)

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

## Project Structure

```
lib/                  # Application source code
  main.dart           # Entry point — runApp(const MainApp())
test/                 # Test files (mirror lib/ structure)
android/              # Android platform code
ios/                  # iOS platform code
linux/                # Linux platform code
macos/                # macOS platform code
web/                  # Web platform code
windows/              # Windows platform code
.beads/               # Issue tracking data (bd/beads)
analysis_options.yaml # Lint configuration
pubspec.yaml          # Dependencies and project metadata
```

## Code Style Guidelines

### Formatting

- **Use `dart format`** — the canonical Dart formatter. Do NOT manually adjust formatting.
- Default line length is 80 characters (Dart formatter default).
- Trailing commas on argument lists to get one-argument-per-line formatting.

### Naming Conventions

| Kind | Convention | Example |
|------|-----------|---------|
| Classes, enums, typedefs, extensions | `UpperCamelCase` | `MainApp`, `UserProfile` |
| Variables, parameters, functions, methods | `lowerCamelCase` | `userName`, `fetchData()` |
| Constants | `lowerCamelCase` | `defaultPadding`, `maxRetries` |
| Libraries, packages, directories, files | `snake_case` | `user_profile.dart` |
| Private members | prefix with `_` | `_internalState` |

### Imports

- Use **package imports** for files within `lib/`: `import 'package:flutter_cleanapp/...';`
- **Never** use relative imports (`../`) for library code. Enforced by `avoid_relative_lib_imports`.
- Order imports: dart core → dart libraries → package imports → relative imports, separated by blank lines.
- Remove unused imports (enforced by analyzer).

### Types and Null Safety

- This project uses **sound null safety**. All types are non-nullable by default.
- Use `?` suffix for nullable types: `String?`, `int?`.
- Prefer explicit types for public APIs; `var`/`final` are fine for local variables.
- Use `final` for variables that are never reassigned. Enforced by `prefer_final_fields`.
- Prefer `const` constructors where possible. Enforced by `prefer_const_constructors_in_immutables`.

### Widget Conventions

- Use `const` constructors for stateless widgets: `const MainApp({super.key})`.
- Use `super.key` parameter syntax (not `Key? key`). Enforced by `use_super_parameters`.
- Use `@override` annotation on all overridden methods. Enforced by `annotate_overrides`.
- Place `child`/`children` parameter last. Enforced by `sort_child_properties_last`.
- Use `SizedBox` instead of `Container` when only specifying size. Enforced by `sized_box_for_whitespace`.
- No logic in `createState()`. Enforced by `no_logic_in_create_state`.
- Check `mounted` before using `BuildContext` after async gaps. Enforced by `use_build_context_synchronously`.

### Error Handling

- Never use empty catch blocks. Enforced by `empty_catches`.
- Use `rethrow` instead of `throw e`. Enforced by `use_rethrow_when_possible`.
- Avoid `print()` — use `debugPrint()` or a logging framework. Enforced by `avoid_print`.

### Documentation

- Use `///` (triple-slash) for doc comments, not `/* */`. Enforced by `slash_for_doc_comments`.
- Document all public APIs with `///` doc comments.

### Key Lint Rules (Active)

The project uses `package:flutter_lints/flutter.yaml` which includes 80+ rules. Key ones:

- `avoid_print` — use `debugPrint()` instead
- `prefer_final_fields` — use `final` for fields not reassigned
- `use_super_parameters` — use `super.key` not `Key? key`
- `sort_child_properties_last` — `child:` goes last in widget constructors
- `avoid_unnecessary_containers` — don't wrap in `Container` needlessly
- `curly_braces_in_flow_control_structures` — always use `{}` in if/for/while
- `prefer_const_constructors_in_immutables` — mark immutable constructors `const`
- `strict_top_level_inference` — top-level declarations need explicit types

### Adding Dependencies

```bash
flutter pub add <package_name>          # Add to dependencies
flutter pub add --dev <package_name>    # Add to dev_dependencies
```

Always run `flutter pub get` after editing `pubspec.yaml`.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** — Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed):
   ```bash
   dart format --set-exit-if-changed . && flutter analyze && flutter test
   ```
3. **Update issue status** — Close finished work, update in-progress items
4. **PUSH TO REMOTE** — This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** — Clear stashes, prune remote branches
6. **Verify** — All changes committed AND pushed
7. **Hand off** — Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing — that leaves work stranded locally
- NEVER say "ready to push when you are" — YOU must push
- If push fails, resolve and retry until it succeeds
