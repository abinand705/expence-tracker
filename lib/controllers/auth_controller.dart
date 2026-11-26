import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firestore_service.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final FirestoreService _firestoreService;
  StreamSubscription<User?>? _authSubscription;

  User? _currentUser;
  bool _isGuest = false;

  // Fallback in-memory state for testing / offline environments
  bool _fallbackIsLoggedIn = false;
  String? _fallbackUserId;
  String? _fallbackUserName;
  String? _fallbackUserEmail;

  AuthController({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    bool initialLoggedIn = false,
    String? initialName,
    String? initialEmail,
  })  : _auth = auth ?? _resolveAuth(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _fallbackIsLoggedIn = initialLoggedIn,
        _fallbackUserName = initialName,
        _fallbackUserEmail = initialEmail {
    _initAuthListener();
  }

  FirestoreService get firestoreService => _firestoreService;

  static FirebaseAuth? _resolveAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth not available in current environment: $e');
      return null;
    }
  }

  void _initAuthListener() {
    if (_auth != null) {
      _currentUser = _auth.currentUser;
      _authSubscription = _auth.authStateChanges().listen((user) {
        _currentUser = user;
        if (user != null) {
          _isGuest = user.isAnonymous;
        }
        notifyListeners();
      });
    }
  }

  bool get isLoggedIn =>
      (_currentUser != null && !_currentUser!.isAnonymous) ||
      _fallbackIsLoggedIn;

  bool get isGuest => (_currentUser != null && _currentUser!.isAnonymous) || _isGuest;

  String get userId {
    if (_currentUser != null) return _currentUser!.uid;
    return _fallbackUserId ?? 'guest_user';
  }

  String? get userName {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName;
    }
    if (_currentUser?.email != null) {
      return _extractNameFromEmail(_currentUser!.email!);
    }
    return _fallbackUserName;
  }

  String? get userEmail => _currentUser?.email ?? _fallbackUserEmail;

  Future<String?> login({
    required String email,
    required String password,
    String? name,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (_auth == null) {
      _fallbackIsLoggedIn = true;
      _fallbackUserEmail = cleanEmail;
      _fallbackUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _fallbackUserName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : _extractNameFromEmail(cleanEmail);
      _isGuest = false;
      await _firestoreService.saveUserData(
        userId: _fallbackUserId!,
        username: _fallbackUserName!,
        emailId: _fallbackUserEmail!,
      );
      notifyListeners();
      return null;
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      _currentUser = cred.user;
      _isGuest = false;

      final uid = _currentUser?.uid ?? cred.user?.uid ?? '';
      if (uid.isNotEmpty) {
        final existing = await _firestoreService.getUserData(uid);
        if (existing == null) {
          final displayName = _currentUser?.displayName ??
              (name != null && name.trim().isNotEmpty
                  ? name.trim()
                  : _extractNameFromEmail(cleanEmail));
          await _firestoreService.saveUserData(
            userId: uid,
            username: displayName,
            emailId: cleanEmail,
          );
        }
        await _firestoreService.seedPredefinedCategories();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Login Error: ${e.code} - ${e.message}');
      return _getReadableErrorMessage(e);
    } catch (e) {
      return 'Login failed. Please check your network and credentials.';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (_auth == null) {
      _fallbackIsLoggedIn = true;
      _fallbackUserId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _fallbackUserName = cleanName;
      _fallbackUserEmail = cleanEmail;
      _isGuest = false;
      await _firestoreService.saveUserData(
        userId: _fallbackUserId!,
        username: cleanName,
        emailId: cleanEmail,
      );
      await _firestoreService.seedPredefinedCategories();
      notifyListeners();
      return null;
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      await cred.user?.updateDisplayName(cleanName);
      await cred.user?.reload();
      _currentUser = _auth.currentUser;
      _isGuest = false;

      final uid = _currentUser?.uid ?? cred.user?.uid ?? '';
      if (uid.isNotEmpty) {
        await _firestoreService.saveUserData(
          userId: uid,
          username: cleanName,
          emailId: cleanEmail,
        );
        await _firestoreService.seedPredefinedCategories();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Register Error: ${e.code} - ${e.message}');
      return _getReadableErrorMessage(e);
    } catch (e) {
      return 'Registration failed. Please try again.';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (_auth == null) {
      _fallbackIsLoggedIn = true;
      _fallbackUserId = 'google_${DateTime.now().millisecondsSinceEpoch}';
      _fallbackUserName = 'Google User';
      _fallbackUserEmail = 'user@gmail.com';
      _isGuest = false;
      await _firestoreService.saveUserData(
        userId: _fallbackUserId!,
        username: _fallbackUserName!,
        emailId: _fallbackUserEmail!,
      );
      await _firestoreService.seedPredefinedCategories();
      notifyListeners();
      return null;
    }

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        final account = await googleSignIn.authenticate();
        final auth = account.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: auth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      _currentUser = userCredential.user;
      _isGuest = false;

      final uid = _currentUser?.uid ?? '';
      final name = _currentUser?.displayName ??
          (_currentUser?.email != null
              ? _extractNameFromEmail(_currentUser!.email!)
              : 'Google User');
      final email = _currentUser?.email ?? '';

      if (uid.isNotEmpty) {
        await _firestoreService.saveUserData(
          userId: uid,
          username: name,
          emailId: email,
        );
        await _firestoreService.seedPredefinedCategories();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Google Sign-In Error: ${e.code} - ${e.message}');
      return _getReadableErrorMessage(e);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      return 'Google Sign-In failed. Please try again.';
    }
  }

  Future<void> continueAsGuest() async {
    if (_auth != null) {
      try {
        final cred = await _auth.signInAnonymously();
        _currentUser = cred.user;
        _isGuest = true;
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Anonymous sign-in error: $e');
      }
    }
    _isGuest = true;
    _fallbackUserId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _fallbackUserName = 'Guest User';
    notifyListeners();
  }

  Future<void> logout() async {
    if (_auth != null) {
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('Firebase SignOut Error: $e');
      }
    }
    _currentUser = null;
    _isGuest = false;
    _fallbackIsLoggedIn = false;
    _fallbackUserId = null;
    _fallbackUserName = null;
    _fallbackUserEmail = null;
    notifyListeners();
  }

  String _extractNameFromEmail(String email) {
    final prefix = email.split('@').first;
    if (prefix.isEmpty) return 'MoneyTrack User';
    return prefix[0].toUpperCase() + prefix.substring(1);
  }

  String _getReadableErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please check and try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection error. Please verify your internet connection.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
