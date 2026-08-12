import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.successGreen,
        onSecondary: AppColors.onSecondary,
        error: AppColors.errorRed,
        onError: AppColors.onError,
        surface: AppColors.background,
        onSurface: AppColors.onBackground,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.getTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
