import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'watch_screen.dart';

/// Built-in browser. When the page looks like a video (YouTube watch URL or a
/// direct mp4/m3u8 link), a floating button offers to open/download it.
class BrowserScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final void Function(VideoInfo video) onVideoTap;

  const BrowserScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.onVideoTap,
  });

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final _urlController = TextEditingController();
  String? _detectedUrl;
  bool _detectedDirectFile = false;
  String _pageTitle = '';
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            _inspectUrl(url);
            if (await _controller.canGoBack() != _canGoBack) {
              setState(() => _canGoBack = !_canGoBack);
            }
            // Scan page HTML for direct video file links after load.
            try {
              await _controller.runJavaScript(
                r'''
                (function() {
                  var els = document.querySelectorAll('a[href], video source, video');
                  for (var el of els) {
                    var u = el.href || el.src || '';
                    if (/\.(mp4|m3u8|webm)(\?|$)/i.test(u)) {
                      VideoFound.postMessage(u);
                      break;
                    }
                  }
                })();
                ''',
              );
              final title = await _controller.getTitle();
              if (mounted && title != null) {
                setState(() => _pageTitle = title);
              }
            } catch (_) {}
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _inspectUrl(url);
          },
          onNavigationRequest: (request) {
            _inspectUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'VideoFound',
        onMessageReceived: (msg) {
          _inspectUrl(msg.message, directFile: true);
        },
      )
      ..loadRequest(Uri.parse('https://www.youtube.com'));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _inspectUrl(String url, {bool directFile = false}) {
    final lower = url.toLowerCase();
    final isYouTube = lower.contains('youtube.com/watch') ||
        lower.contains('youtu.be/') ||
        lower.contains('youtube.com/shorts/');
    final isFile = directFile ||
        RegExp(r'\.(mp4|m3u8|webm|m4a|mp3)(\?|$)').hasMatch(lower);
    if (!mounted) return;
    if (isYouTube || isFile) {
      setState(() {
        _detectedUrl = url;
        _detectedDirectFile = isFile && !isYouTube;
      });
    }
  }

  void _go() {
    var text = _urlController.text.trim();
    if (text.isEmpty) return;
    if (!text.contains('://')) text = 'https://$text';
    _controller.loadRequest(Uri.parse(text));
  }

  Future<void> _onFabTap() async {
    final url = _detectedUrl;
    if (url == null) return;
    if (_detectedDirectFile) {
      final ext = RegExp(r'\.([a-z0-9]+)(\?|$)')
              .firstMatch(url.toLowerCase())
              ?.group(1) ??
          'mp4';
      final isAudio = ext == 'm4a' || ext == 'mp3';
      final title = _pageTitle.isEmpty ? 'Web video' : _pageTitle;
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.card,
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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Direct media file detected on this page.',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: isAudio ? 'Download Audio' : 'Download File',
                  icon: Icons.download_outlined,
                  onPressed: () async {
                    Navigator.of(c).pop();
                    try {
                      await widget.downloads.enqueueDownload(
                        url: url,
                        title: title,
                        audio: isAudio,
                        video: VideoInfo(
                          id: url,
                          title: title,
                          thumbnailUrl: '',
                          durationSecs: 0,
                          channelName: '',
                          viewCount: 0,
                          videoUrl: url,
                        ),
                        requiresWiFi: widget.settings.wifiOnly,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download started.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    } else {
      final video = VideoInfo(
        id: url,
        title: _pageTitle.isEmpty ? 'YouTube video' : _pageTitle,
        thumbnailUrl: '',
        durationSecs: 0,
        channelName: '',
        viewCount: 0,
        videoUrl: url,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WatchScreen(
            video: video,
            settings: widget.settings,
            downloads: widget.downloads,
            history: widget.history,
            autoOpenDownload: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _urlController,
          onSubmitted: (_) => _go(),
          textInputAction: TextInputAction.go,
          decoration: const InputDecoration(
            hintText: 'Enter URL...',
            border: InputBorder.none,
            filled: false,
          ),
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: !_canGoBack
                ? null
                : () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
      floatingActionButton: _detectedUrl == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _onFabTap,
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              label: Text(
                _detectedDirectFile ? 'Download file' : 'Get this video',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }
}
