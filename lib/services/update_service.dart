import 'dart:convert';
import 'dart:io';
import '../data/repositories/financial_repository.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? releaseUrl;
  final String? apkDownloadUrl;
  final DateTime? publishedAt;
  final String? errorMessage;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    this.releaseTitle,
    this.releaseNotes,
    this.releaseUrl,
    this.apkDownloadUrl,
    this.publishedAt,
    this.errorMessage,
  });

  factory AppUpdateInfo.noUpdate(String currentVersion) {
    return AppUpdateInfo(
      hasUpdate: false,
      latestVersion: currentVersion,
      currentVersion: currentVersion,
    );
  }

  factory AppUpdateInfo.error({required String currentVersion, required String message}) {
    return AppUpdateInfo(
      hasUpdate: false,
      latestVersion: currentVersion,
      currentVersion: currentVersion,
      errorMessage: message,
    );
  }
}

class UpdateService {
  static const currentVersion = '1.1.6';
  static const repoOwner = 'LuGoAn';
  static const repoName = 'chokin';

  final FinancialRepository repository;

  UpdateService({FinancialRepository? repository}) : repository = repository ?? FinancialRepository();

  static bool isVersionNewer(String latest, String current) {
    final cleanLatest = latest.replaceAll(RegExp(r'^[vV]'), '').trim();
    final cleanCurrent = current.replaceAll(RegExp(r'^[vV]'), '').trim();

    final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }

  Future<String?> getEffectiveToken() async {
    final stored = await repository.getSetting('github_token');
    return (stored != null && stored.trim().isNotEmpty) ? stored.trim() : null;
  }

  Future<void> saveGithubToken(String token) async {
    await repository.setSetting('github_token', token.trim());
  }

  Future<AppUpdateInfo> checkForUpdates({String? customToken}) async {
    final token = customToken ?? await getEffectiveToken();
    if (token == null || token.isEmpty) {
      return AppUpdateInfo.error(
        currentVersion: currentVersion,
        message: 'Informe um token do GitHub em Ajustes › Token do GitHub para procurar atualizações.',
      );
    }

    final uri = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'ChokinApp/$currentVersion');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      request.headers.set('Authorization', 'Bearer $token');

      final response = await request.close();

      await repository.setSetting('last_update_check', DateTime.now().toIso8601String());

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody) as Map<String, dynamic>;

        final rawTagName = data['tag_name'] as String? ?? '';
        final latestVer = rawTagName.replaceAll(RegExp(r'^[vV]'), '').trim();
        final title = data['name'] as String? ?? rawTagName;
        final notes = data['body'] as String? ?? '';
        final releaseUrl = data['html_url'] as String?;
        final publishedAtStr = data['published_at'] as String?;
        final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

        String? apkDownloadUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            if (asset is Map) {
              final name = asset['name'] as String? ?? '';
              if (name.toLowerCase() == 'chokin.apk') {
                apkDownloadUrl = asset['browser_download_url'] as String?;
                break;
              } else if (name.toLowerCase().endsWith('.apk') && apkDownloadUrl == null) {
                apkDownloadUrl = asset['browser_download_url'] as String?;
              }
            }
          }
        }

        final hasNewer = isVersionNewer(latestVer, currentVersion);

        return AppUpdateInfo(
          hasUpdate: hasNewer,
          latestVersion: latestVer,
          currentVersion: currentVersion,
          releaseTitle: title,
          releaseNotes: notes,
          releaseUrl: releaseUrl,
          apkDownloadUrl: apkDownloadUrl ?? releaseUrl,
          publishedAt: publishedAt,
        );
      } else if (response.statusCode == 404) {
        return AppUpdateInfo.noUpdate(currentVersion);
      } else {
        return AppUpdateInfo.error(
          currentVersion: currentVersion,
          message: 'Status HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return AppUpdateInfo.error(
        currentVersion: currentVersion,
        message: e.toString(),
      );
    } finally {
      client?.close();
    }
  }
}
