import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/core/theme/app_theme.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';
import 'package:flutter_cleanapp/screens/auth_screen.dart';
import 'package:flutter_cleanapp/screens/calendar_screen.dart';
import 'package:flutter_cleanapp/screens/comments_screen.dart';
import 'package:flutter_cleanapp/screens/home_screen.dart';
import 'package:flutter_cleanapp/screens/notifications_screen.dart';
import 'package:flutter_cleanapp/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Root application widget that owns theme state and bottom navigation.
class LimpyApp extends StatefulWidget {
  /// Creates a [LimpyApp].
  const LimpyApp({super.key});

  @override
  State<LimpyApp> createState() => _LimpyAppState();
}

class _LimpyAppState extends State<LimpyApp> {
  static const String _themePrefKey = 'theme_mode';
  AppThemeMode _themeMode = AppThemeMode.system;
  int _currentIndex = 2;

  bool _isAuthenticated = false;
  UserModel? _currentUser;
  bool _isLoadingUser = false;
  bool _pendingPasswordReset = false;
  bool _isUserResponsible = false;

  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  late final StreamSubscription<void> _schedulesRealtimeSub;
  late final StreamSubscription<void> _extensionsRealtimeSub;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _checkAuth();
    RealtimeService.instance.subscribe();
    _schedulesRealtimeSub = RealtimeService.instance.onSchedulesChanged.listen((
      _,
    ) {
      if (mounted) _computeResponsibleStatus();
    });
    _extensionsRealtimeSub = RealtimeService.instance.onExtensionsChanged
        .listen((_) {
          if (mounted) _computeResponsibleStatus();
        });
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // User arrived via password reset link — show dialog immediately.
        // Set the flag in case the user isn't fully loaded yet.
        _pendingPasswordReset = true;
        _loadCurrentUser().then((_) async {
          await _computeResponsibleStatus();
          if (_pendingPasswordReset &&
              _isAuthenticated &&
              _currentUser != null) {
            _showPasswordResetDialog();
          }
        });
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        _loadCurrentUser().then((_) async {
          await _computeResponsibleStatus();
          if (_pendingPasswordReset &&
              _isAuthenticated &&
              _currentUser != null) {
            _showPasswordResetDialog();
          }
        });
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isAuthenticated = false;
          _currentUser = null;
          _currentIndex = 2;
          _isUserResponsible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _schedulesRealtimeSub.cancel();
    _extensionsRealtimeSub.cancel();
    RealtimeService.instance.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null && !session.isExpired) {
      await _loadCurrentUser();
      await _computeResponsibleStatus();
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

  Future<void> _computeResponsibleStatus() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isUserResponsible = false);
      return;
    }
    try {
      final now = DateTime.now();
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      final currentWeekStart = DateTime(
        currentMonday.year,
        currentMonday.month,
        currentMonday.day,
      );
      final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));

      final schedules = await SupabaseService.instance.getSchedules();
      final schedule = schedules.where((s) {
        return s.userId == _currentUser!.id &&
            !s.date.isBefore(currentWeekStart) &&
            s.date.isBefore(currentWeekEnd);
      }).firstOrNull;

      bool isResponsible = schedule != null;

      if (isResponsible) {
        final extensions = await SupabaseService.instance
            .getExtensionRequestsForUser(_currentUser!.id);
        final hasAcceptedProrroga = extensions.any(
          (e) =>
              e.status == ExtensionRequestStatus.accepted &&
              e.requesterId == _currentUser!.id &&
              e.scheduleId == schedule.id,
        );
        if (hasAcceptedProrroga) isResponsible = false;
      }

      if (mounted) setState(() => _isUserResponsible = isResponsible);
    } catch (_) {
      if (mounted) setState(() => _isUserResponsible = false);
    }
  }

  Future<void> _logout() async {
    await SupabaseConfig.client.auth.signOut();
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'limpy' && uri.host == 'reset-callback') {
      _pendingPasswordReset = true;
      if (_isAuthenticated && _currentUser != null) {
        _showPasswordResetDialog();
      }
    }
  }

  Future<void> _showPasswordResetDialog() async {
    _pendingPasswordReset = false;
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: _navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu nueva contraseña para completar el restablecimiento.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newPassword = newPasswordController.text;
      final confirmPassword = confirmPasswordController.text;

      if (newPassword.length < 6) {
        if (mounted) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('La contraseña debe tener al menos 6 caracteres'),
            ),
          );
        }
      } else if (newPassword != confirmPassword) {
        if (mounted) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('Las contraseñas no coinciden')),
          );
        }
      } else {
        try {
          await SupabaseConfig.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          if (mounted) {
            ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text('Contraseña actualizada exitosamente'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              _navigatorKey.currentContext!,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      }
    }

    newPasswordController.dispose();
    confirmPasswordController.dispose();
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
    CalendarScreen(currentUser: _currentUser!),
    ActivitiesScreen(
      currentUser: _currentUser!,
      isResponsible: _isUserResponsible,
    ),
    HomeScreen(
      currentUser: _currentUser!,
      onNavigateToActivities: () => setState(() => _currentIndex = 1),
    ),
    CommentsScreen(
      currentUser: _currentUser!,
      isResponsible: _isUserResponsible,
    ),
    SettingsScreen(
      currentUser: _currentUser!,
      onProfileChanged: _loadCurrentUser,
      themeModeIcon: _themeModeIcon,
      onToggleTheme: _toggleTheme,
      onSendFeedback: _showFeedbackDialog,
      onLogout: _logout,
    ),
  ];

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    if (savedTheme != null && mounted) {
      setState(() {
        _themeMode = switch (savedTheme) {
          'light' => AppThemeMode.light,
          'dark' => AppThemeMode.dark,
          _ => AppThemeMode.system,
        };
      });
    }
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, _themeMode.name);
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        AppThemeMode.system => AppThemeMode.light,
        AppThemeMode.light => AppThemeMode.dark,
        AppThemeMode.dark => AppThemeMode.system,
      };
    });
    _saveThemePreference();
  }

  ThemeMode get _resolvedThemeMode => switch (_themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  String get _currentTitle => switch (_currentIndex) {
    0 => 'Calendario',
    1 => 'Actividades',
    2 => 'Limpy',
    3 => 'Comentarios',
    4 => 'Configuración',
    _ => 'Limpy',
  };

  IconData get _themeModeIcon => switch (_themeMode) {
    AppThemeMode.system => CupertinoIcons.circle_lefthalf_fill,
    AppThemeMode.light => CupertinoIcons.sun_max_fill,
    AppThemeMode.dark => CupertinoIcons.moon_fill,
  };

  Widget _buildRetryScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 64,
                color: Colors.red,
              ),
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

  Widget _buildMainShell(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.black,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
            ),
      child: Scaffold(
        appBar: CupertinoNavigationBar(
          middle: Text(_currentTitle),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.bell),
            onPressed: () {
              _navigatorKey.currentState?.push(
                CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF000000)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          border: null,
          transitionBetweenRoutes: false,
        ),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: Theme.of(context).brightness == Brightness.dark
                  ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                  : ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: CupertinoTabBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                activeColor: CupertinoColors.activeBlue,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.7),
                inactiveColor: Theme.of(context).brightness == Brightness.dark
                    ? CupertinoColors.systemGrey
                    : CupertinoColors.inactiveGray,
                border: Theme.of(context).brightness == Brightness.dark
                    ? const Border()
                    : null,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.calendar),
                    activeIcon: Icon(CupertinoIcons.calendar_today),
                    label: 'Calendario',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.checkmark_square),
                    activeIcon: Icon(CupertinoIcons.checkmark_square_fill),
                    label: 'Actividades',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.house),
                    activeIcon: Icon(CupertinoIcons.house_fill),
                    label: 'Inicio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.chat_bubble_2),
                    activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
                    label: 'Comentarios',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.gear),
                    activeIcon: Icon(CupertinoIcons.gear_solid),
                    label: 'Configuración',
                  ),
                ],
              ),
            ),
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
          ? Builder(builder: (innerContext) => _buildMainShell(innerContext))
          : !_isAuthenticated &&
                SupabaseConfig.client.auth.currentSession != null &&
                !(SupabaseConfig.client.auth.currentSession!.isExpired)
          ? _buildRetryScreen()
          : const AuthScreen(),
    );
  }
}
