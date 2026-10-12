import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'models/video_info.dart';
import 'screens/downloads_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/playlists_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trending_screen.dart';
import 'screens/watch_screen.dart';
import 'services/download_manager.dart';
import 'services/history_service.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers: never let an init failure kill the app.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await runZonedGuarded<Future<void>>(() async {
    final settings = SettingsService();
    try {
      await settings.init();
    } catch (e) {
      debugPrint('SettingsService init failed: $e');
    }

    final downloads = DownloadManager();
    try {
      await downloads.init();
    } catch (e) {
      debugPrint('DownloadManager init failed: $e');
    }

    final storage = StorageService();
    final history = HistoryService();
    try {
      await history.init();
    } catch (e) {
      debugPrint('HistoryService init failed: $e');
    }

    final library = LibraryService();
    try {
      await library.init();
    } catch (e) {
      debugPrint('LibraryService init failed: $e');
    }

    final player = PlayerService(settings: settings);

    runApp(
      MusicPlayerApp(
        settings: settings,
        downloads: downloads,
        storage: storage,
        history: history,
        library: library,
        player: player,
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
  });
}

class MusicPlayerApp extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final StorageService storage;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;

  const MusicPlayerApp({
    super.key,
    required this.settings,
    required this.downloads,
    required this.storage,
    required this.history,
    required this.library,
    required this.player,
  });

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  @override
  Widget build(BuildContext context) {
    // ThemeMode comes from Settings; AppTheme.isLight drives the
    // brightness-aware AppText styles used across every screen.
    final mode = widget.settings.themeMode == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    AppTheme.isLight = mode == ThemeMode.light;
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: MainShell(
        settings: widget.settings,
        downloads: widget.downloads,
        storage: widget.storage,
        history: widget.history,
        library: widget.library,
        player: widget.player,
        onSettingsChanged: () => setState(() {}),
      ),
    );
  }
}

/// Bottom nav shell: Home | Playlists | (Player) | Favorites | Settings.
class MainShell extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final StorageService storage;
  final HistoryService history;
  final LibraryService library;
  final PlayerService player;
  final VoidCallback onSettingsChanged;

  const MainShell({
    super.key,
    required this.settings,
    required this.downloads,
    required this.storage,
    required this.history,
    required this.library,
    required this.player,
    required this.onSettingsChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    // Rotating center-player artwork while music plays.
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _initShareReceiver();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _spin.dispose();
    super.dispose();
  }

  void _initShareReceiver() {
    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_onSharedMedia);
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onSharedMedia(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _onSharedMedia(List<SharedMediaFile> files) {
    for (final f in files) {
      final url = _extractUrl(f.path);
      if (url != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          openWatch(
            context,
            VideoInfo(
              id: url,
              title: 'Shared video',
              thumbnailUrl: '',
              durationSecs: 0,
              channelName: '',
              viewCount: 0,
              videoUrl: url,
            ),
            settings: widget.settings,
            downloads: widget.downloads,
            history: widget.history,
          );
        });
        break;
      }
    }
  }

  String? _extractUrl(String text) {
    final m = RegExp(r'https?://[^\s]+').firstMatch(text);
    return m?.group(0);
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          player: widget.player,
          library: widget.library,
          settings: widget.settings,
          downloads: widget.downloads,
          history: widget.history,
        ),
      ),
    );
  }

  void _goSearch() {
    // iOS-style open: scale + fade from the search bar.
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration:
            const Duration(milliseconds: 220),
        pageBuilder: (c, _, __) => SearchScreen(
          settings: widget.settings,
          downloads: widget.downloads,
          history: widget.history,
          library: widget.library,
          player: widget.player,
        ),
        transitionsBuilder: (c, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _goTrending() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrendingScreen(
          settings: widget.settings,
          downloads: widget.downloads,
          history: widget.history,
          library: widget.library,
          player: widget.player,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
        library: widget.library,
        player: widget.player,
        onVideoTap: (v) => widget.player.play(v),
        onSearchTap: _goSearch,
        onViewAllTrending: _goTrending,
      ),
      PlaylistsScreen(
        library: widget.library,
        storage: widget.storage,
        player: widget.player,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
      ),
      FavoritesScreen(
        library: widget.library,
        player: widget.player,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
      ),
      SettingsScreen(
        settings: widget.settings,
        storage: widget.storage,
        library: widget.library,
        onChanged: widget.onSettingsChanged,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: _buildNav(_index),
    );
  }

  Widget _buildNav(int visibleIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBlack,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                visibleIndex: visibleIndex,
              ),
              _navItem(
                icon: Icons.queue_music_outlined,
                activeIcon: Icons.queue_music,
                label: 'Playlists',
                index: 1,
                visibleIndex: visibleIndex,
              ),
              _centerPlayerButton(),
              _navItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: 'Favorites',
                index: 2,
                visibleIndex: visibleIndex,
              ),
              _navItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                index: 3,
                visibleIndex: visibleIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int visibleIndex,
  }) {
    final active = visibleIndex == index;
    final color = active ? AppTheme.primary : AppTheme.textGrey;
    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Center circular button: current video thumbnail, rotating while playing.
  Widget _centerPlayerButton() {
    return GestureDetector(
      onTap: _openPlayer,
      child: ListenableBuilder(
        listenable: widget.player,
        builder: (context, _) {
          final thumb = widget.player.current?.thumbnailUrl ?? '';
          final playing = widget.player.isPlaying &&
              widget.player.current != null;
          if (playing && !_spin.isAnimating) {
            _spin.repeat();
          } else if (!playing && _spin.isAnimating) {
            _spin.stop();
          }
          final art = ClipOval(
            child: thumb.isEmpty
                ? Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    width: 58,
                    height: 58,
                    errorWidget: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
          );
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: playing
                ? RotationTransition(turns: _spin, child: art)
                : art,
          );
        },
      ),
    );
  }
}

/// Push the watch screen for [video].
void openWatch(
  BuildContext context,
  VideoInfo video, {
  required SettingsService settings,
  required DownloadManager downloads,
  required HistoryService history,
  bool autoOpenDownload = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => WatchScreen(
        video: video,
        settings: settings,
        downloads: downloads,
        history: history,
        autoOpenDownload: autoOpenDownload,
      ),
    ),
  );
}

/// Push the downloads screen (used from player / menus).
void openDownloads(BuildContext context, DownloadManager downloads) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DownloadsScreen(downloads: downloads),
    ),
  );
}
