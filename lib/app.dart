import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/theme/app_theme.dart';

/// Root application widget that owns theme state and bottom navigation.
class CleanApp extends StatefulWidget {
  /// Creates a [CleanApp].
  const CleanApp({super.key});

  @override
  State<CleanApp> createState() => _CleanAppState();
}

class _CleanAppState extends State<CleanApp> {
  AppThemeMode _themeMode = AppThemeMode.system;
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    Center(child: Text('Inicio')),
    Center(child: Text('Actividades')),
    Center(child: Text('Calendario')),
  ];

  void _toggleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        AppThemeMode.system => AppThemeMode.light,
        AppThemeMode.light => AppThemeMode.dark,
        AppThemeMode.dark => AppThemeMode.system,
      };
    });
  }

  ThemeMode get _resolvedThemeMode => switch (_themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  IconData get _themeModeIcon => switch (_themeMode) {
    AppThemeMode.system => Icons.brightness_auto,
    AppThemeMode.light => Icons.light_mode,
    AppThemeMode.dark => Icons.dark_mode,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolvedThemeMode,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CleanApp'),
          actions: [
            IconButton(
              icon: Icon(_themeModeIcon),
              onPressed: _toggleTheme,
              tooltip: 'Cambiar tema',
            ),
          ],
        ),
        body: _screens[_currentIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Actividades',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendario',
            ),
          ],
        ),
      ),
    );
  }
}
