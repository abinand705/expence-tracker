import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'services/firestore_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(const MoneyTrackApp());
}

class MoneyTrackApp extends StatefulWidget {
  final ThemeController? themeController;
  final AuthController? authController;
  final FirestoreService? firestoreService;

  const MoneyTrackApp({
    super.key,
    this.themeController,
    this.authController,
    this.firestoreService,
  });

  @override
  State<MoneyTrackApp> createState() => _MoneyTrackAppState();
}

class _MoneyTrackAppState extends State<MoneyTrackApp> {
  late final ThemeController _themeController;
  late final AuthController _authController;
  late final FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _authController = widget.authController ??
        AuthController(firestoreService: _firestoreService);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeController, _authController]),
      builder: (context, _) {
        final isDark = _themeController.themeMode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'MoneyTrack',
          debugShowCheckedModeBanner: false,
          themeMode: _themeController.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: MainNavigationScreen(
            themeController: _themeController,
            authController: _authController,
            firestoreService: _firestoreService,
          ),
        );
      },
    );
  }
}
