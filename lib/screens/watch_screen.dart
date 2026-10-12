import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// Video playback with quality selection and download actions.
class WatchScreen extends StatefulWidget {
  final VideoInfo video;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final bool autoOpenDownload;

  const WatchScreen({
    super.key,
    required this.video,
    required this.settings,
    required this.downloads,
    required this.history,
    this.autoOpenDownload = false,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  VideoPlayerController? _player;
  ChewieController? _chewie;
  List<MediaFormat> _formats = [];
  MediaFormat? _selected;
  String? _error;
  bool _resolvingStream = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    widget.history.addWatched(widget.video);
    _loadFormats();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadFormats() async {
    try {
      final formats =
          await widget.settings.apiClient.formats(widget.video.videoUrl);
      if (!mounted) return;
      setState(() {
        _formats = formats;
      });
      final initial = _pickInitialFormat(formats);
      if (initial != null) {
        await _playFormat(initial);
      } else if (mounted) {
        setState(() => _error = 'No playable formats found.');
      }
      if (widget.autoOpenDownload && mounted) {
        _openDownloadSheet();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load video: $e';
      });
    }
  }

  MediaFormat? _pickInitialFormat(List<MediaFormat> formats) {
    if (formats.isEmpty) return null;
    final withVideo = formats.where((f) => f.hasVideo).toList();
    final pool = withVideo.isEmpty ? formats : withVideo;
    final pref = widget.settings.defaultQuality.toLowerCase();
    if (pref != 'best') {
      for (final f in pool) {
        if (f.label.toLowerCase().contains(pref)) return f;
      }
    }
    // Best: largest video format by label heuristic, else first.
    pool.sort((a, b) => _qualityRank(b.label).compareTo(_qualityRank(a.label)));
    return pool.first;
  }

  int _qualityRank(String label) {
    final m = RegExp(r'(\d+)').firstMatch(label);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  Future<void> _playFormat(MediaFormat format) async {
    if (_resolvingStream) return;
    setState(() {
      _resolvingStream = true;
      _error = null;
    });
    try {
      final url = format.directUrl ??
          await widget.settings.apiClient
              .streamUrl(widget.video.videoUrl, format.formatId);
      if (!mounted) return;
      final oldChewie = _chewie;
      final oldPlayer = _player;
      _chewie = null;
      _player = null;
      final player = VideoPlayerController.networkUrl(Uri.parse(url));
      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: player,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
      );
      oldChewie?.dispose();
      oldPlayer?.dispose();
      setState(() {
        _player = player;
        _chewie = chewie;
        _selected = format;
        _resolvingStream = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _resolvingStream = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not play this quality: $e';
        _resolvingStream = false;
      });
    }
  }

  MediaFormat? _bestAudioFormat() {
    final audio = _formats.where((f) => !f.hasVideo).toList();
    if (audio.isEmpty) return null;
    audio.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    return audio.firstWhere(
      (f) => f.ext == 'm4a',
      orElse: () => audio.first,
    );
  }

  Future<String> _downloadUrlFor(MediaFormat format) async {
    return format.directUrl ??
        await widget.settings.apiClient
            .streamUrl(widget.video.videoUrl, format.formatId);
  }

  Future<void> _downloadVideo() async {
    final format = _selected;
    if (format == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final url = await _downloadUrlFor(format);
      await widget.downloads.enqueueDownload(
        url: url,
        title: '${widget.video.title} [${format.label}]',
        audio: false,
        requiresWiFi: widget.settings.wifiOnly,
      );
      await widget.history.addDownloaded(widget.video);
      if (!mounted) return;
      Navigator.of(context).pop(); // close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadAudio() async {
    if (_downloading) return;
    final audio = _bestAudioFormat();
    if (audio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio format available.')),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      final url = await _downloadUrlFor(audio);
      await widget.downloads.enqueueDownload(
        url: url,
        title: '${widget.video.title} [MP3]',
        audio: true,
        requiresWiFi: widget.settings.wifiOnly,
      );
      await widget.history.addDownloaded(widget.video);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MP3 download started.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Quality',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _formats.length,
                itemBuilder: (c, i) {
                  final f = _formats[i];
                  final selected = f.formatId == _selected?.formatId;
                  return ListTile(
                    leading: Icon(
                      f.hasVideo ? Icons.videocam_outlined : Icons.audiotrack,
                      color: selected ? AppTheme.primary : AppTheme.textGrey,
                    ),
                    title: Text(
                      f.label.isEmpty ? f.formatId : f.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    subtitle: f.fileSize > 0
                        ? Text(formatBytes(f.fileSize))
                        : null,
                    trailing: selected
                        ? const Icon(Icons.check, color: AppTheme.primary)
                        : null,
                    onTap: () {
                      Navigator.of(c).pop();
                      _playFormat(f);
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

  void _openDownloadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quality: ${_selected?.label ?? '—'}',
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: _downloading ? 'Starting...' : 'Download Video',
                icon: Icons.video_library_outlined,
                onPressed: _downloading ? null : _downloadVideo,
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: _downloading ? 'Starting...' : 'Download MP3',
                icon: Icons.audiotrack,
                onPressed: _downloading ? null : _downloadAudio,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (widget.video.channelName.isNotEmpty) widget.video.channelName,
      if (widget.video.viewCount > 0)
        '${formatCount(widget.video.viewCount)} views',
      if (widget.video.durationSecs > 0)
        formatDuration(widget.video.durationSecs),
    ].join(' • ');
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildPlayer(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title.isEmpty
                      ? 'Untitled'
                      : widget.video.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _formats.isEmpty ? null : _openQualitySheet,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: Text(_selected?.label ?? 'Quality'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.primary),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: 'Download',
                        icon: Icons.download_outlined,
                        compact: true,
                        onPressed: _openDownloadSheet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (_error != null && _chewie == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.textGrey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadFormats,
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
    if (_chewie == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 12),
            Text(
              'Loading video...',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Chewie(controller: _chewie!),
        if (_resolvingStream)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
      ],
    );
  }
}
