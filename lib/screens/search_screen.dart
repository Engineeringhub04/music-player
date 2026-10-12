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
import '../widgets/glass_popup.dart';
import '../widgets/video_menu.dart';

/// Search like the reference app: search bar with clear + Cancel,
/// sections (Songs / Videos / Playlists / Albums) each with a pink "View"
/// link and horizontal cards (thumbnail, white title, pink artist, 3-dot).
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
  List<VideoInfo>? _songs;
  List<PlaylistInfo>? _playlists;
  List<PlaylistInfo>? _albums;
  String? _error;
  bool _searching = false;
  String _query = '';

  VideoMenuDeps get _deps => VideoMenuDeps(
        library: widget.library,
        player: widget.player,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        _songs = null;
        _playlists = null;
        _albums = null;
        _error = null;
        _searching = false;
        _query = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _query = q;
    });
    try {
      final songs = await widget.settings.apiClient.search(q, limit: 12);
      List<PlaylistInfo> playlists = [];
      List<PlaylistInfo> albums = [];
      try {
        playlists = await widget.settings.apiClient
            .searchPlaylists(q, kind: 'playlists', limit: 8);
      } catch (_) {}
      try {
        albums = await widget.settings.apiClient
            .searchPlaylists(q, kind: 'albums', limit: 8);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _playlists = playlists;
        _albums = albums;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Try again.';
      });
    }
  }

  void _play(VideoInfo v, List<VideoInfo> queue) {
    widget.library.addRecent(v);
    widget.history.addWatched(v);
    widget.player.play(v, queue: queue);
  }

  void _playlistMenu(PlaylistInfo p) {
    showIosMenu(
      context,
      items: [
        GlassMenuItem(
          label: 'Save Playlist',
          icon: Icons.download_outlined,
          onTap: () => _savePlaylist(p),
        ),
        GlassMenuItem(
          label: 'Play Playlist',
          icon: Icons.play_arrow,
          onTap: () => _playPlaylist(p),
        ),
      ],
    );
  }

  Future<void> _savePlaylist(PlaylistInfo p) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saving "${p.title}"…')),
    );
    try {
      final entries =
          await widget.settings.apiClient.playlist(p.playlistUrl);
      if (entries.isEmpty) {
        throw const ApiException('Playlist is empty.');
      }
      final created =
          await widget.library.createPlaylist(p.title);
      for (final v in entries) {
        await widget.library.addToPlaylist(created, v);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Saved "${p.title}" (${entries.length} songs).'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _playPlaylist(PlaylistInfo p) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loading playlist…')),
    );
    try {
      final entries =
          await widget.settings.apiClient.playlist(p.playlistUrl);
      if (entries.isEmpty) {
        throw const ApiException('Playlist is empty.');
      }
      widget.library.addRecent(entries.first);
      await widget.player.playQueue(entries);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load: $e')),
        );
      }
    }
  }

  void _viewAllSongs() {
    final songs = _songs ?? [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoListScreen(
          title: 'Songs',
          videos: songs,
          deps: _deps,
        ),
      ),
    );
  }

  void _viewAllVideos() {
    final songs = _songs ?? [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoListScreen(
          title: 'Videos',
          videos: songs,
          deps: _deps,
        ),
      ),
    );
  }

  void _viewAllPlaylists(List<PlaylistInfo> items, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlaylistListScreen(
          title: title,
          items: items,
          onMenu: _playlistMenu,
          onTap: _playPlaylist,
        ),
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBarField(
                      hint: 'Search songs..',
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      suffix: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: AppTheme.textGrey,
                                size: 20,
                              ),
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: fg, fontSize: 17),
                    ),
                  ),
                ],
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
                        AppTheme.primary),
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
    if (_songs == null) {
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
              'Search for songs, videos,\nplaylists and albums.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      );
    }
    final songs = _songs!;
    final playlists = _playlists ?? [];
    final albums = _albums ?? [];
    if (songs.isEmpty &&
        playlists.isEmpty &&
        albums.isEmpty &&
        !_searching) {
      return Center(
        child: Text(
          'No results for "$_query".',
          style: AppText.body,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _section(
          title: 'Songs',
          items: songs,
          onView: songs.length > 3 ? _viewAllSongs : null,
        ),
        _section(
          title: 'Videos',
          items: songs,
          onView: songs.length > 3 ? _viewAllVideos : null,
        ),
        _playlistSection(
          title: 'Playlists',
          items: playlists,
          onView: playlists.length > 2
              ? () => _viewAllPlaylists(playlists, 'Playlists')
              : null,
        ),
        _playlistSection(
          title: 'Albums',
          items: albums,
          onView: albums.length > 2
              ? () => _viewAllPlaylists(albums, 'Albums')
              : null,
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required List<VideoInfo> items,
    VoidCallback? onView,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.sectionTitle),
              ),
              if (onView != null)
                GestureDetector(
                  onTap: onView,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('View', style: AppText.viewLink),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length.clamp(0, 10),
            separatorBuilder: (_, __) =>
                const SizedBox(width: 12),
            itemBuilder: (c, i) {
              final v = items[i];
              return _ResultCard(
                video: v,
                onTap: () => _play(v, items),
                onMenu: () =>
                    showVideoMenu(context, v, deps: _deps),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _playlistSection({
    required String title,
    required List<PlaylistInfo> items,
    VoidCallback? onView,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.sectionTitle),
              ),
              if (onView != null)
                GestureDetector(
                  onTap: onView,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('View', style: AppText.viewLink),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length.clamp(0, 10),
            separatorBuilder: (_, __) =>
                const SizedBox(width: 12),
            itemBuilder: (c, i) {
              final p = items[i];
              return _PlaylistCard(
                info: p,
                onTap: () => _playPlaylist(p),
                onMenu: () => _playlistMenu(p),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal result card: dark rounded card, thumbnail, white title,
/// pink artist, 3-dot — like the reference search page.
class _ResultCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _ResultCard({
    required this.video,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final card =
        AppTheme.isLight ? AppTheme.cardLight : AppTheme.card;
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: video.thumbnailUrl.isEmpty
                    ? Container(
                        color: AppTheme.primary
                            .withValues(alpha: 0.18),
                        child: const Icon(
                          Icons.music_note,
                          color: AppTheme.textGrey,
                        ),
                      )
                    : Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(
                          Icons.music_note,
                          color: AppTheme.textGrey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    video.title.isEmpty ? 'Untitled' : video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelName.isEmpty
                        ? 'Unknown artist'
                        : video.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.artist,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMenu,
              icon: const Icon(
                Icons.more_vert,
                color: AppTheme.textGrey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistInfo info;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _PlaylistCard({
    required this.info,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final card =
        AppTheme.isLight ? AppTheme.cardLight : AppTheme.card;
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: info.thumbnailUrl.isEmpty
                    ? Container(
                        color: AppTheme.primary
                            .withValues(alpha: 0.18),
                        child: const Icon(
                          Icons.queue_music,
                          color: AppTheme.primary,
                        ),
                      )
                    : Image.network(
                        info.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(
                          Icons.queue_music,
                          color: AppTheme.textGrey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    info.title.isEmpty ? 'Untitled' : info.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.channelName.isEmpty
                        ? '${info.videoCount} videos'
                        : info.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.artist,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMenu,
              icon: const Icon(
                Icons.more_vert,
                color: AppTheme.textGrey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full list page for a search section ("View").
class VideoListScreen extends StatelessWidget {
  final String title;
  final List<VideoInfo> videos;
  final VideoMenuDeps deps;

  const VideoListScreen({
    super.key,
    required this.title,
    required this.videos,
    required this.deps,
  });

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
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: fg),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.pageTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                itemCount: videos.length,
                itemBuilder: (c, i) {
                  final v = videos[i];
                  return SongRow(
                    video: v,
                    onTap: () {
                      deps.library.addRecent(v);
                      deps.player.play(v, queue: videos);
                    },
                    onMenu: () =>
                        showVideoMenu(context, v, deps: deps),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListScreen extends StatelessWidget {
  final String title;
  final List<PlaylistInfo> items;
  final void Function(PlaylistInfo) onMenu;
  final void Function(PlaylistInfo) onTap;

  const _PlaylistListScreen({
    required this.title,
    required this.items,
    required this.onMenu,
    required this.onTap,
  });

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
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: fg),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.pageTitle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final p = items[i];
                  return _PlaylistCard(
                    info: p,
                    onTap: () => onTap(p),
                    onMenu: () => onMenu(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
