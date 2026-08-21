import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/theme/theme_controller.dart';

void main() {
  group('ThemeController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to ThemeMode.system before load()', () {
      final controller = ThemeController();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('load() restores light mode from prefs', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'light'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.themeMode, ThemeMode.light);
    });

    test('load() restores dark mode from prefs', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.themeMode, ThemeMode.dark);
    });

    test('load() falls back to system for unknown pref value', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'unknown'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('setThemeMode() updates mode and notifies listeners', () async {
      final controller = ThemeController();
      bool notified = false;
      controller.addListener(() => notified = true);
      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notified, isTrue);
    });

    test('setThemeMode() persists to SharedPreferences', () async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'light');
    });

    test('setThemeMode() does not notify if mode unchanged', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final controller = ThemeController();
      await controller.load();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      await controller.setThemeMode(ThemeMode.dark);
      expect(notifyCount, 0);
    });

    test('themeModeLabel returns correct strings', () async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeModeLabel, 'System Default');
      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeModeLabel, 'Light');
      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeModeLabel, 'Dark');
    });
  });
}
