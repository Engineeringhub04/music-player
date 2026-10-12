import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/download_sheet.dart';

/// Full-screen player: artwork, title/artist, seekbar, controls,
/// shuffle/repeat, download + favorite + queue.
class PlayerScreen extends StatelessWidget {
  final PlayerService player;
  final LibraryService library;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.library,
    required this.settings,
    required this.downloads,
    required this.history,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBlack,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final video = player.current;
          if (video == null) {
            return const Center(
              child: Text(
                'Nothing playing.\nPick a song from Home.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            );
          }
          return _playerBody(context, video);
        },
      ),
    );
  }

  Widget _playerBody(BuildContext context, VideoInfo video) {
    final pos = player.position;
    final dur = player.duration;
    final maxMs = dur.inMilliseconds > 0
        ? dur.inMilliseconds.toDouble()
        : 1.0;
    final curMs =
        pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // Artwork
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color:
                    AppTheme.violet.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: video.thumbnailUrl.isEmpty
                  ? Container(
                      color: AppTheme.cardDark,
                      child: const Center(
                        child: Icon(
                          Icons.music_note,
                          color: AppTheme.violet,
                          size: 80,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.cardDark,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.violet,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.cardDark,
                        child: const Center(
                          child: Icon(
                            Icons.music_note,
                            color: AppTheme.violet,
                            size: 80,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Title / artist
        Text(
          video.title.isEmpty ? 'Untitled' : video.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          video.channelName.isEmpty
              ? 'Unknown artist'
              : video.channelName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.artist.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (player.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.violet,
                ),
              ),
            ),
          )
        else if (player.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              player.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13),
            ),
          ),
        // Seekbar
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.violet,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppTheme.violet,
            overlayColor:
                AppTheme.violet.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: curMs,
            max: maxMs,
            onChanged: (v) =>
                player.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: AppText.body),
              Text(_fmt(dur), style: AppText.body),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: player.toggleShuffle,
              icon: Icon(
                Icons.shuffle,
                color: player.shuffle
                    ? AppTheme.violet
                    : AppTheme.textGrey,
                size: 26,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: player.hasPrevious
                  ? player.previous
                  : null,
              icon: const Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: player.togglePlayPause,
                iconSize: 44,
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed:
                  player.hasNext ? () => player.next() : null,
              icon: const Icon(
                Icons.skip_next,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: player.toggleRepeat,
              icon: Icon(
                player.repeatOne
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: player.repeatOne
                    ? AppTheme.violet
                    : AppTheme.textGrey,
                size: 26,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Actions: favorite / download / queue
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Favorite',
              onPressed: () =>
                  library.toggleFavorite(video),
              icon: ListenableBuilder(
                listenable: library,
                builder: (c, _) => Icon(
                  library.isFavorite(video)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: library.isFavorite(video)
                      ? AppTheme.violet
                      : Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              tooltip: 'Download',
              onPressed: () => showDownloadSheet(
                context,
                video: video,
                settings: settings,
                downloads: downloads,
                history: history,
              ),
              icon: const Icon(
                Icons.download_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              tooltip: 'Queue',
              onPressed: () => _showQueue(context),
              icon: const Icon(
                Icons.queue_music,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Up Next', style: AppText.title),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: player.queue.length,
                itemBuilder: (c, i) {
                  final v = player.queue[i];
                  final active = i == player.currentIndex;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: v.thumbnailUrl.isEmpty
                            ? Container(
                                color: AppTheme.cardDark,
                                child: const Icon(
                                  Icons.music_note,
                                  color: AppTheme.textGrey,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: v.thumbnailUrl,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    title: Text(
                      v.title.isEmpty ? 'Untitled' : v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppTheme.violet
                            : Colors.white,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      v.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body,
                    ),
                    onTap: () {
                      Navigator.of(c).pop();
                      player.play(v,
                          queue: player.queue);
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
}
