import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Comprobación e instalación de actualizaciones desde GitHub Releases.
class UpdateService {
  // Repositorio donde se publican las releases.
  static const _owner = 'nimbo-dev';
  static const _repo = 'tessera';
  static const _latestUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Devuelve la info de actualización si hay una versión más nueva publicada;
  /// `null` si estás al día o no se pudo comprobar.
  static Future<UpdateInfo?> checkForUpdate() async {
    final resp = await http.get(
      Uri.parse(_latestUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;

    final info = await PackageInfo.fromPlatform();
    if (!_isNewer(_parse(tag), _parse(info.version))) return null;

    // Localizar el APK adjunto a la release.
    final assets = (data['assets'] as List<dynamic>?) ?? const [];
    String? apkUrl;
    for (final a in assets) {
      final name = (a['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null) return null;

    return UpdateInfo(
      version: tag.replaceFirst('v', ''),
      apkUrl: apkUrl,
      notes: (data['body'] as String?)?.trim() ?? '',
    );
  }

  /// Descarga el APK (reporta progreso 0..1) y lanza el instalador de Android.
  static Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/tessera-update.apk');

    final resp = await http.Client().send(http.Request('GET', Uri.parse(url)));
    final total = resp.contentLength ?? 0;
    final sink = file.openWrite();
    int received = 0;
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();

    await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
  }

  // ── Comparación de versiones (semver simple: major.minor.patch) ──────────
  static List<int> _parse(String v) {
    final clean = v.replaceFirst('v', '').split('+').first.split('-').first;
    return clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  static bool _isNewer(List<int> a, List<int> b) {
    final n = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

class UpdateInfo {
  final String version; // p. ej. "0.2.0"
  final String apkUrl;
  final String notes;
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });
}
