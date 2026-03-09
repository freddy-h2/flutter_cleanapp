import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/core/theme/app_theme.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';
import 'package:flutter_cleanapp/screens/admin/feedback_screen.dart';
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

  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    RealtimeService.instance.subscribe();
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
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

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'limpy' && uri.host == 'reset-callback') {
      if (_isAuthenticated && _currentUser != null) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(currentUser: _currentUser!),
          ),
        );
      }
    }
  }

  /// Shows a dialog for sending anonymous app feedback.
  Future<void> _showFeedbackDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Comentario sobre la App'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Escribe tu comentario anónimo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await SupabaseService.instance.sendFeedback(controller.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('Comentario enviado. ¡Gracias!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            _navigatorKey.currentContext!,
          ).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
        }
      }
    }
    controller.dispose();
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
            onSelected: (value) {
              switch (value) {
                case 'theme':
                  _toggleTheme();
                case 'profile':
                  _navigatorKey.currentState
                      ?.push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(currentUser: _currentUser!),
                        ),
                      )
                      .then((changed) {
                        if (changed == true && mounted) _loadCurrentUser();
                      });
                case 'feedback':
                  _showFeedbackDialog();
                case 'admin_feedback':
                  _navigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  );
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
              PopupMenuItem(
                value: 'profile',
                child: const Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Administrar perfil'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: const Row(
                  children: [
                    Icon(Icons.feedback_outlined),
                    SizedBox(width: 12),
                    Text('Comentario sobre la App'),
                  ],
                ),
              ),
              if (_currentUser?.isAdmin == true)
                PopupMenuItem(
                  value: 'admin_feedback',
                  child: const Row(
                    children: [
                      Icon(Icons.campaign_outlined),
                      SizedBox(width: 12),
                      Text('Gestionar Comunicados'),
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
      navigatorKey: _navigatorKey,
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
