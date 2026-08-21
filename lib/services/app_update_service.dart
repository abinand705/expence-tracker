import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_distribution/firebase_app_distribution.dart' as fad;
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';
import 'public_update_provider.dart';

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
  final PublicUpdateRelease? publicRelease;
  final AppDistributionRelease? betaRelease;
  final String? errorMessage;

  UpdateCheckResult({
    required this.status, 
    this.publicRelease, 
    this.betaRelease, 
    this.errorMessage
  });
}

class AppConfig {
  static const String updateMetadataUrl = 'https://moneytrack-demo.web.app/latest.json';
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

  final StreamController<double> _downloadProgressController = StreamController<double>.broadcast();

  /// Checks if a newer release is available publicly.
  Future<UpdateCheckResult> checkForUpdate({bool checkBeta = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return UpdateCheckResult(status: UpdateCheckStatus.unknownError, errorMessage: 'Unsupported platform');
    }

    if (checkBeta) {
      return _checkBetaUpdate();
    }

    try {
      developer.log('Public update check started', name: 'AppUpdateService');
      final provider = PublicUpdateProvider(metadataUrl: AppConfig.updateMetadataUrl);
      final release = await provider.checkUpdate();
      
      if (release != null) {
        return UpdateCheckResult(status: UpdateCheckStatus.updateAvailable, publicRelease: release);
      } else {
        return UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Public update check failed',
        name: 'AppUpdateService',
        error: e,
        stackTrace: stackTrace,
      );

      var status = UpdateCheckStatus.unknownError;
      final stringError = e.toString().toLowerCase();

      if (stringError.contains('network') || 
          stringError.contains('socket') || 
          stringError.contains('connect') || 
          stringError.contains('timeout') ||
          stringError.contains('host lookup') ||
          stringError.contains('clientexception')) {
        status = UpdateCheckStatus.networkError;
      } else if (stringError.contains('format') || stringError.contains('json')) {
        status = UpdateCheckStatus.configurationError;
      }

      return UpdateCheckResult(status: status, errorMessage: e.toString());
    }
  }

  Future<UpdateCheckResult> _checkBetaUpdate() async {
    try {
      final isTesterSignedIn = await fad.isTesterSignedIn();
      if (!isTesterSignedIn) {
        await fad.signInTester();
      }
      final release = await fad.checkForNewRelease();
      if (release != null) {
        return UpdateCheckResult(status: UpdateCheckStatus.updateAvailable, betaRelease: release);
      } else {
        return UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }
    } catch (e) {
      return UpdateCheckResult(status: UpdateCheckStatus.notAuthorized, errorMessage: e.toString());
    }
  }

  /// Downloads and initiates the installation of the provided public release.
  Future<void> performPublicUpdate(PublicUpdateRelease release) async {
    if (!Platform.isAndroid) return;

    try {
      final url = Uri.parse(release.apkUrl);
      final request = http.Request('GET', url);
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download APK. Status: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/moneytrack_update.apk');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          _downloadProgressController.add(downloaded / contentLength);
        }
      }
      await sink.close();
      
      developer.log('APK downloaded to ${file.path}', name: 'AppUpdateService');

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open installer: ${result.message}');
      }
    } catch (e) {
      developer.log('Update installation failed', name: 'AppUpdateService', error: e);
      rethrow;
    }
  }

  Stream<double> get publicDownloadProgress => _downloadProgressController.stream;

  Future<void> performBetaUpdate() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await fad.updateApp();
  }

  Stream<AppDistributionDownloadProgress> get betaDownloadProgress => fad.downloadProgress;

  Future<PackageInfo> getAppVersionInfo() async {
    return await PackageInfo.fromPlatform();
  }
}
