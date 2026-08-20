import 'package:flutter/material.dart';
import 'package:firebase_app_distribution_platform_interface/firebase_app_distribution_platform_interface.dart';
import '../services/app_update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateCheckResult checkResult;
  final PackageInfo currentPackageInfo;

  const UpdateDialog({
    super.key,
    required this.checkResult,
    required this.currentPackageInfo,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final publicRelease = widget.checkResult.publicRelease;
    final betaRelease = widget.checkResult.betaRelease;
    
    final displayVersion = publicRelease?.version ?? betaRelease?.displayVersion ?? 'Unknown';
    final buildVersion = publicRelease?.buildNumber.toString() ?? betaRelease?.buildVersion ?? '';
    final releaseNotes = publicRelease?.releaseNotes ?? betaRelease?.releaseNotes;

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text('New version available', style: AppTypography.headlineMd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MoneyTrack', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text('Current version:\n${widget.currentPackageInfo.version}+${widget.currentPackageInfo.buildNumber}', style: AppTypography.bodyMd),
            const SizedBox(height: AppSpacing.sm),
            Text('New version:\n$displayVersion+$buildVersion', style: AppTypography.bodyMd.copyWith(color: AppColors.primary)),
            if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('What\'s new:', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(releaseNotes, style: AppTypography.bodyMd),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: AppTypography.bodyMd.copyWith(color: AppColors.errorRed)),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Downloading update...', style: AppTypography.bodyMd),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              if (_progress > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${(_progress * 100).toStringAsFixed(0)}%', style: AppTypography.bodyMd),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text('To install this update, Android may ask you to allow MoneyTrack to install unknown apps.', style: AppTypography.bodyMd.copyWith(color: AppColors.outline)),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? [] 
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Later', style: AppTypography.labelCaps.copyWith(color: AppColors.outline)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: _startDownload,
                child: Text('Update Now', style: AppTypography.labelCaps),
              ),
            ],
    );
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });

    final isPublic = widget.checkResult.publicRelease != null;
    final stream = isPublic 
        ? AppUpdateService().publicDownloadProgress 
        : AppUpdateService().betaDownloadProgress.map((p) => p.apkFileTotalBytes > 0 ? (p.apkBytesDownloaded / p.apkFileTotalBytes) : 0.0);

    final sub = stream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    });

    try {
      if (isPublic) {
        await AppUpdateService().performPublicUpdate(widget.checkResult.publicRelease!);
      } else {
        await AppUpdateService().performBetaUpdate();
      }
      
      if (mounted) {
         Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = 'Unable to reach the update server. Please check your internet connection and try again.';
        });
      }
    } finally {
      sub.cancel();
    }
  }
}
