import 'dart:math';

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

/// Favorites: title, search, Shuffle + Play buttons (no Radios),
/// favorites list.
class FavoritesScreen extends StatefulWidget {
  final LibraryService library;
  final PlayerService player;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const FavoritesScreen({
    super.key,
    required this.library,
    required this.player,
    required this.settings,
    required this.downloads,
    required this.history,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _query = '';

  void _playAll({bool shuffle = false}) {
    final favs = widget.library.favorites;
    if (favs.isEmpty) return;
    final list = List<VideoInfo>.from(favs);
    if (shuffle) list.shuffle(Random());
    widget.player.playQueue(list);
  }

  void _songMenu(VideoInfo v) {
    final deps = VideoMenuDeps(
      library: widget.library,
      player: widget.player,
      settings: widget.settings,
      downloads: widget.downloads,
      history: widget.history,
    );
    showGlassPopup(
      context,
      items: [
        GlassMenuItem(
          label: 'Play',
          icon: Icons.play_arrow,
          onTap: () => widget.player.play(
            v,
            queue: widget.library.favorites,
          ),
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
              settings: widget.settings,
              downloads: widget.downloads,
              history: widget.history,
            );
          },
        ),
        GlassMenuItem(
          label: 'Play Related Mix',
          icon: Icons.radio_outlined,
          onTap: () => playRelatedMix(context, v, deps: deps),
        ),
        GlassMenuItem(
          label: 'Remove from favorites',
          icon: Icons.heart_broken_outlined,
          destructive: true,
          onTap: () async {
            await widget.library.toggleFavorite(v);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (context, _) {
            final favs = widget.library.favorites
                .where((v) =>
                    v.title.toLowerCase().contains(_query.toLowerCase()) ||
                    v.channelName
                        .toLowerCase()
                        .contains(_query.toLowerCase()))
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Favorites', style: AppText.pageTitle),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SearchBarField(
                    hint: 'Search..',
                    onChanged: (v) =>
                        setState(() => _query = v.trim()),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          icon: Icons.shuffle,
                          label: 'Shuffle',
                          onTap: favs.isEmpty
                              ? null
                              : () => _playAll(shuffle: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          icon: Icons.play_arrow,
                          label: 'Play',
                          onTap: favs.isEmpty
                              ? null
                              : () => _playAll(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: favs.isEmpty
                      ? const Center(
                          child: Text(
                            'No favorites yet.\nTap the heart on any song.',
                            textAlign: TextAlign.center,
                            style: AppText.body,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount: favs.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Colors.white10,
                          ),
                          itemBuilder: (c, i) {
                            final v = favs[i];
                            return SongRow(
                              video: v,
                              onTap: () => widget.player.play(
                                v,
                                queue: widget.library.favorites,
                              ),
                              onMenu: () => _songMenu(v),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
