import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';

/// Playlist detail: back, title, download icon, search, song rows with
/// checkmark + 3-dot menu (screenshot 6).
class PlaylistDetailScreen extends StatefulWidget {
  final UserPlaylist playlist;
  final LibraryService library;
  final PlayerService? player;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.library,
    this.player,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  String _query = '';
  final Set<String> _checked = {};

  void _play(VideoInfo v) {
    widget.library.addRecent(v);
    widget.player?.play(v, queue: widget.playlist.videos);
  }

  void _songMenu(VideoInfo v) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.play_arrow, color: AppTheme.violet),
              title: const Text(
                'Play',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(c).pop();
                _play(v);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.favorite_border,
                color: Colors.white,
              ),
              title: const Text(
                'Add to Favorites',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.of(c).pop();
                if (!widget.library.isFavorite(v)) {
                  await widget.library.toggleFavorite(v);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Added to favorites.')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Remove from playlist',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.of(c).pop();
                await widget.library
                    .removeFromPlaylist(widget.playlist, v);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.playlist.videos
        .where((v) =>
            v.title.toLowerCase().contains(_query.toLowerCase()) ||
            v.channelName.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
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
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Download-all coming from the Downloads tab.'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.download_outlined,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _songMenu(widget.playlist.videos
                              .isNotEmpty
                          ? widget.playlist.videos.first
                          : VideoInfo(
                              id: '',
                              title: widget.playlist.name,
                              thumbnailUrl: '',
                              durationSecs: 0,
                              channelName: '',
                              viewCount: 0,
                              videoUrl: '')),
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBarField(
                  hint: 'Search',
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
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: videos.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Colors.white10,
                        ),
                        itemBuilder: (c, i) {
                          final v = videos[i];
                          return SongRow(
                            video: v,
                            checked: _checked.contains(v.id),
                            onCheckToggle: () {
                              setState(() {
                                if (_checked.contains(v.id)) {
                                  _checked.remove(v.id);
                                } else {
                                  _checked.add(v.id);
                                }
                              });
                            },
                            onTap: () => _play(v),
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
