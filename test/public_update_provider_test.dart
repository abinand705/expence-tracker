import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/public_update_provider.dart';

void main() {
  group('PublicUpdateProvider', () {
    test('parses latest.json correctly', () {
      final jsonMap = {
        'version': '1.0.2',
        'buildNumber': 3,
        'apkUrl': 'https://example.com/app.apk',
        'releaseNotes': 'New features',
        'forceUpdate': true,
      };

      final release = PublicUpdateRelease.fromJson(jsonMap);
      
      expect(release.version, '1.0.2');
      expect(release.buildNumber, 3);
      expect(release.apkUrl, 'https://example.com/app.apk');
      expect(release.releaseNotes, 'New features');
      expect(release.forceUpdate, true);
    });

    test('handles missing optional fields', () {
      final jsonMap = {
        'version': '1.0.2',
        'buildNumber': 3,
        'apkUrl': 'https://example.com/app.apk',
      };

      final release = PublicUpdateRelease.fromJson(jsonMap);
      
      expect(release.version, '1.0.2');
      expect(release.buildNumber, 3);
      expect(release.apkUrl, 'https://example.com/app.apk');
      expect(release.releaseNotes, 'Bug fixes and improvements');
      expect(release.forceUpdate, false);
    });
  });
}
