import 'package:flutter/material.dart';

/// Enum representing the available theme modes for the app.
enum AppThemeMode { light, dark, system }

/// Provides the light and dark [ThemeData] configurations for the app.
///
/// Uses Material Design 3 with a blue color palette derived from [seedColor].
abstract final class AppTheme {
  /// The seed color used to generate the app's color schemes.
  static const Color seedColor = Color(0xFF1565C0); // Blue 800

  /// Light theme configuration.
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ).primary,
      unselectedItemColor: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ).onSurfaceVariant,
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  /// Dark theme configuration.
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Roboto',
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).primary,
      unselectedItemColor: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).onSurfaceVariant,
    ),
    cardTheme: const CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
