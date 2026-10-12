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
import '../widgets/glass_popup.dart';
import '../widgets/video_menu.dart';

/// Full "Top Music Videos" page (opened from Home's "View All").
/// Country-based trending, infinite scroll (paged client-side), header
/// 3-dot with Play All / Add All to a Playlist.., glass popup per row.
class TrendingScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;

  const TrendingScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.library,
    required this.player,
  });

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  static const _pageSize = 25;

  List<VideoInfo>? _all;
  int _shown = _pageSize;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  final _scroll = ScrollController();

  VideoMenuDeps get _deps => VideoMenuDeps(
        library: widget.library,
        player: widget.player,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
      );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        _all != null &&
        _shown < _all!.length) {
      setState(() => _loadingMore = true);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _shown = (_shown + _pageSize).clamp(0, _all!.length);
          _loadingMore = false;
        });
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final country = widget.settings.countryCode;
      final videos = await widget.settings.apiClient.trending(
        country: country.isEmpty ? null : country,
      );
      if (!mounted) return;
      setState(() {
        _all = videos;
        _shown = _pageSize.clamp(0, videos.length);
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
    widget.player.play(v, queue: _all ?? [v]);
  }

  void _headerMenu() {
    final videos = _all ?? [];
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Play All',
          icon: Icons.play_arrow,
          onTap: () {
            if (videos.isEmpty) return;
            widget.library.addRecent(videos.first);
            widget.player.playQueue(videos);
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
                          'Added ${videos.length} videos to ${p.name}.'),
                    ),
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
    return Scaffold(
      backgroundColor: AppTheme.isLight
          ? Colors.white
          : AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: AppTheme.isLight
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Top Music Videos',
                      textAlign: TextAlign.center,
                      style: AppText.pageTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: _all == null ? null : _headerMenu,
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.isLight
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppTheme.textGrey,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: 12),
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
        ),
      );
    }
    final videos = _all ?? [];
    if (videos.isEmpty) {
      return const Center(
        child: Text(
          'No trending videos right now.',
          style: AppText.body,
        ),
      );
    }
    final shown = videos.take(_shown).toList();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        controller: _scroll,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: shown.length + (_loadingMore ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= shown.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary),
              ),
            );
          }
          final v = shown[i];
          return SongRow(
            video: v,
            onTap: () => _play(v),
            onMenu: () => showVideoMenu(context, v, deps: _deps),
          );
        },
      ),
    );
  }
}
