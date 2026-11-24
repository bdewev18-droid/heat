import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/heat_theme.dart';
import 'app_update_page.dart';

const String appVersionLabel = '1.4.0';
const int appBuildNumber = 5;

class RemoteAppVersion {
  const RemoteAppVersion({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    this.releaseNotes,
  });

  final String version;
  final int buildNumber;
  final String apkUrl;
  final String? releaseNotes;

  factory RemoteAppVersion.fromJson(Map<String, dynamic> json) {
    return RemoteAppVersion(
      version: (json['version'] as String?)?.trim() ?? '',
      buildNumber: json['buildNumber'] is int
          ? json['buildNumber'] as int
          : int.tryParse(json['buildNumber']?.toString() ?? '') ?? 0,
      apkUrl: (json['apkUrl'] as String?)?.trim() ?? '',
      releaseNotes: (json['releaseNotes'] as String?)?.trim(),
    );
  }
}

class AppUpdateService {
  AppUpdateService._();

  static const String versionCheckUrl =
      'https://raw.githubusercontent.com/bdewev18-droid/heat/main/version.json';

  /// Vérifie si une mise à jour APK est disponible sur GitHub (Android uniquement).
  static Future<RemoteAppVersion?> checkUpdate() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final uri = Uri.parse(
        '$versionCheckUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = RemoteAppVersion.fromJson(json);

      if (remote.buildNumber > appBuildNumber && remote.apkUrl.isNotEmpty) {
        return remote;
      }
    } catch (_) {
      // Échec silencieux si hors-ligne
    }
    return null;
  }

  /// Affiche la boîte de dialogue de mise à jour (style Heat).
  static Future<void> promptUpdate(
    BuildContext context,
    RemoteAppVersion update, {
    bool isForced = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !isForced,
      builder: (dialogCtx) => PopScope(
        canPop: !isForced,
        child: AlertDialog(
          backgroundColor: HeatColors.paperCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: HeatColors.navyHeader, width: 2),
          ),
          title: const HeatSectionBanner(
            title: 'Mise à jour disponible',
            compact: true,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouvelle version de Heat disponible : v${update.version} (Build ${update.buildNumber}).',
                style: const TextStyle(
                  color: HeatColors.inkDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Version installée : v$appVersionLabel (Build $appBuildNumber).',
                style: TextStyle(color: HeatColors.inkMuted, fontSize: 12),
              ),
              if (update.releaseNotes != null &&
                  update.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HeatColors.paperCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HeatColors.paperBorder),
                  ),
                  child: Text(
                    update.releaseNotes!,
                    style: const TextStyle(
                      color: HeatColors.inkDark,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!isForced)
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Plus tard'),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppUpdatePage(
                      update: update,
                      isForced: isForced,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Télécharger et installer'),
            ),
          ],
        ),
      ),
    );
  }
}
