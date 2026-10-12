import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';

/// Home: "Discover Great Music", search bar, Top Music Videos (trending API),
/// Top Artists, Top Playlists.
class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;
  final void Function(VideoInfo video) onVideoTap;
  final VoidCallback onSearchTap;
  final VoidCallback onViewAllTrending;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.library,
    required this.player,
    required this.onVideoTap,
    required this.onSearchTap,
    required this.onViewAllTrending,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<VideoInfo>? _trending;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await widget.settings.apiClient.trending();
      if (!mounted) return;
      setState(() {
        _trending = videos;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  void _play(VideoInfo v) {
    widget.library.addRecent(v);
    widget.player.play(v, queue: _trending ?? [v]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Text('Discover Great Music', style: AppText.pageTitle),
              ),
              const SizedBox(height: 14),
              SearchBarField(
                hint: 'Search songs..',
                readOnly: true,
                onTap: widget.onSearchTap,
              ),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Top Music Videos',
                onViewTap: widget.onViewAllTrending,
              ),
              const SizedBox(height: 12),
              _trendingSection(),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Top Artists'),
              const SizedBox(height: 12),
              _artistsRow(),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Top Playlists'),
              const SizedBox(height: 12),
              _playlistsRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendingSection() {
    if (_loading) {
      return SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (c, _) => Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppTheme.textGrey,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final videos = _trending ?? [];
    if (videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No trending videos right now.\nPull down to refresh.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      );
    }
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length.clamp(0, 10),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (c, i) {
          final v = videos[i];
          return VideoHCard(
            video: v,
            onTap: () => _play(v),
          );
        },
      ),
    );
  }

  Widget _artistsRow() {
    final videos = _trending ?? [];
    // Derive artists from trending channels (unique, with thumbnails).
    final seen = <String>{};
    final artists = <VideoInfo>[];
    for (final v in videos) {
      final name = v.channelName.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        artists.add(v);
      }
      if (artists.length >= 8) break;
    }
    if (artists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Artists will appear here.', style: AppText.body),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (c, i) {
          final a = artists[i];
          return ArtistCircle(
            name: a.channelName,
            imageUrl: a.thumbnailUrl,
            onTap: () => _play(a),
          );
        },
      ),
    );
  }

  Widget _playlistsRow() {
    final defaults = [
      ("80's Vibes", Icons.music_note),
      ("90's Rewind", Icons.music_note),
      ("Hits: 00's", Icons.music_note),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: defaults.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (c, i) {
          final d = defaults[i];
          return Container(
            width: 170,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.queue_music,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      d.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
