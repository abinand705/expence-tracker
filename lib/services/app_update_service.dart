import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_app_distribution/firebase_app_distribution.dart' as fad;
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  bool _hasPromptedThisSession = false;

  bool get hasPromptedThisSession => _hasPromptedThisSession;

  void markAsPrompted() {
    _hasPromptedThisSession = true;
  }

  /// Checks if a newer release is available on Firebase App Distribution.
  Future<AppDistributionRelease?> checkForUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }

    try {
      final isTesterSignedIn = await fad.isTesterSignedIn();
      if (!isTesterSignedIn) {
        developer.log('Tester not signed in, prompting sign in...', name: 'AppUpdateService');
        await fad.signInTester();
      }

      final release = await fad.checkForNewRelease();
      return release;
    } catch (e) {
      developer.log('Failed to check for updates: $e', name: 'AppUpdateService');
      // Rethrow to let UI handle it if needed
      rethrow;
    }
  }

  /// Downloads and initiates the installation of the provided release.
  Future<void> performUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await fad.updateApp();
    } catch (e) {
      developer.log('Failed to perform update: $e', name: 'AppUpdateService');
      rethrow;
    }
  }

  /// Stream of download progress for UI rendering.
  Stream<AppDistributionDownloadProgress> get downloadProgress => fad.downloadProgress;

  /// Utility to get current app version info.
  Future<PackageInfo> getAppVersionInfo() async {
    return await PackageInfo.fromPlatform();
  }
}
