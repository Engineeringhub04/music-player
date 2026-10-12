import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// Shows the download quality picker for [video].
/// Loads formats via ApiClient.formats(), then enqueues the chosen format
/// through DownloadManager.enqueueDownload() using ApiClient.streamUrl().
Future<void> showDownloadSheet(
  BuildContext context, {
  required VideoInfo video,
  required SettingsService settings,
  required DownloadManager downloads,
  required HistoryService history,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => _DownloadSheet(
      video: video,
      settings: settings,
      downloads: downloads,
      history: history,
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  final VideoInfo video;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;

  const _DownloadSheet({
    required this.video,
    required this.settings,
    required this.downloads,
    required this.history,
  });

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  List<MediaFormat>? _formats;
  String? _error;
  String? _busyFormatId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final formats =
          await widget.settings.apiClient.formats(widget.video.videoUrl);
      if (!mounted) return;
      setState(() => _formats = formats);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load formats: $e');
    }
  }

  Future<void> _download(MediaFormat format) async {
    setState(() => _busyFormatId = format.formatId);
    try {
      final url = format.directUrl ??
          await widget.settings.apiClient
              .streamUrl(widget.video.videoUrl, format.formatId);
      final audio = !format.hasVideo;
      await widget.downloads.enqueueDownload(
        url: url,
        title:
            '${widget.video.title} [${format.label.isEmpty ? format.formatId : format.label}]',
        audio: audio,
        video: widget.video,
        requiresWiFi: widget.settings.wifiOnly,
        expectedBytes: format.fileSize,
      );
      await widget.history.addDownloaded(widget.video);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyFormatId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyFormatId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGrey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Download', style: AppText.title),
            const SizedBox(height: 4),
            Text(
              widget.video.title.isEmpty ? 'Untitled' : widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body,
            ),
            const SizedBox(height: 12),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _formats = null;
                });
                _load();
              },
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
    final formats = _formats;
    if (formats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    if (formats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No downloadable formats found.', style: AppText.body),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: formats.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppTheme.faint,
      ),
      itemBuilder: (c, i) {
        final f = formats[i];
        final busy = _busyFormatId == f.formatId;
        final label = f.label.isEmpty ? f.formatId : f.label;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            f.hasVideo ? Icons.videocam_outlined : Icons.audiotrack,
            color: AppTheme.primary,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: AppTheme.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${f.ext.toUpperCase()}${f.fileSize > 0 ? ' • ${formatBytes(f.fileSize)}' : ''}',
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
            ),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : const Icon(
                  Icons.download_outlined,
                  color: AppTheme.primary,
                ),
          onTap: busy ? null : () => _download(f),
        );
      },
    );
  }
}
