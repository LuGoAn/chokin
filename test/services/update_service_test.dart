import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chokin/services/update_service.dart';

void main() {
  group('UpdateService Tests', () {
    test('isVersionNewer correctly compares semver versions', () {
      expect(UpdateService.isVersionNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isVersionNewer('1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isVersionNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isVersionNewer('v1.0.5', '1.0.0'), isTrue);
      expect(UpdateService.isVersionNewer('V1.2.0', '1.1.9'), isTrue);

      expect(UpdateService.isVersionNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isVersionNewer('1.0.0', '1.0.1'), isFalse);
      expect(UpdateService.isVersionNewer('0.9.9', '1.0.0'), isFalse);
      expect(UpdateService.isVersionNewer('v1.0.0', '1.0.0'), isFalse);
    });

    test('Default configuration points to LuGoAn/chokin', () {
      expect(UpdateService.repoOwner, equals('LuGoAn'));
      expect(UpdateService.repoName, equals('chokin'));
      expect(UpdateService.currentVersion, equals('1.1.6'));
    });

    test('AppUpdateInfo factory constructors work as expected', () {
      final noUpdate = AppUpdateInfo.noUpdate('1.0.0');
      expect(noUpdate.hasUpdate, isFalse);
      expect(noUpdate.latestVersion, equals('1.0.0'));
      expect(noUpdate.errorMessage, isNull);

      final error = AppUpdateInfo.error(currentVersion: '1.0.0', message: 'Network error');
      expect(error.hasUpdate, isFalse);
      expect(error.errorMessage, equals('Network error'));
    });
    test('Nenhum token do GitHub fica escrito no código', () {
      final tokenPattern = RegExp(r'(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})');
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        expect(tokenPattern.hasMatch(file.readAsStringSync()), isFalse, reason: file.path);
      }
    });
  });
}
