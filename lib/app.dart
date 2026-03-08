import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/core/theme/app_theme.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';
import 'package:flutter_cleanapp/screens/auth_screen.dart';
import 'package:flutter_cleanapp/screens/calendar_screen.dart';
import 'package:flutter_cleanapp/screens/comments_screen.dart';
import 'package:flutter_cleanapp/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _isAuthenticated = false;
  UserModel? _currentUser;
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        _loadCurrentUser();
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isAuthenticated = false;
          _currentUser = null;
          _currentIndex = 0;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      await _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoadingUser = true);
    try {
      final user = await SupabaseService.instance.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isAuthenticated = user != null;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _logout() async {
    await SupabaseConfig.client.auth.signOut();
  }

  List<Widget> get _screens => [
    HomeScreen(
      currentUser: _currentUser!,
      onNavigateToActivities: () => setState(() => _currentIndex = 1),
    ),
    ActivitiesScreen(currentUser: _currentUser!),
    CalendarScreen(currentUser: _currentUser!),
    CommentsScreen(currentUser: _currentUser!),
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

  Widget _buildMainShell() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CleanApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
          IconButton(
            icon: Icon(_themeModeIcon),
            onPressed: _toggleTheme,
            tooltip: 'Cambiar tema',
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
          NavigationDestination(
            icon: Icon(Icons.comment_outlined),
            selectedIcon: Icon(Icons.comment),
            label: 'Comentarios',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolvedThemeMode,
      home: _isLoadingUser
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated && _currentUser != null
          ? _buildMainShell()
          : const AuthScreen(),
    );
  }
}
