import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

// Checks GitHub Releases for a newer FoodLink APK than the one installed,
// downloads it, and hands it to the OS installer. This exists because the
// app is sideloaded (not distributed via Play Store), so there is no other
// mechanism telling the installed copy that a newer build exists.
class UpdateService {
  static const _repo = 'YOGITH-D/FoodLink';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(_latestReleaseUrl))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String?;
    if (tagName == null) return null;

    final assets = (json['assets'] as List<dynamic>?) ?? [];
    final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
          (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
          orElse: () => const {},
        );
    final downloadUrl = apkAsset['browser_download_url'] as String?;
    if (downloadUrl == null) return null;

    final latestVersion = _parseVersion(tagName);
    final currentVersion = _parseVersion(
      (await PackageInfo.fromPlatform()).version,
    );
    if (latestVersion == null || currentVersion == null) return null;
    if (latestVersion <= currentVersion) return null;

    return UpdateInfo(
      version: latestVersion.toString(),
      downloadUrl: downloadUrl,
      releaseNotes: (json['body'] as String?)?.trim() ?? '',
    );
  }

  Version? _parseVersion(String raw) {
    // Strip a leading 'v' (e.g. "v1.0.3") and any build suffix (e.g. "1.0.3+4").
    final cleaned = raw.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
    try {
      return Version.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  // Downloads the APK to the app's cache dir, reporting progress in [0, 1].
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/foodlink-update.apk';
    final file = File(filePath);

    final client = http.Client();
    try {
      final request = await client.send(http.Request('GET', Uri.parse(url)));
      final total = request.contentLength ?? 0;
      var received = 0;

      final sink = file.openWrite();
      await request.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }).asFuture<void>();
      await sink.close();
    } finally {
      client.close();
    }

    return filePath;
  }

  // Hands the downloaded APK to the Android package installer. The system
  // will prompt the user for the "install unknown apps" permission the
  // first time this is used.
  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath);
  }
}
