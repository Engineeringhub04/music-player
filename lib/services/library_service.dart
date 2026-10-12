import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/video_info.dart';

/// One user playlist.
class UserPlaylist {
  final String id;
  String name;
  final List<VideoInfo> videos;
  final DateTime createdAt;

  UserPlaylist({
    required this.id,
    required this.name,
    List<VideoInfo>? videos,
    DateTime? createdAt,
  })  : videos = videos ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    final raw = json['videos'];
    final videos = <VideoInfo>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          videos.add(VideoInfo.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return UserPlaylist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Playlist').toString(),
      videos: videos,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'videos': videos.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Playlists + favorites + local tracks, persisted as JSON in the app docs dir.
class LibraryService extends ChangeNotifier {
  static const _fileName = 'music_player_library.json';

  final List<UserPlaylist> playlists = [];
  final List<VideoInfo> favorites = [];
  final List<VideoInfo> recentlyPlayed = [];

  /// Downloaded tracks registered on completion (isLocal=true,
  /// videoUrl = absolute file path). Persisted — survives restarts.
  final List<VideoInfo> localTracks = [];
  bool _ready = false;

  bool get ready => _ready;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> init() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is Map) {
          for (final e in (decoded['playlists'] as List? ?? [])) {
            if (e is Map) {
              playlists.add(
                  UserPlaylist.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          for (final e in (decoded['favorites'] as List? ?? [])) {
            if (e is Map) {
              favorites
                  .add(VideoInfo.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          for (final e in (decoded['recentlyPlayed'] as List? ?? [])) {
            if (e is Map) {
              recentlyPlayed
                  .add(VideoInfo.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          for (final e in (decoded['localTracks'] as List? ?? [])) {
            if (e is Map) {
              localTracks
                  .add(VideoInfo.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
      }
    } catch (_) {
      // Start fresh on corrupt file.
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'playlists': playlists.map((p) => p.toJson()).toList(),
        'favorites': favorites.map((v) => v.toJson()).toList(),
        'recentlyPlayed': recentlyPlayed.map((v) => v.toJson()).toList(),
        'localTracks': localTracks.map((v) => v.toJson()).toList(),
      }));
    } catch (_) {}
  }

  // ---------- Playlists ----------

  Future<UserPlaylist> createPlaylist(String name) async {
    final clean = name.trim().isEmpty ? 'My Playlist' : name.trim();
    final p = UserPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: clean,
    );
    playlists.insert(0, p);
    await _save();
    notifyListeners();
    return p;
  }

  Future<void> renamePlaylist(UserPlaylist p, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    p.name = clean;
    await _save();
    notifyListeners();
  }

  Future<void> deletePlaylist(UserPlaylist p) async {
    playlists.removeWhere((e) => e.id == p.id);
    await _save();
    notifyListeners();
  }

  Future<void> addToPlaylist(UserPlaylist p, VideoInfo video) async {
    final target = playlists.firstWhere(
      (e) => e.id == p.id,
      orElse: () => p,
    );
    if (target.videos.any((v) => v.id == video.id && v.id.isNotEmpty)) return;
    target.videos.add(video);
    await _save();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(UserPlaylist p, VideoInfo video) async {
    p.videos.removeWhere((v) => v.id == video.id);
    await _save();
    notifyListeners();
  }

  // ---------- Favorites ----------

  bool isFavorite(VideoInfo v) =>
      favorites.any((e) => e.id == v.id && v.id.isNotEmpty);

  Future<void> toggleFavorite(VideoInfo v) async {
    if (isFavorite(v)) {
      favorites.removeWhere((e) => e.id == v.id);
    } else {
      favorites.insert(0, v);
    }
    await _save();
    notifyListeners();
  }

  // ---------- Recently played ----------

  Future<void> addRecent(VideoInfo v) async {
    recentlyPlayed.removeWhere((e) => e.id == v.id && v.id.isNotEmpty);
    recentlyPlayed.insert(0, v);
    if (recentlyPlayed.length > 50) {
      recentlyPlayed.removeRange(50, recentlyPlayed.length);
    }
    await _save();
    notifyListeners();
  }

  // ---------- Local tracks (downloads) ----------

  /// Register a finished download. Replaces any previous entry for the
  /// same file path. Persisted, so it survives app restarts.
  Future<void> registerLocalTrack(VideoInfo track) async {
    localTracks.removeWhere((e) => e.videoUrl == track.videoUrl);
    localTracks.insert(0, track);
    await _save();
    notifyListeners();
  }

  /// Remove a local track by its file path (e.g. after file deletion).
  Future<void> removeLocalTrack(String filePath) async {
    final n = localTracks.length;
    localTracks.removeWhere((e) => e.videoUrl == filePath);
    if (localTracks.length != n) {
      await _save();
      notifyListeners();
    }
  }

  // ---------- Backup / restore ----------

  Future<String> exportJson() async {
    final f = await _file();
    return f.existsSync() ? await f.readAsString() : '{}';
  }

  Future<void> importJson(String json) async {
    final f = await _file();
    await f.writeAsString(json);
    playlists.clear();
    favorites.clear();
    recentlyPlayed.clear();
    localTracks.clear();
    await init();
  }

  Future<void> clearCache() async {
    // Clears in-memory lists only; files stay on disk.
    playlists.clear();
    favorites.clear();
    recentlyPlayed.clear();
    localTracks.clear();
    await _save();
    notifyListeners();
  }
}
