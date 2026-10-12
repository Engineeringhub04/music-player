import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'models/video_info.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/watch_screen.dart';
import 'services/download_manager.dart';
import 'services/history_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.init();

  final downloads = DownloadManager();
  await downloads.init();

  final storage = StorageService();
  final history = HistoryService();
  await history.init();

  runApp(
    MusicPlayerApp(
      settings: settings,
      downloads: downloads,
      storage: storage,
      history: history,
    ),
  );
}

class MusicPlayerApp extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final StorageService storage;
  final HistoryService history;

  const MusicPlayerApp({
    super.key,
    required this.settings,
    required this.downloads,
    required this.storage,
    required this.history,
  });

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  @override
  Widget build(BuildContext context) {
    final dark = widget.settings.themeMode != 'light';
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: MainShell(
        settings: widget.settings,
        downloads: widget.downloads,
        storage: widget.storage,
        history: widget.history,
        onSettingsChanged: () => setState(() {}),
      ),
    );
  }
}

/// Bottom nav shell: Home / Search / Downloads / Library.
class MainShell extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final StorageService storage;
  final HistoryService history;
  final VoidCallback onSettingsChanged;

  const MainShell({
    super.key,
    required this.settings,
    required this.downloads,
    required this.storage,
    required this.history,
    required this.onSettingsChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  void _initShareReceiver() {
    // App opened via share while already running.
    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_onSharedMedia);
    // App cold-started via share.
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
            autoOpenDownload: true,
          );
        });
        break;
      }
    }
  }

  /// Pulls the first http(s) URL out of shared text.
  String? _extractUrl(String text) {
    final m = RegExp(r'https?://[^\s]+').firstMatch(text);
    return m?.group(0);
  }

  void _openVideo(VideoInfo video) {
    openWatch(
      context,
      video,
      settings: widget.settings,
      downloads: widget.downloads,
      history: widget.history,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(settings: widget.settings, onVideoTap: _openVideo),
      SearchScreen(
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
        onVideoTap: _openVideo,
      ),
      DownloadsScreen(downloads: widget.downloads),
      LibraryScreen(
        storage: widget.storage,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
        onSettingsChanged: widget.onSettingsChanged,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_outlined),
            activeIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Library',
          ),
        ],
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
