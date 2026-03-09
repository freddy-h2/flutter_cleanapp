import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/core/theme/app_theme.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';
import 'package:flutter_cleanapp/screens/auth_screen.dart';
import 'package:flutter_cleanapp/screens/calendar_screen.dart';
import 'package:flutter_cleanapp/screens/comments_screen.dart';
import 'package:flutter_cleanapp/screens/home_screen.dart';
import 'package:flutter_cleanapp/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root application widget that owns theme state and bottom navigation.
class LimpyApp extends StatefulWidget {
  /// Creates a [LimpyApp].
  const LimpyApp({super.key});

  @override
  State<LimpyApp> createState() => _LimpyAppState();
}

class _LimpyAppState extends State<LimpyApp> {
  AppThemeMode _themeMode = AppThemeMode.system;
  int _currentIndex = 0;

  bool _isAuthenticated = false;
  UserModel? _currentUser;
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    RealtimeService.instance.subscribe();
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
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

  @override
  void dispose() {
    RealtimeService.instance.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null && !session.isExpired) {
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
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoadingUser = false;
        });
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

  Widget _buildRetryScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar perfil. Intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadCurrentUser,
                child: const Text('Reintentar'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _logout,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainShell() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limpy'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menú',
            onSelected: (value) async {
              switch (value) {
                case 'theme':
                  _toggleTheme();
                case 'profile':
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(currentUser: _currentUser!),
                    ),
                  );
                  if (changed == true && mounted) _loadCurrentUser();
                case 'logout':
                  _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(_themeModeIcon),
                    const SizedBox(width: 12),
                    const Text('Cambiar tema'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Administrar perfil'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            height: 70,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Limpy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _resolvedThemeMode,
      home: _isLoadingUser
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated && _currentUser != null
          ? _buildMainShell()
          : !_isAuthenticated &&
                SupabaseConfig.client.auth.currentSession != null &&
                !(SupabaseConfig.client.auth.currentSession!.isExpired)
          ? _buildRetryScreen()
          : const AuthScreen(),
    );
  }
}
