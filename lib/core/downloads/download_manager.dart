import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meditator/core/api/api_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadedMeditation {
  const DownloadedMeditation({
    required this.meditationId,
    required this.localPath,
    required this.title,
    required this.durationMinutes,
    required this.category,
    required this.downloadedAt,
    this.sizeBytes = 0,
  });

  final String meditationId;
  final String localPath;
  final String title;
  final int durationMinutes;
  final String category;
  final DateTime downloadedAt;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'meditationId': meditationId,
        'localPath': localPath,
        'title': title,
        'durationMinutes': durationMinutes,
        'category': category,
        'downloadedAt': downloadedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory DownloadedMeditation.fromJson(Map<String, dynamic> json) =>
      DownloadedMeditation(
        meditationId: json['meditationId'] as String,
        localPath: json['localPath'] as String,
        title: json['title'] as String? ?? '',
        durationMinutes: json['durationMinutes'] as int? ?? 0,
        category: json['category'] as String? ?? '',
        downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
            DateTime.now(),
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );
}

enum DownloadStatus { idle, downloading, completed, error }

class DownloadProgress {
  const DownloadProgress({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.error,
  });
  final DownloadStatus status;
  final double progress;
  final String? error;
}

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const _kDownloadsKey = 'offline_downloads';

  final _downloads = ValueNotifier<Map<String, DownloadedMeditation>>({});
  ValueListenable<Map<String, DownloadedMeditation>> get downloads => _downloads;

  final _activeDownloads = <String, ValueNotifier<DownloadProgress>>{};
  final _cancelTokens = <String, CancelToken>{};

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromPrefs();
  }

  bool isDownloaded(String meditationId) =>
      _downloads.value.containsKey(meditationId);

  String? localPath(String meditationId) =>
      _downloads.value[meditationId]?.localPath;

  ValueNotifier<DownloadProgress> progressOf(String meditationId) {
    return _activeDownloads.putIfAbsent(
      meditationId,
      () => ValueNotifier(DownloadProgress(
        status: isDownloaded(meditationId)
            ? DownloadStatus.completed
            : DownloadStatus.idle,
      )),
    );
  }

  Future<void> download({
    required String meditationId,
    required String audioUrl,
    required String title,
    required int durationMinutes,
    required String category,
  }) async {
    if (isDownloaded(meditationId)) return;

    final notifier = progressOf(meditationId);
    if (notifier.value.status == DownloadStatus.downloading) return;

    notifier.value = const DownloadProgress(
      status: DownloadStatus.downloading,
      progress: 0,
    );

    final cancelToken = CancelToken();
    _cancelTokens[meditationId] = cancelToken;

    try {
      final dir = await _downloadDir();
      final ext = audioUrl.contains('.') ? audioUrl.split('.').last.split('?').first : 'mp3';
      final file = File('${dir.path}/$meditationId.$ext');

      await ApiClient.instance.dio.download(
        audioUrl,
        file.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            notifier.value = DownloadProgress(
              status: DownloadStatus.downloading,
              progress: received / total,
            );
          }
        },
      );

      final stat = await file.stat();
      final downloaded = DownloadedMeditation(
        meditationId: meditationId,
        localPath: file.path,
        title: title,
        durationMinutes: durationMinutes,
        category: category,
        downloadedAt: DateTime.now(),
        sizeBytes: stat.size,
      );

      final map = Map<String, DownloadedMeditation>.from(_downloads.value);
      map[meditationId] = downloaded;
      _downloads.value = map;
      await _saveToPrefs();

      notifier.value = const DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        notifier.value = const DownloadProgress(status: DownloadStatus.idle);
      } else {
        notifier.value = DownloadProgress(
          status: DownloadStatus.error,
          error: 'Ошибка загрузки',
        );
      }
    } catch (e) {
      notifier.value = DownloadProgress(
        status: DownloadStatus.error,
        error: 'Ошибка: $e',
      );
    } finally {
      _cancelTokens.remove(meditationId);
    }
  }

  void cancelDownload(String meditationId) {
    _cancelTokens[meditationId]?.cancel();
    _cancelTokens.remove(meditationId);
  }

  Future<void> removeDownload(String meditationId) async {
    final entry = _downloads.value[meditationId];
    if (entry != null) {
      try {
        final f = File(entry.localPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final map = Map<String, DownloadedMeditation>.from(_downloads.value);
    map.remove(meditationId);
    _downloads.value = map;
    await _saveToPrefs();

    _activeDownloads[meditationId]?.value =
        const DownloadProgress(status: DownloadStatus.idle);
  }

  Future<void> removeAll() async {
    final dir = await _downloadDir();
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    _downloads.value = {};
    await _saveToPrefs();
    for (final n in _activeDownloads.values) {
      n.value = const DownloadProgress(status: DownloadStatus.idle);
    }
  }

  int get totalSizeBytes =>
      _downloads.value.values.fold(0, (sum, d) => sum + d.sizeBytes);

  String get totalSizeFormatted {
    final bytes = totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<Directory> _downloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/offline_meditations');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDownloadsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DownloadedMeditation>{};
      for (final entry in map.entries) {
        final dm = DownloadedMeditation.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (File(dm.localPath).existsSync()) {
          result[entry.key] = dm;
        }
      }
      _downloads.value = result;
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final entry in _downloads.value.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_kDownloadsKey, jsonEncode(map));
  }
}
