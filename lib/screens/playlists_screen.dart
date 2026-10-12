import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/glass_popup.dart';
import 'local_music_screen.dart';
import 'playlist_detail_screen.dart';
import 'recently_played_screen.dart';

/// Playlists tab: "Local Music" first (all downloads), then
/// Create New / Recently Played cards, then user playlists.
class PlaylistsScreen extends StatefulWidget {
  final LibraryService library;
  final StorageService storage;
  final PlayerService player;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const PlaylistsScreen({
    super.key,
    required this.library,
    required this.storage,
    required this.player,
    required this.settings,
    required this.downloads,
    required this.history,
  });

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  String _query = '';
  int _localCount = 0;

  @override
  void initState() {
    super.initState();
    _countLocal();
  }

  Future<void> _countLocal() async {
    try {
      final files = await widget.storage.listFiles();
      if (mounted) setState(() => _localCount = files.length);
    } catch (_) {}
  }

  void _openLocalMusic() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LocalMusicScreen(
              storage: widget.storage,
              downloads: widget.downloads,
              history: widget.history,
              library: widget.library,
              player: widget.player,
              settings: widget.settings,
            ),
          ),
        )
        .then((_) => _countLocal());
  }

  void _openRecentlyPlayed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecentlyPlayedScreen(
          library: widget.library,
          player: widget.player,
          settings: widget.settings,
          downloads: widget.downloads,
          history: widget.history,
        ),
      ),
    );
  }

  void _openPlaylist(UserPlaylist p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: p,
          library: widget.library,
          player: widget.player,
          settings: widget.settings,
          downloads: widget.downloads,
          history: widget.history,
        ),
      ),
    );
  }

  Future<void> _createDialog() async {
    final name = await showIosPrompt(
      context,
      title: 'New Playlist',
      placeholder: 'Playlist name',
      okLabel: 'Create',
    );
    if (name != null && name.trim().isNotEmpty) {
      await widget.library.createPlaylist(name.trim());
    }
  }

  void _playlistMenu(UserPlaylist p) {
    showGlassPopup(
      context,
      items: [
        GlassMenuItem(
          label: 'Play',
          icon: Icons.play_arrow,
          onTap: () {
            if (p.videos.isNotEmpty) {
              widget.player.playQueue(p.videos);
            }
          },
        ),
        GlassMenuItem(
          label: 'Rename',
          icon: Icons.edit_outlined,
          onTap: () async {
            final name = await showIosPrompt(
              context,
              title: 'Rename Playlist',
              placeholder: 'Playlist name',
              initialValue: p.name,
              okLabel: 'Save',
            );
            if (name != null && name.trim().isNotEmpty) {
              await widget.library
                  .renamePlaylist(p, name.trim());
            }
          },
        ),
        GlassMenuItem(
          label: 'Delete',
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () async {
            final ok = await showIosConfirm(
              context,
              title: 'Delete "${p.name}"?',
              message: 'The videos stay in your library.',
            );
            if (ok) await widget.library.deletePlaylist(p);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor:
          AppTheme.isLight ? Colors.white : AppTheme.scaffoldBlack,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (context, _) {
            final playlists = widget.library.playlists
                .where((p) => p.name
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Text('Playlists', style: AppText.pageTitle),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _createDialog,
                          icon: Icon(Icons.add,
                              color: fg, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SearchBarField(
                  hint: 'Search',
                  onChanged: (v) =>
                      setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 16),
                // Local Music FIRST — every downloaded file lives here.
                PlaylistRowCard(
                  name: 'Local Music',
                  count: _localCount,
                  fallbackIcon: Icons.download_outlined,
                  onTap: _openLocalMusic,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.add_circle_outline,
                        label: 'Create New Playlist',
                        onTap: _createDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.watch_later_outlined,
                        label: 'Recently Played',
                        onTap: _openRecentlyPlayed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...playlists.map(
                  (p) => PlaylistRowCard(
                    name: p.name,
                    thumbnailUrl: p.videos.isNotEmpty
                        ? p.videos.first.thumbnailUrl
                        : null,
                    count: p.videos.length,
                    onTap: () => _openPlaylist(p),
                    onMenu: () => _playlistMenu(p),
                  ),
                ),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'No playlists yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final card =
        AppTheme.isLight ? Colors.white : AppTheme.cardDark;
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
