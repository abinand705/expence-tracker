import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_login_screen.dart';

void main() {
  runApp(const MoneyTrackApp());
}

class MoneyTrackApp extends StatelessWidget {
  const MoneyTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyTrack',
      theme: AppTheme.lightTheme,
      home: const SplashLoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
