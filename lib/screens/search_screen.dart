import 'dart:async';

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
import '../widgets/download_sheet.dart';

/// Search with debounced live results, styled like the reference app.
/// Rows: thumbnail, white title, violet artist, download + menu.
class SearchScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;

  const SearchScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.library,
    required this.player,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<VideoInfo>? _results;
  String? _error;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _runSearch(value.trim(), live: true);
    });
  }

  Future<void> _runSearch(String q, {bool live = false}) async {
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _searching = false;
        _query = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = live ? _error : null;
      _query = q;
    });
    try {
      final results =
          await widget.settings.apiClient.search(q, limit: live ? 10 : 25);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!live) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!live) _error = 'Search failed. Try again.';
      });
    }
  }

  void _play(VideoInfo v) {
    widget.library.addRecent(v);
    widget.history.addWatched(v);
    widget.player.play(v, queue: _results ?? [v]);
  }

  void _download(VideoInfo v) {
    showDownloadSheet(
      context,
      video: v,
      settings: widget.settings,
      downloads: widget.downloads,
      history: widget.history,
    );
  }

  void _menu(VideoInfo v) {
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
                Icons.download_outlined,
                color: Colors.white,
              ),
              title: const Text(
                'Download',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(c).pop();
                _download(v);
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
                Icons.playlist_add,
                color: Colors.white,
              ),
              title: const Text(
                'Add to Playlist',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(c).pop();
                _addToPlaylistSheet(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToPlaylistSheet(VideoInfo v) {
    final playlists = widget.library.playlists;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to Playlist', style: AppText.title),
            ),
            Flexible(
              child: playlists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No playlists yet.\nCreate one from the Playlists tab.',
                        textAlign: TextAlign.center,
                        style: AppText.body,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (c, i) {
                        final p = playlists[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.queue_music,
                            color: AppTheme.violet,
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                                color: Colors.white),
                          ),
                          subtitle: Text(
                            '${p.videos.length} songs',
                            style: AppText.body,
                          ),
                          onTap: () async {
                            await widget.library
                                .addToPlaylist(p, v);
                            if (c.mounted) Navigator.of(c).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Added to ${p.name}.'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Search', style: AppText.pageTitle),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchBarField(
                hint: 'Search songs..',
                controller: _controller,
                onChanged: _onChanged,
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.violet),
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 56,
                color: AppTheme.textGrey,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _runSearch(_query),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 56,
              color: AppTheme.textGrey,
            ),
            SizedBox(height: 12),
            Text(
              'Search for videos and music.\nResults appear as you type.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      );
    }
    if (results.isEmpty && !_searching) {
      return Center(
        child: Text(
          'No results for "$_query".',
          style: AppText.body,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: Colors.white10,
      ),
      itemBuilder: (c, i) {
        final v = results[i];
        return Row(
          children: [
            Expanded(
              child: SongRow(
                video: v,
                onTap: () => _play(v),
                onMenu: () => _menu(v),
              ),
            ),
            IconButton(
              onPressed: () => _download(v),
              icon: const Icon(
                Icons.download_outlined,
                color: AppTheme.violet,
                size: 22,
              ),
            ),
          ],
        );
      },
    );
  }
}
