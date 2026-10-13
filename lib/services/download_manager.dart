import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/video_info.dart';

enum DlStatus { queued, running, paused, complete, failed, canceled }

/// One download tracked by the app.
class DownloadEntry {
  final String taskId;
  final DownloadTask task;
  final String title;
  final bool audio;

  /// The video this download came from (for Local Music registration).
  final VideoInfo? video;

  double progress; // 0..1, -1 unknown
  DlStatus status;
  double speedMbps; // MB/s, -1 unknown
  String? error;

  /// Total bytes expected (from the format info); -1 when unknown.
  final int expectedBytes;

  DownloadEntry({
    required this.taskId,
    required this.task,
    required this.title,
    required this.audio,
    this.video,
    this.progress = 0,
    this.status = DlStatus.queued,
    this.speedMbps = -1,
    this.error,
    this.expectedBytes = -1,
  });

  /// Bytes downloaded so far (estimated from progress), -1 if unknown.
  int get downloadedBytes => expectedBytes > 0 && progress >= 0
      ? (expectedBytes * progress.clamp(0.0, 1.0)).round()
      : -1;
}

/// Wraps background_downloader: enqueue / pause / resume / cancel,
/// max 3 parallel downloads, app-local /MusicPlayer folder.
class DownloadManager extends ChangeNotifier {
  final Map<String, DownloadEntry> _entries = {};
  StreamSubscription<TaskUpdate>? _sub;
  bool _initialized = false;

  /// Called when a download finishes: (entry, absolute file path).
  /// Used to register the file into Local Music (LibraryService).
  Future<void> Function(DownloadEntry entry, String filePath)?
      onDownloadComplete;

  List<DownloadEntry> get entries => _entries.values.toList();
  List<DownloadEntry> get active => _entries.values
      .where((e) =>
          e.status == DlStatus.queued ||
          e.status == DlStatus.running ||
          e.status == DlStatus.paused ||
          e.status == DlStatus.failed)
      .toList();
  List<DownloadEntry> get completed => _entries.values
      .where((e) => e.status == DlStatus.complete)
      .toList();

  Future<void> init() async {
    if (_initialized) return;
    // App-specific external dir on Android (no storage permission needed
    // on Android 10+), app documents elsewhere.
    if (Platform.isAndroid) {
      Task.useExternalStorage = true;
    }
    await FileDownloader().ready;
    await FileDownloader().configure(
      globalConfig: [
        // holding queue: max 3 parallel downloads
        (Config.holdingQueue, (3, null, null)),
      ],
    );
    _sub = FileDownloader().updates.listen(_onUpdate);
    _initialized = true;
  }

