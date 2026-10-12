import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/video_card.dart';

/// Paste a playlist URL -> checkbox list of entries -> batch download.
/// A single video URL can be opened directly instead.
class PlaylistScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final void Function(VideoInfo video) onVideoTap;

  const PlaylistScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.onVideoTap,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final _urlController = TextEditingController();
  List<VideoInfo>? _entries;
  final Set<int> _checked = {};
  bool _loading = false;
  String? _error;
  bool _batchRunning = false;
  double _batchProgress = 0;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _looksLikeSingleVideo(String url) {
    final l = url.toLowerCase();
    return (l.contains('youtube.com/watch') ||
            l.contains('youtu.be/') ||
            l.contains('youtube.com/shorts/')) &&
        !l.contains('list=');
  }

  Future<void> _load() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (_looksLikeSingleVideo(url)) {
      widget.onVideoTap(VideoInfo(
        id: url,
        title: 'Shared video',
        thumbnailUrl: '',
        durationSecs: 0,
        channelName: '',
        viewCount: 0,
        videoUrl: url,
      ));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _entries = null;
      _checked.clear();
    });
    try {
      final entries = await widget.settings.apiClient.playlist(url);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _checked.addAll(List.generate(entries.length, (i) => i));
        _loading = false;
        if (entries.isEmpty) _error = 'No videos found in this playlist.';
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
        _error = 'Could not load playlist: $e';
        _loading = false;
      });
    }
  }

  Future<void> _downloadSelected() async {
    final entries = _entries;
    if (entries == null || _checked.isEmpty || _batchRunning) return;
    setState(() {
      _batchRunning = true;
      _batchProgress = 0;
    });
    final selected = _checked.map((i) => entries[i]).toList();
    var done = 0;
    var failed = 0;
    for (final video in selected) {
      try {
        final formats =
            await widget.settings.apiClient.formats(video.videoUrl);
        final withVideo = formats.where((f) => f.hasVideo).toList();
        final pool = withVideo.isEmpty ? formats : withVideo;
        if (pool.isEmpty) throw const ApiException('No formats.');
        pool.sort((a, b) =>
            _rank(b.label).compareTo(_rank(a.label)));
        final best = pool.first;
        final url = best.directUrl ??
            await widget.settings.apiClient
                .streamUrl(video.videoUrl, best.formatId);
        await widget.downloads.enqueueDownload(
          url: url,
          title: '${video.title} [${best.label}]',
          audio: false,
          video: video,
          requiresWiFi: widget.settings.wifiOnly,
        );
        await widget.history.addDownloaded(video);
        done++;
      } catch (_) {
        failed++;
      }
      if (mounted) {
        setState(() {
          _batchProgress = (done + failed) / selected.length;
        });
      }
    }
    if (!mounted) return;
    setState(() => _batchRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Queued $done download${done == 1 ? '' : 's'}'
          '${failed > 0 ? ', $failed failed' : ''}.',
        ),
      ),
    );
  }

  int _rank(String label) {
    final m = RegExp(r'(\d+)').firstMatch(label);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Playlist download',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      hintText: 'Paste playlist or video URL...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GradientButton(
                  label: 'Load',
                  icon: Icons.cloud_download_outlined,
                  compact: true,
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              color: AppTheme.primary,
              backgroundColor: Colors.transparent,
            ),
          if (_batchRunning)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Queueing downloads... '
                    '${(_batchProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _batchProgress,
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.faint,
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
          if ((_entries ?? []).isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _checked.clear()),
                          child: const Text('Clear all'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _checked.addAll(
                              List.generate(
                                  _entries!.length, (i) => i))),
                          child: const Text('Select all'),
                        ),
                        const Spacer(),
                        Text(
                          '${_checked.length} selected',
                          style: const TextStyle(
                              color: AppTheme.textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GradientButton(
                      label: _batchRunning
                          ? 'Queueing...'
                          : 'Download selected (${_checked.length})',
                      icon: Icons.download_outlined,
                      onPressed: _checked.isEmpty || _batchRunning
                          ? null
                          : _downloadSelected,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey),
          ),
        ),
      );
    }
    final entries = _entries;
    if (entries == null && !_loading) {
      return const Center(
        child: Text(
          'Paste a playlist link above,\nselect videos, download them all.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textGrey),
        ),
      );
    }
    if (entries == null) return const SizedBox();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (c, i) {
        final v = entries[i];
        return CheckboxListTile(
          value: _checked.contains(i),
          onChanged: (val) => setState(() {
            if (val == true) {
              _checked.add(i);
            } else {
              _checked.remove(i);
            }
          }),
          activeColor: AppTheme.primary,
          secondary: SizedBox(
            width: 120,
            child: VideoRow(
              video: v,
              onTap: () => widget.onVideoTap(v),
            ),
          ),
          title: Text(
            v.title.isEmpty ? 'Untitled' : v.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: v.durationSecs > 0
              ? Text(
                  formatDuration(v.durationSecs),
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                )
              : null,
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }
}
