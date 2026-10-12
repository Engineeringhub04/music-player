import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/download_sheet.dart';
import '../widgets/glass_popup.dart';
import '../widgets/video_menu.dart';

/// Player tab: real video on top, transport controls, and the action row.
/// Matches the reference app: cast + queue top-right, 16:9 video, progress
/// with times, title/artist, prev | -15 | play | +30 | next, "Next:" line,
/// then favorite | repeat | shuffle | sleep timer | more.
class PlayerScreen extends StatefulWidget {
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

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  Timer? _sleepTicker;

  PlayerService get player => widget.player;
  LibraryService get library => widget.library;

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSleepTimer() {
    const options = <Duration?>[
      null,
      Duration(minutes: 5),
      Duration(minutes: 10),
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(minutes: 45),
      Duration(hours: 1),
    ];
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Sleep Timer', style: AppText.title),
                  const Spacer(),
                  if (_sleepRemaining != null)
                    Text(
                      'Stops in ${_fmt(_sleepRemaining!)}',
                      style: AppText.body,
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (c, i) {
                  final o = options[i];
                  final label = o == null
                      ? 'Off'
                      : '${o.inMinutes} minutes';
                  final selected = (o == null && _sleepRemaining == null) ||
                      (o != null &&
                          _sleepRemaining != null &&
                          _sleepRemaining!.inMinutes == o.inMinutes);
                  return ListTile(
                    title: Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check,
                            color: AppTheme.primary)
                        : null,
                    onTap: () {
                      _setSleepTimer(o);
                      Navigator.of(c).pop();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    if (d == null) {
      setState(() => _sleepRemaining = null);
      return;
    }
    setState(() => _sleepRemaining = d);
    _sleepTicker =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _sleepRemaining = _sleepRemaining! - const Duration(seconds: 1);
        if (_sleepRemaining! <= Duration.zero) {
          _sleepRemaining = null;
        }
      });
    });
    _sleepTimer = Timer(d, () {
      _sleepTicker?.cancel();
      if (mounted) setState(() => _sleepRemaining = null);
      if (player.isPlaying) player.togglePlayPause();
    });
  }

  void _openMenu(VideoInfo video) {
    showVideoMenu(
      context,
      video,
      deps: VideoMenuDeps(
        library: library,
        player: player,
        settings: widget.settings,
        downloads: widget.downloads,
        history: widget.history,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: ListenableBuilder(
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
      ),
    );
  }

  Widget _playerBody(BuildContext context, VideoInfo video) {
    // Responsive sizing for small phones.
    final w = MediaQuery.of(context).size.width;
    final small = w < 360;
    final skipIcon = small ? 30.0 : 34.0;
    final playCircle = small ? 66.0 : 78.0;
    final playIcon = small ? 34.0 : 42.0;
    final actionIcon = small ? 24.0 : 27.0;

    final pos = player.position;
    final dur = player.duration;
    final maxMs =
        dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
    final curMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
    final next = player.nextTrack;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, small ? 12 : 20),
      children: [
        // Top row: (back handled by tab) ... cast + queue.
        Row(
          children: [
            const Spacer(),
            IconButton(
              tooltip: 'Cast',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cast is not available yet.'),
                  ),
                );
              },
              icon: Icon(Icons.cast, color: AppTheme.fg, size: 24),
            ),
            IconButton(
              tooltip: 'Queue',
              onPressed: () => _showQueue(context),
              icon: Icon(Icons.queue_music,
                  color: AppTheme.fg, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Video area (16:9).
        _videoArea(video, small),
        const SizedBox(height: 10),
        // Progress.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.faint,
            thumbColor: AppTheme.primary,
            overlayColor:
                AppTheme.primary.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: curMs,
            max: maxMs,
            onChanged: (v) =>
                player.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: AppText.body),
              Text(_fmt(dur), style: AppText.body),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (player.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          )
        else if (player.error != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              player.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13),
            ),
          ),
        // Title / artist.
        Text(
          video.title.isEmpty ? 'Untitled' : video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.fg,
            fontWeight: FontWeight.w700,
            fontSize: small ? 17 : 19,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          video.channelName.isEmpty
              ? 'Unknown artist'
              : video.channelName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.artist.copyWith(
              fontSize: small ? 14 : 15),
        ),
        SizedBox(height: small ? 10 : 16),
        // Transport controls.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed:
                  player.hasPrevious ? player.previous : null,
              icon: Icon(Icons.skip_previous,
                  color: AppTheme.fg, size: skipIcon),
            ),
            _SkipButton(
              seconds: -15,
              size: skipIcon,
              onTap: () =>
                  player.seekBy(const Duration(seconds: -15)),
            ),
            Container(
              width: playCircle,
              height: playCircle,
              margin:
                  const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: player.togglePlayPause,
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: playIcon,
                ),
              ),
            ),
            _SkipButton(
              seconds: 30,
              size: skipIcon,
              onTap: () =>
                  player.seekBy(const Duration(seconds: 30)),
            ),
            IconButton(
              onPressed:
                  player.hasNext ? () => player.next() : null,
              icon: Icon(Icons.skip_next,
                  color: AppTheme.fg, size: skipIcon),
            ),
          ],
        ),
        // Next line.
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: InkWell(
              onTap: () => player.next(),
              child: Text(
                'Next: ${next.title.isEmpty ? 'Untitled' : next.title}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 13),
              ),
            ),
          ),
        SizedBox(height: small ? 12 : 20),
        // Bottom action row.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      ? AppTheme.primary
                      : AppTheme.fg,
                  size: actionIcon,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Repeat',
              onPressed: player.toggleRepeat,
              icon: Icon(
                player.repeatOne
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: player.repeatOne
                    ? AppTheme.primary
                    : AppTheme.fg,
                size: actionIcon,
              ),
            ),
            IconButton(
              tooltip: 'Shuffle',
              onPressed: player.toggleShuffle,
              icon: Icon(
                Icons.shuffle,
                color: player.shuffle
                    ? AppTheme.primary
                    : AppTheme.fg,
                size: actionIcon,
              ),
            ),
            IconButton(
              tooltip: 'Sleep timer',
              onPressed: _showSleepTimer,
              icon: Icon(
                Icons.bedtime_outlined,
                color: _sleepRemaining != null
                    ? AppTheme.primary
                    : AppTheme.fg,
                size: actionIcon,
              ),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: () => _openMenu(video),
              icon: Icon(Icons.more_vert,
                  color: AppTheme.fg, size: actionIcon),
            ),
          ],
        ),
      ],
    );
  }

  /// 16:9 video area: real video when the video engine is active,
  /// thumbnail otherwise, spinner while loading.
  Widget _videoArea(VideoInfo video, bool small) {
    final c = player.videoController;
    final showVideo = player.videoMode &&
        c != null &&
        c.value.isInitialized;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: showVideo
              ? VideoPlayer(c)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    video.thumbnailUrl.isEmpty
                        ? Container(
                            color: AppTheme.card,
                            child: const Center(
                              child: Icon(
                                Icons.music_note,
                                color: AppTheme.primary,
                                size: 64,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.card,
                            ),
                            errorWidget: (_, __, ___) =>
                                Container(
                              color: AppTheme.card,
                              child: const Center(
                                child: Icon(
                                  Icons.music_note,
                                  color: AppTheme.primary,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                    if (player.videoLoading || player.loading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Up Next', style: AppText.title),
            ),
            Flexible(
              child: ListenableBuilder(
                listenable: player,
                builder: (c, _) => ListView.builder(
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
                                  color: AppTheme.card,
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
                              ? AppTheme.primary
                              : AppTheme.fg,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular -15 / +30 skip button like the reference app.
class _SkipButton extends StatelessWidget {
  final int seconds;
  final double size;
  final VoidCallback onTap;

  const _SkipButton({
    required this.seconds,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = seconds < 0 ? '${-seconds}' : '$seconds';
    final arrow = Icon(
      Icons.replay,
      color: AppTheme.fg,
      size: size + 6,
    );
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          // Flip for the clockwise (+seconds) direction.
          if (seconds < 0)
            arrow
          else
            Transform.flip(flipX: true, child: arrow),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.fg,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
