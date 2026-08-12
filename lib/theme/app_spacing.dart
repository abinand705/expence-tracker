import 'package:flutter/material.dart';

class AppSpacing {
  static const double base = 4.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  
  static const double containerMargin = 20.0;
  static const double cardGap = 12.0;
}

class AppRadius {
  static const double sm = 4.0;
  static const double base = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}

class AppShadows {
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0D0D3B2E),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
