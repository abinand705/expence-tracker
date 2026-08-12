import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayCurrency => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.02,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineLg => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineMd => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.onSurface,
  );

  static TextStyle get labelCaps => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.05,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle get labelMuted => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    color: AppColors.outline,
  );
  
  static TextTheme getTextTheme() {
    return TextTheme(
      displayLarge: displayCurrency,
      headlineLarge: headlineLg,
      headlineMedium: headlineMd,
      bodyLarge: bodyLg,
      bodyMedium: bodyMd,
      labelLarge: labelCaps,
      labelSmall: labelMuted,
    );
  }
}
