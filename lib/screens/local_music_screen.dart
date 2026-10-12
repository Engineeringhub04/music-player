import 'dart:io';

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/glass_popup.dart';
import '../widgets/video_menu.dart';

/// One local track: absolute file path + metadata.
class _LocalTrack {
  final String path;

  /// Original video id (from the registered library entry); empty for
  /// unregistered files found on disk.
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final bool isAudio;
  final DateTime modified;

  _LocalTrack({
    required this.path,
    this.videoId = '',
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.isAudio = false,
    required this.modified,
  });

  VideoInfo toVideoInfo() => VideoInfo(
        id: path,
        title: title,
        thumbnailUrl: thumbnailUrl,
        durationSecs: 0,
        channelName: artist,
        viewCount: 0,
        videoUrl: path,
        isLocal: true,
        isAudio: isAudio,
      );
}

/// "Local Music": every downloaded file, search, edit/import/sort menu,
/// and the download-progress popup from the reference app.
class LocalMusicScreen extends StatefulWidget {
  final StorageService storage;
  final DownloadManager downloads;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;
  final SettingsService settings;

  const LocalMusicScreen({
    super.key,
    required this.storage,
    required this.downloads,
    required this.history,
    required this.library,
    required this.player,
    required this.settings,
  });

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen> {
  List<_LocalTrack> _tracks = [];
  bool _loading = true;
  String _query = '';
  bool _sortByName = false;
  bool _editMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_onLibraryChanged);
    _refresh();
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    // A download may have completed while this screen is open.
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final tracks = <_LocalTrack>[];
      final seen = <String>{};
      // 1. Registered downloads (persisted in LibraryService) — these have
      // proper title/artist/thumbnail metadata.
      for (final v in widget.library.localTracks) {
        final f = File(v.videoUrl);
        if (!await f.exists()) continue;
        final stat = await f.stat();
        seen.add(v.videoUrl);
        tracks.add(_LocalTrack(
          path: v.videoUrl,
          videoId: v.id,
          title: v.title.isEmpty ? _baseName(v.videoUrl) : v.title,
          artist: v.channelName.isEmpty ? 'Unknown artist' : v.channelName,
          thumbnailUrl: v.thumbnailUrl,
          isAudio: v.isAudio,
          modified: stat.modified,
        ));
      }
      // 2. Files on disk never registered (older downloads): keep showing
      // them with best-effort metadata from history.
      for (final sf in await widget.storage.listFiles()) {
        if (seen.contains(sf.path)) continue;
        final (title, artist, thumb) = _enrich(sf);
        tracks.add(_LocalTrack(
          path: sf.path,
          title: title,
          artist: artist,
          thumbnailUrl: thumb,
          isAudio: sf.path.toLowerCase().endsWith('.mp3'),
          modified: sf.modified,
        ));
      }
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
      _applySort();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _baseName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  /// Match a file to its history entry (title/artist/thumbnail).
  /// Returns (title, artist, thumbnailUrl).
  (String, String, String) _enrich(StoredFile f) {
    final base = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    for (final h in widget.history.downloaded) {
      final clean =
          DownloadManager.sanitizeFileName(h.title).toLowerCase();
      if (clean.isNotEmpty &&
          base.toLowerCase().startsWith(clean.substring(
              0, clean.length > 40 ? 40 : clean.length))) {
        return (h.title, 'Unknown artist', h.thumbnailUrl);
      }
    }
    return (base, 'Unknown artist', '');
  }

