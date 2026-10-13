import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import 'app_widgets.dart';
import 'download_sheet.dart';
import 'glass_popup.dart';

/// Dependencies needed by the shared video context menu.
class VideoMenuDeps {
  final LibraryService library;
  final PlayerService player;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const VideoMenuDeps({
    required this.library,
    required this.player,
    required this.settings,
    required this.downloads,
    required this.history,
  });
}

/// Shows the reference-app glass popup for [video]:
/// Add to Favorites / Add to a Playlist.. / Download / Select Quality /
/// Play Related Mix. (No Share Link, per the reference.)
void showVideoMenu(
  BuildContext context,
  VideoInfo video, {
  required VideoMenuDeps deps,
  VoidCallback? onFavoriteChanged,
  BuildContext? anchorContext,
}) {
  showIosMenu(
    context,
    anchorContext: anchorContext,
    items: [
      GlassMenuItem(
        label: deps.library.isFavorite(video)
            ? 'Remove from Favorites'
            : 'Add to Favorites',
        icon: deps.library.isFavorite(video)
            ? Icons.favorite
            : Icons.favorite_border,
        onTap: () async {
          await deps.library.toggleFavorite(video);
          onFavoriteChanged?.call();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(deps.library.isFavorite(video)
                    ? 'Added to favorites.'
                    : 'Removed from favorites.'),
              ),
            );
          }
        },
      ),
      GlassMenuItem(
        label: 'Add to a Playlist..',
        icon: Icons.playlist_add,
        onTap: () {
          showAddToListSheet(
            context,
            library: deps.library,
            onPick: (p) async {
              await deps.library.addToPlaylist(p, video);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to ${p.name}.')),
                );
              }
            },
          );
        },
      ),
      GlassMenuItem(
        label: 'Download',
        icon: Icons.download_outlined,
        onTap: () => quickDownload(context, video, deps: deps),
      ),
      GlassMenuItem(
        label: 'Select Quality',
        icon: Icons.chevron_right,
        onTap: () {
          showDownloadSheet(
            context,
            video: video,
            settings: deps.settings,
            downloads: deps.downloads,
            history: deps.history,
          );
        },
      ),
      GlassMenuItem(
        label: isAudioSaved(deps.library, video.id)
            ? 'Audio Saved ✓'
            : 'Save to Audio (MP3)',
        icon: Icons.music_note_outlined,
        onTap: () => saveToAudio(context, video, deps: deps),
      ),
      GlassMenuItem(
        label: 'Play Related Mix',
        icon: Icons.radio_outlined,
        onTap: () => playRelatedMix(context, video, deps: deps),
      ),
    ],
  );
}

/// Enqueue the best format for [video] without asking (quick "Download").
Future<void> quickDownload(
  BuildContext context,
  VideoInfo video, {
  required VideoMenuDeps deps,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Preparing download…')),
  );
  try {
    final formats =
        await deps.settings.apiClient.formats(video.videoUrl);
    if (formats.isEmpty) throw const ApiException('No formats found.');
    final withVideo = formats.where((f) => f.hasVideo).toList();
    withVideo.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    final audioOnly = formats.where((f) => !f.hasVideo).toList();
    audioOnly.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    final best = withVideo.isNotEmpty ? withVideo.first : audioOnly.first;
    final url = best.directUrl ??
        await deps.settings.apiClient
            .streamUrl(video.videoUrl, best.formatId);
    await deps.downloads.enqueueDownload(
      url: url,
      title:
          '${video.title} [${best.label.isEmpty ? best.formatId : best.label}]',
      audio: !best.hasVideo,
      video: video,
      requiresWiFi: deps.settings.wifiOnly,
      expectedBytes: best.fileSize,
    );
    await deps.history.addDownloaded(video);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started.')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.message}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }
}

/// True when an MP3 was already saved for [videoId].
bool isAudioSaved(LibraryService library, String videoId) {
  if (videoId.isEmpty) return false;
  return library.localTracks
      .any((t) => t.isAudio && t.id == videoId);
}

/// Resolve the remote URL usable with the extractor for [video].
/// Remote videos use their URL directly; local downloads fall back to a
/// YouTube watch URL built from the video id.
String _sourceUrl(VideoInfo video) {
  if (!video.isLocal && video.videoUrl.isNotEmpty) return video.videoUrl;
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(video.id)) {
    return 'https://www.youtube.com/watch?v=${video.id}';
  }
  return '';
}

/// "Save to Audio (MP3)": download the best audio-only format as .mp3 and
/// register it in Local Music as an audio-only track.
Future<void> saveToAudio(
  BuildContext context,
  VideoInfo video, {
  required VideoMenuDeps deps,
}) async {
  if (isAudioSaved(deps.library, video.id)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already saved as MP3.')),
      );
    }
    return;
  }
  final sourceUrl = _sourceUrl(video);
  if (sourceUrl.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot find the original video.')),
      );
    }
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Preparing audio…')),
  );
  try {
    final formats = await deps.settings.apiClient.formats(sourceUrl);
    final audioOnly =
        formats.where((f) => f.hasAudio && !f.hasVideo).toList();
    if (audioOnly.isEmpty) {
      throw const ApiException('No audio format found.');
    }
    // Prefer m4a, then highest bitrate/size.
    audioOnly.sort((a, b) {
      final aM4a = a.ext.toLowerCase() == 'm4a' ? 0 : 1;
      final bM4a = b.ext.toLowerCase() == 'm4a' ? 0 : 1;
      if (aM4a != bM4a) return aM4a.compareTo(bM4a);
      return b.fileSize.compareTo(a.fileSize);
    });
    final best = audioOnly.first;
    final url = best.directUrl ??
        await deps.settings.apiClient.streamUrl(sourceUrl, best.formatId);
    // Registration id must stay the original video id so the "already
    // saved" check and Local Music matching keep working.
    final regVideo = VideoInfo(
      id: video.id,
      title: video.title,
      thumbnailUrl: video.thumbnailUrl,
      durationSecs: video.durationSecs,
      channelName: video.channelName,
      viewCount: video.viewCount,
      videoUrl: '',
      isLocal: true,
    );
    await deps.downloads.enqueueDownload(
      url: url,
      title: '${video.title} [MP3]',
      audio: true,
      fileExt: 'mp3',
      video: regVideo,
      requiresWiFi: deps.settings.wifiOnly,
      expectedBytes: best.fileSize,
    );
    await deps.history.addDownloaded(video);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving audio as MP3…')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio save failed: ${e.message}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio save failed: $e')),
      );
    }
  }
}

/// "Play Related Mix": search for similar videos and play them as a queue.
Future<void> playRelatedMix(
  BuildContext context,
  VideoInfo video, {
  required VideoMenuDeps deps,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Loading related mix…')),
  );
  try {
    final q = '${video.title} ${video.channelName}'.trim();
    final results =
        await deps.settings.apiClient.search(q, limit: 25);
    final mix =
        results.where((v) => v.videoUrl != video.videoUrl).toList();
    if (mix.isEmpty) throw const ApiException('No related videos found.');
    await deps.library.addRecent(video);
    await deps.player.playQueue([video, ...mix]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playing related mix.')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load mix: ${e.message}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load mix: $e')),
      );
    }
  }
}
