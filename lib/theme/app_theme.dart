import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  String get themeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void setThemeByName(String name) {
    if (name == 'Dark') {
      setThemeMode(ThemeMode.dark);
    } else if (name == 'System') {
      setThemeMode(ThemeMode.system);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      cardColor: Colors.white,
      canvasColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A3026),
        primary: const Color(0xFF0A3026),
        surface: Colors.white,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark slate 900
      cardColor: const Color(0xFF1E293B), // Dark slate 800
      canvasColor: const Color(0xFF1E293B),
      dividerColor: const Color(0xFF334155),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E293B),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF34D399),
        primary: const Color(0xFF34D399),
        surface: const Color(0xFF1E293B),
        brightness: Brightness.dark,
      ),
    );
  }
}