  void _applySort() {
    setState(() {
      if (_sortByName) {
        _tracks.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else {
        _tracks.sort(
            (a, b) => b.modified.compareTo(a.modified));
      }
    });
  }

  List<_LocalTrack> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _tracks;
    return _tracks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q))
        .toList();
  }

  void _play(_LocalTrack t) {
    final videos = _filtered.map((e) => e.toVideoInfo()).toList();
    widget.library.addRecent(t.toVideoInfo());
    widget.player.play(t.toVideoInfo(), queue: videos);
  }

  void _headerMenu() {
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: _editMode ? 'Done' : 'Edit',
          icon: Icons.edit_outlined,
          onTap: () => setState(() {
            _editMode = !_editMode;
            _selected.clear();
          }),
        ),
        GlassMenuItem(
          label: 'Import',
          icon: Icons.download_outlined,
          onTap: () async {
            await _refresh();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Library refreshed.')),
              );
            }
          },
        ),
        GlassMenuItem(
          label: 'Sort by Name',
          icon: Icons.sort_by_alpha,
          onTap: () {
            _sortByName = true;
            _applySort();
          },
        ),
        GlassMenuItem(
          label: 'Sort by Date',
          icon: Icons.arrow_downward,
          onTap: () {
            _sortByName = false;
            _applySort();
          },
        ),
      ],
    );
  }

  void _trackMenu(_LocalTrack t) {
    final v = t.toVideoInfo();
    // Video identity for "Save to Audio": the original video id (from the
    // registered library entry), so formats can be fetched and the
    // already-saved check works.
    final menuVideo = VideoInfo(
      id: t.videoId,
      title: t.title,
      thumbnailUrl: t.thumbnailUrl,
      durationSecs: 0,
      channelName: t.artist,
      viewCount: 0,
      videoUrl: '',
      isLocal: true,
    );
    final deps = VideoMenuDeps(
      library: widget.library,
      player: widget.player,
      settings: widget.settings,
      downloads: widget.downloads,
      history: widget.history,
    );
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Play',
          icon: Icons.play_arrow,
          onTap: () => _play(t),
        ),
        GlassMenuItem(
          label: widget.library.isFavorite(v)
              ? 'Remove from Favorites'
              : 'Add to Favorites',
          icon: Icons.favorite_border,
          onTap: () async {
            await widget.library.toggleFavorite(v);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Updated favorites.')),
              );
            }
          },
        ),
        GlassMenuItem(
          label: 'Add to a Playlist..',
          icon: Icons.playlist_add,
          onTap: () {
            showAddToListSheet(
              context,
              library: widget.library,
              onPick: (p) async {
                await widget.library.addToPlaylist(p, v);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to ${p.name}.')),
                  );
                }
              },
            );
          },
        ),
        if (!t.isAudio)
          GlassMenuItem(
            label: isAudioSaved(widget.library, t.videoId)
                ? 'Audio Saved ✓'
                : 'Save to Audio (MP3)',
            icon: Icons.music_note_outlined,
            onTap: () => saveToAudio(context, menuVideo, deps: deps),
          ),
        GlassMenuItem(
          label: 'Delete',
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () async {
            final ok = await showIosConfirm(
              context,
              title: 'Delete file?',
              message: t.title,
            );
            if (ok) {
              await _deletePath(t.path);
              await _refresh();
            }
          },
        ),
      ],
    );
  }

  /// Delete the file at [path] and drop its Local Music registration.
  Future<void> _deletePath(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
    await widget.library.removeLocalTrack(path);
  }

  void _openProgress() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          AppTheme.isLight ? Colors.white : AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => _ProgressSheet(downloads: widget.downloads),
    );
  }

  Future<void> _deleteSelected() async {
    final ok = await showIosConfirm(
      context,
      title: 'Delete ${_selected.length} file(s)?',
      message: 'This cannot be undone.',
    );
    if (!ok) return;
    for (final t in _tracks.where((e) => _selected.contains(e.path))) {
      await _deletePath(t.path);
    }
    setState(() {
      _editMode = false;
      _selected.clear();
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor:
          AppTheme.isLight ? Colors.white : AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new, color: fg),
                  ),
                  Expanded(
                    child: Text(
                      'Local Music',
                      textAlign: TextAlign.center,
                      style: AppText.pageTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: _openProgress,
                    icon: Icon(Icons.download_outlined, color: fg),
                  ),
                  IconButton(
                    onPressed: _headerMenu,
                    icon: Icon(Icons.more_vert, color: fg),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SearchBarField(
                hint: 'Search',
                onChanged: (v) =>
                    setState(() => _query = v.trim()),
              ),
            ),
            if (_editMode)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${_selected.length} selected',
                      style: AppText.body,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : _deleteSelected,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _editMode = false;
                        _selected.clear();
                      }),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No downloads yet.\nDownloaded music appears here.',
                            textAlign: TextAlign.center,
                            style: AppText.body,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (c, i) {
                              final t = _filtered[i];
                              return SongRow(
                                video: t.toVideoInfo(),
                                onTap: () => _play(t),
                                onMenu: () => _trackMenu(t),
                                showCheck: _editMode,
                                checked: _selected
                                    .contains(t.path),
                                onCheckToggle: () {
                                  setState(() {
                                    if (_selected
                                        .contains(t.path)) {
                                      _selected
                                          .remove(t.path);
                                    } else {
                                      _selected
                                          .add(t.path);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "In Progress" download sheet from the reference app:
/// filename, "X MB of Y MB", "% XX.XX", pink progress bar,
/// pause/resume + cancel buttons. 3-dot: Resume All / Pause All / Cancel All.
class _ProgressSheet extends StatelessWidget {
  final DownloadManager downloads;

  const _ProgressSheet({required this.downloads});

  void _menu(BuildContext context) {
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Resume All',
          icon: Icons.play_arrow,
          onTap: () => downloads.resumeAll(),
        ),
        GlassMenuItem(
          label: 'Pause All',
          icon: Icons.pause,
          onTap: () => downloads.pauseAll(),
        ),
        GlassMenuItem(
          label: 'Cancel All',
          icon: Icons.cancel_outlined,
          destructive: true,
          onTap: () => downloads.cancelAll(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return SafeArea(
      child: ListenableBuilder(
        listenable: downloads,
        builder: (context, _) {
          final active = downloads.active;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Text(
                      'In Progress',
                      style: TextStyle(
                        color: fg,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    IconButton(
                      onPressed: () => _menu(context),
                      icon: Icon(Icons.more_vert, color: fg),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: active.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(
                            24, 12, 24, 36),
                        child: Text(
                          'No active downloads.',
                          style: AppText.body,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                            20, 4, 20, 28),
                        itemCount: active.length,
                        itemBuilder: (c, i) =>
                            _ProgressRow(
                          entry: active[i],
                          downloads: downloads,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final DownloadEntry entry;
  final DownloadManager downloads;

  const _ProgressRow({
    required this.entry,
    required this.downloads,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    final pct = entry.progress < 0
        ? 0.0
        : entry.progress.clamp(0.0, 1.0);
    final downloaded = entry.downloadedBytes;
    final total = entry.expectedBytes;
    final sizeText = downloaded >= 0 && total > 0
        ? '${formatBytes(downloaded)} of ${formatBytes(total)}'
        : entry.status == DlStatus.paused
            ? 'Paused'
            : entry.status == DlStatus.failed
                ? (entry.error ?? 'Failed')
                : 'Starting…';
    final pctText = '% ${(pct * 100).toStringAsFixed(2)}';
    final paused = entry.status == DlStatus.paused ||
        entry.status == DlStatus.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor:
                        fg.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sizeText,
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      pctText,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _roundBtn(
            icon: paused ? Icons.play_arrow : Icons.pause,
            onTap: () => paused
                ? downloads.resume(entry.taskId)
                : downloads.pause(entry.taskId),
          ),
          const SizedBox(width: 8),
          _roundBtn(
            icon: Icons.close,
            onTap: () => downloads.cancel(entry.taskId),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