  static String sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cut = cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
    return cut.isEmpty ? 'download' : cut;
  }

  /// Enqueue a download. Returns the task id.
  /// [fileExt] overrides the default extension ('m4a' for audio, 'mp4' for
  /// video) — e.g. 'mp3' for "Save to Audio".
  Future<String> enqueueDownload({
    required String url,
    required String title,
    required bool audio,
    VideoInfo? video,
    bool requiresWiFi = false,
    int expectedBytes = -1,
    String? fileExt,
  }) async {
    // POST_NOTIFICATIONS on first download (Android 13+).
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    final ext = fileExt ?? (audio ? 'm4a' : 'mp4');
    final filename = '${sanitizeFileName(title)}.$ext';
    final task = DownloadTask(
      url: url,
      filename: filename,
      directory: 'MusicPlayer',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      allowPause: true,
      requiresWiFi: requiresWiFi,
      retries: 3,
      displayName: title,
    );
    final ok = await FileDownloader().enqueue(task);
    if (!ok) {
      throw const DownloadException('Could not start download.');
    }
    _entries[task.taskId] = DownloadEntry(
      taskId: task.taskId,
      task: task,
      title: title,
      audio: audio,
      video: video,
      expectedBytes: expectedBytes,
    );
    notifyListeners();
    return task.taskId;
  }

  Future<void> pause(String taskId) async {
    final entry = _entries[taskId];
    if (entry == null) return;
    await FileDownloader().pause(entry.task);
  }

  Future<void> resume(String taskId) async {
    final entry = _entries[taskId];
    if (entry == null) return;
    entry.error = null;
    await FileDownloader().resume(entry.task);
    notifyListeners();
  }

  Future<void> cancel(String taskId) async {
    await FileDownloader().cancelTaskWithId(taskId);
    _entries.remove(taskId);
    notifyListeners();
  }

  void dismiss(String taskId) {
    _entries.remove(taskId);
    notifyListeners();
  }

  /// Pause every active download.
  Future<void> pauseAll() async {
    for (final e in active) {
      if (e.status == DlStatus.running || e.status == DlStatus.queued) {
        await FileDownloader().pause(e.task);
      }
    }
  }

  /// Resume every paused/failed download.
  Future<void> resumeAll() async {
    for (final e in active) {
      if (e.status == DlStatus.paused || e.status == DlStatus.failed) {
        e.error = null;
        await FileDownloader().resume(e.task);
      }
    }
    notifyListeners();
  }

  /// Cancel every active download.
  Future<void> cancelAll() async {
    final ids = active.map((e) => e.taskId).toList();
    for (final id in ids) {
      await FileDownloader().cancelTaskWithId(id);
      _entries.remove(id);
    }
    notifyListeners();
  }

  /// Absolute path where completed files land.
  Future<String> downloadDirPath() async {
    final task = DownloadTask(
      url: 'https://example.com/x',
      directory: 'MusicPlayer',
      baseDirectory: BaseDirectory.applicationDocuments,
    );
    final full = await task.filePath();
    return full.substring(0, full.lastIndexOf(Platform.pathSeparator));
  }

  void _onUpdate(TaskUpdate update) {
    final entry = _entries[update.task.taskId];
    if (entry == null) return;

    if (update is TaskProgressUpdate) {
      entry.progress = update.progress < 0 ? entry.progress : update.progress;
      entry.speedMbps =
          update.hasNetworkSpeed ? update.networkSpeed : entry.speedMbps;
      if (entry.status == DlStatus.queued || entry.status == DlStatus.paused) {
        entry.status = DlStatus.running;
      }
    } else if (update is TaskStatusUpdate) {
      switch (update.status) {
        case TaskStatus.enqueued:
          entry.status = DlStatus.queued;
        case TaskStatus.running:
          entry.status = DlStatus.running;
        case TaskStatus.paused:
          entry.status = DlStatus.paused;
        case TaskStatus.complete:
          entry.status = DlStatus.complete;
          entry.progress = 1.0;
          // Register into Local Music (fire-and-forget).
          _registerComplete(entry, update.task);
        case TaskStatus.canceled:
          entry.status = DlStatus.canceled;
        case TaskStatus.failed:
          entry.status = DlStatus.failed;
          entry.error =
              update.exception?.description ?? 'Download failed.';
        case TaskStatus.notFound:
        case TaskStatus.waitingToRetry:
          entry.status = DlStatus.failed;
          entry.error = 'Download failed. Will not retry automatically.';
      }
    }
    notifyListeners();
  }

  /// Resolve the finished file path and notify [onDownloadComplete].
  /// Verifies the file actually exists; falls back to scanning the
  /// download directory by filename if the resolved path is wrong.
  Future<void> _registerComplete(
      DownloadEntry entry, Task task) async {
    final cb = onDownloadComplete;
    if (cb == null || entry.video == null) {
      debugPrint(
          'DownloadManager: skip registration (callback=${cb != null}, video=${entry.video != null})');
      return;
    }
    try {
      var path = await task.filePath();
      var f = File(path);
      if (!await f.exists()) {
        // Fallback: scan the download dir for the file by name.
        debugPrint(
            'DownloadManager: filePath() missing, scanning dir for ${task.filename}');
        final dirPath = await downloadDirPath();
        final candidate =
            '$dirPath${Platform.pathSeparator}${task.filename}';
        if (await File(candidate).exists()) {
          path = candidate;
          f = File(path);
        }
      }
      if (!await f.exists()) {
        debugPrint(
            'DownloadManager: completed file not found on disk: $path');
        return;
      }
      debugPrint('DownloadManager: registering completed file: $path');
      await cb(entry, path);
    } catch (e) {
      debugPrint('DownloadManager: registration failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);
  @override
  String toString() => message;
}
