import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/heat_theme.dart';
import 'app_update_service.dart';

enum UpdateDownloadStatus { idle, downloading, completed, failed }

class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({
    super.key,
    required this.update,
    this.isForced = false,
  });

  final RemoteAppVersion update;
  final bool isForced;

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  UpdateDownloadStatus _status = UpdateDownloadStatus.idle;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _savedApkPath;
  bool _cancelled = false;
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _httpClient?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (!mounted) return;
    setState(() {
      _status = UpdateDownloadStatus.downloading;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _cancelled = false;
    });

    _httpClient = http.Client();
    IOSink? fileSink;
    File? tempFile;

    try {
      String? storageDir;
      try {
        const channel = MethodChannel('heat/updater');
        storageDir = await channel.invokeMethod<String>('getAppStorageDir');
      } catch (err) {
        debugPrint('getAppStorageDir error: $err');
      }

      if (storageDir == null || storageDir.isEmpty) {
        throw Exception('Espace de stockage non disponible sur cet appareil.');
      }

      tempFile = File('$storageDir/heat-update.apk');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      final separator = widget.update.apkUrl.contains('?') ? '&' : '?';
      final freshApkUrl =
          '${widget.update.apkUrl}${separator}t=${DateTime.now().millisecondsSinceEpoch}';
      final request = http.Request('GET', Uri.parse(freshApkUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode >= 400) {
        throw Exception(
          'Le serveur a renvoyé une erreur HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? 0;
      if (mounted) {
        setState(() => _totalBytes = total);
      }

      fileSink = tempFile.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        if (_cancelled) {
          await fileSink.close();
          try {
            await tempFile.delete();
          } catch (_) {}
          return;
        }

        fileSink.add(chunk);
        received += chunk.length;

        if (mounted) {
          setState(() {
            _downloadedBytes = received;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
          });
        }
      }

      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      if (!mounted || _cancelled) return;

      setState(() {
        _status = UpdateDownloadStatus.completed;
        _savedApkPath = tempFile!.path;
        _progress = 1.0;
      });

      await _triggerInstall(tempFile.path);
    } catch (error) {
      if (_cancelled) return;
      if (fileSink != null) {
        try {
          await fileSink.close();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _status = UpdateDownloadStatus.failed;
          _errorMessage = error.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    try {
      const channel = MethodChannel('heat/updater');
      await channel.invokeMethod<bool>('installApk', {'filePath': filePath});
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HeatColors.heatRed,
            content: Text(
              'Erreur d\'installation : $err. Utilise le lien navigateur ci-dessous.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openExternalBrowser() async {
    final uri = Uri.parse(widget.update.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).toInt();

    return PopScope(
      canPop: !widget.isForced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mise à jour Heat'),
          automaticallyImplyLeading: !widget.isForced,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HeatColors.paperCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HeatColors.navyHeader, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeatSectionBanner(
                      title: 'Version ${widget.update.version}',
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Installée : v$appVersionLabel (Build $appBuildNumber) → '
                      'Nouvelle : v${widget.update.version} (Build ${widget.update.buildNumber})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: HeatColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((widget.update.releaseNotes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.update.releaseNotes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: HeatColors.inkDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: HeatColors.paperCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HeatColors.paperBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_status == UpdateDownloadStatus.downloading) ...[
                      Text(
                        'Téléchargement de l\'APK… $percent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: HeatColors.navyHeader,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _totalBytes > 0 ? _progress : null,
                        minHeight: 8,
                        color: HeatColors.heatRed,
                        backgroundColor: HeatColors.paperBorder,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _totalBytes > 0
                            ? '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}'
                            : _formatBytes(_downloadedBytes),
                        style: const TextStyle(
                          fontSize: 12,
                          color: HeatColors.inkMuted,
                        ),
                      ),
                    ] else if (_status == UpdateDownloadStatus.completed) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: HeatColors.trackGreen,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Téléchargement terminé ! Lancement de l\'installateur Android…',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: HeatColors.trackGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _savedApkPath == null
                            ? null
                            : () => _triggerInstall(_savedApkPath!),
                        icon: const Icon(Icons.install_mobile),
                        label: const Text('Relancer l\'installation'),
                      ),
                    ] else if (_status == UpdateDownloadStatus.failed) ...[
                      Text(
                        'Échec du téléchargement : ${_errorMessage ?? "Erreur inconnue"}',
                        style: const TextStyle(
                          color: HeatColors.heatRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _startDownload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openExternalBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Télécharger via le navigateur'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
