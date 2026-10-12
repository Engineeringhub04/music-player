import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/video_info.dart';

/// One history record (watched video or finished download).
class HistoryEntry {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final DateTime at;

  HistoryEntry({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.at,
  });

  factory HistoryEntry.fromVideo(VideoInfo v) => HistoryEntry(
        videoId: v.id,
        title: v.title,
        thumbnailUrl: v.thumbnailUrl,
        videoUrl: v.videoUrl,
        at: DateTime.now(),
      );

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        videoId: (json['videoId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
        videoUrl: (json['videoUrl'] ?? '').toString(),
        at: DateTime.tryParse(json['at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'videoUrl': videoUrl,
        'at': at.toIso8601String(),
      };
}

/// Watched + downloaded history, persisted as JSON in the app docs dir.
class HistoryService {
  static const _fileName = 'music_player_history.json';
  static const _maxEntries = 200;

  final List<HistoryEntry> watched = [];
  final List<HistoryEntry> downloaded = [];

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> init() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map) {
        for (final e in (decoded['watched'] as List? ?? [])) {
          if (e is Map) {
            watched.add(HistoryEntry.fromJson(Map<String, dynamic>.from(e)));
          }
        }
        for (final e in (decoded['downloaded'] as List? ?? [])) {
          if (e is Map) {
            downloaded.add(HistoryEntry.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
    } catch (_) {
      // Corrupt history file: start fresh.
    }
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'watched': watched.map((e) => e.toJson()).toList(),
        'downloaded': downloaded.map((e) => e.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<void> addWatched(VideoInfo v) async {
    watched.removeWhere((e) => e.videoId == v.id && v.id.isNotEmpty);
    watched.insert(0, HistoryEntry.fromVideo(v));
    if (watched.length > _maxEntries) {
      watched.removeRange(_maxEntries, watched.length);
    }
    await _save();
  }

  Future<void> addDownloaded(VideoInfo v) async {
    downloaded.removeWhere((e) => e.videoId == v.id && v.id.isNotEmpty);
    downloaded.insert(0, HistoryEntry.fromVideo(v));
    if (downloaded.length > _maxEntries) {
      downloaded.removeRange(_maxEntries, downloaded.length);
    }
    await _save();
  }

  Future<void> clearWatched() async {
    watched.clear();
    await _save();
  }

  Future<void> clearDownloaded() async {
    downloaded.clear();
    await _save();
  }
}
