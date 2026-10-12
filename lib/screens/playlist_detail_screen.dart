import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/download_sheet.dart';
import '../widgets/glass_popup.dart';
import '../widgets/video_menu.dart';

/// Playlist detail: back, centered title, header 3-dot,
/// search, song rows with 3-dot glass menus. No download icon.
class PlaylistDetailScreen extends StatefulWidget {
  final UserPlaylist playlist;
  final LibraryService library;
  final PlayerService? player;
  final SettingsService? settings;
  final DownloadManager? downloads;
  final HistoryService? history;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.library,
    this.player,
    this.settings,
    this.downloads,
    this.history,
  });

  @override
  State<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends State<PlaylistDetailScreen> {
  String _query = '';

  VideoMenuDeps? get _deps {
    if (widget.player == null ||
        widget.settings == null ||
        widget.downloads == null ||
        widget.history == null) {
      return null;
    }
    return VideoMenuDeps(
      library: widget.library,
      player: widget.player!,
      settings: widget.settings!,
      downloads: widget.downloads!,
      history: widget.history!,
    );
  }

  void _play(VideoInfo v, List<VideoInfo> queue) {
    widget.library.addRecent(v);
    widget.player?.play(v, queue: queue);
  }

  void _songMenu(VideoInfo v) {
    final deps = _deps;
    if (deps == null) return;
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Play',
          icon: Icons.play_arrow,
          onTap: () => _play(v, widget.playlist.videos),
        ),
        GlassMenuItem(
          label: deps.library.isFavorite(v)
              ? 'Remove from Favorites'
              : 'Add to Favorites',
          icon: Icons.favorite_border,
          onTap: () async {
            await deps.library.toggleFavorite(v);
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
              library: deps.library,
              onPick: (p) async {
                await deps.library.addToPlaylist(p, v);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Added to ${p.name}.')),
                  );
                }
              },
            );
          },
        ),
        GlassMenuItem(
          label: 'Download',
          icon: Icons.download_outlined,
          onTap: () => quickDownload(context, v, deps: deps),
        ),
        GlassMenuItem(
          label: 'Select Quality',
          icon: Icons.chevron_right,
          onTap: () {
            showDownloadSheet(
              context,
              video: v,
              settings: deps.settings,
              downloads: deps.downloads,
              history: deps.history,
            );
          },
        ),
        GlassMenuItem(
          label: 'Remove from playlist',
          icon: Icons.remove_circle_outline,
          destructive: true,
          onTap: () async {
            await widget.library
                .removeFromPlaylist(widget.playlist, v);
          },
        ),
      ],
    );
  }

  void _headerMenu() {
    final videos = widget.playlist.videos;
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Play All',
          icon: Icons.play_arrow,
          onTap: () {
            if (videos.isNotEmpty) {
              widget.library.addRecent(videos.first);
              widget.player?.playQueue(videos);
            }
          },
        ),
        GlassMenuItem(
          label: 'Add All to a Playlist..',
          icon: Icons.playlist_add,
          onTap: () {
            if (videos.isEmpty) return;
            showAddToListSheet(
              context,
              library: widget.library,
              onPick: (p) async {
                for (final v in videos) {
                  await widget.library.addToPlaylist(p, v);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Added to ${p.name}.')),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    final videos = widget.playlist.videos
        .where((v) =>
            v.title.toLowerCase().contains(_query.toLowerCase()) ||
            v.channelName
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor:
          AppTheme.isLight ? Colors.white : AppTheme.scaffoldBg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(4, 8, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: fg),
                    ),
                    Expanded(
                      child: Text(
                        widget.playlist.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.pageTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: _headerMenu,
                      icon: Icon(Icons.more_vert, color: fg),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBarField(
                  hint: 'Search..',
                  onChanged: (v) =>
                      setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: videos.isEmpty
                    ? const Center(
                        child: Text(
                          'No songs in this playlist yet.',
                          style: AppText.body,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: videos.length,
                        itemBuilder: (c, i) {
                          final v = videos[i];
                          return SongRow(
                            video: v,
                            onTap: () => _play(v, videos),
                            onMenu: () => _songMenu(v),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
