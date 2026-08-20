import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class PublicUpdateRelease {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  PublicUpdateRelease({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory PublicUpdateRelease.fromJson(Map<String, dynamic> json) {
    return PublicUpdateRelease(
      version: json['version'] as String,
      buildNumber: json['buildNumber'] as int,
      apkUrl: json['apkUrl'] as String,
      releaseNotes: json['releaseNotes'] as String? ?? 'Bug fixes and improvements',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}

class PublicUpdateProvider {
  final String metadataUrl;

  PublicUpdateProvider({required this.metadataUrl});

  Future<PublicUpdateRelease?> checkUpdate() async {
    try {
      if (!metadataUrl.startsWith('https://')) {
        throw Exception('Insecure update URL. Must use HTTPS.');
      }

      final response = await http.get(Uri.parse(metadataUrl)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestRelease = PublicUpdateRelease.fromJson(json);
        
        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
        
        if (latestRelease.buildNumber > currentBuildNumber) {
          return latestRelease;
        } else {
          return null; // Up to date
        }
      } else {
        throw Exception('Failed to fetch update metadata. Status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
