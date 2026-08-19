import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_distribution/firebase_app_distribution.dart' as fad;
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateCheckStatus {
  updateAvailable,
  upToDate,
  networkError,
  notAuthorized,
  configurationError,
  unknownError,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppDistributionRelease? release;
  final String? errorMessage;

  UpdateCheckResult({required this.status, this.release, this.errorMessage});
}

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
  Future<UpdateCheckResult> checkForUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return UpdateCheckResult(status: UpdateCheckStatus.unknownError, errorMessage: 'Unsupported platform');
    }

    try {
      developer.log('Firebase App Distribution update check started', name: 'AppUpdateService');
      
      final isTesterSignedIn = await fad.isTesterSignedIn();
      if (!isTesterSignedIn) {
        developer.log('Tester not signed in, prompting sign in...', name: 'AppUpdateService');
        await fad.signInTester();
      }

      final release = await fad.checkForNewRelease();
      developer.log('Firebase App Distribution update check succeeded. Release: ${release?.displayVersion}', name: 'AppUpdateService');
      
      if (release != null) {
        return UpdateCheckResult(status: UpdateCheckStatus.updateAvailable, release: release);
      } else {
        return UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Firebase App Distribution update check failed',
        name: 'AppUpdateService',
        error: e,
        stackTrace: stackTrace,
      );

      var status = UpdateCheckStatus.unknownError;
      String? errorMessage = e.toString();

      if (e is FirebaseException) {
        final code = e.code.toLowerCase();
        final message = e.message?.toLowerCase() ?? '';
        
        if (code.contains('network') || message.contains('network') || message.contains('connect') || message.contains('socket') || code == 'unavailable') {
          status = UpdateCheckStatus.networkError;
        } else if (code.contains('not-authorized') || code.contains('tester') || code.contains('unauthenticated') || message.contains('tester')) {
          status = UpdateCheckStatus.notAuthorized;
        } else if (code.contains('configuration') || code.contains('project') || code.contains('app-id') || code == 'not-found') {
          status = UpdateCheckStatus.configurationError;
        }
      } else {
        final stringError = e.toString().toLowerCase();
        if (stringError.contains('network') || stringError.contains('socket') || stringError.contains('connect')) {
          status = UpdateCheckStatus.networkError;
        } else if (stringError.contains('tester') || stringError.contains('authoriz') || stringError.contains('authenticat')) {
          status = UpdateCheckStatus.notAuthorized;
        } else if (stringError.contains('project') || stringError.contains('config')) {
          status = UpdateCheckStatus.configurationError;
        }
      }

      return UpdateCheckResult(status: status, errorMessage: errorMessage);
    }
  }

  /// Downloads and initiates the installation of the provided release.
  Future<void> performUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await fad.updateApp();
    } catch (e, stackTrace) {
      developer.log(
        'Firebase App Distribution perform update failed',
        name: 'AppUpdateService',
        error: e,
        stackTrace: stackTrace,
      );
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
