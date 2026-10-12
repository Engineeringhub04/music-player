import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/video_menu.dart';

/// Recently Played: every video the user played, newest first.
class RecentlyPlayedScreen extends StatelessWidget {
  final LibraryService library;
  final PlayerService player;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const RecentlyPlayedScreen({
    super.key,
    required this.library,
    required this.player,
    required this.settings,
    required this.downloads,
    required this.history,
  });

  void _play(BuildContext context, VideoInfo v) {
    library.addRecent(v);
    player.play(v, queue: library.recentlyPlayed);
  }

  @override
  Widget build(BuildContext context) {
    final deps = VideoMenuDeps(
      library: library,
      player: player,
      settings: settings,
      downloads: downloads,
      history: history,
    );
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return Scaffold(
      backgroundColor:
          AppTheme.isLight ? Colors.white : AppTheme.scaffoldBlack,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            final items = library.recentlyPlayed;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(4, 8, 8, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: fg),
                      ),
                      Expanded(
                        child: Text(
                          'Recently Played',
                          textAlign: TextAlign.center,
                          style: AppText.pageTitle,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'Nothing played yet.\nPlay a video and it will show up here.',
                            textAlign: TextAlign.center,
                            style: AppText.body,
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (c, i) {
                            final v = items[i];
                            return SongRow(
                              video: v,
                              onTap: () =>
                                  _play(context, v),
                              onMenu: () => showVideoMenu(
                                context,
                                v,
                                deps: deps,
                              ),
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
}
