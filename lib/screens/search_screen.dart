import 'dart:async';

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/video_card.dart';
import 'browser_screen.dart';
import 'playlist_screen.dart';

/// Search field with debounced live results.
class SearchScreen extends StatefulWidget {
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final void Function(VideoInfo video) onVideoTap;

  const SearchScreen({
    super.key,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.onVideoTap,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<VideoInfo>? _results;
  String? _error;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _runSearch(value.trim(), live: true);
    });
  }

  Future<void> _runSearch(String q, {bool live = false}) async {
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _searching = false;
        _query = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = live ? _error : null;
      _query = q;
    });
    try {
      final results =
          await widget.settings.apiClient.search(q, limit: live ? 10 : 25);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!live) _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        if (!live) _error = 'Search failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Playlist / URL',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(
                  settings: widget.settings,
                  downloads: widget.downloads,
                  history: widget.history,
                  onVideoTap: widget.onVideoTap,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Built-in browser',
            icon: const Icon(Icons.public),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BrowserScreen(
                  settings: widget.settings,
                  downloads: widget.downloads,
                  history: widget.history,
                  onVideoTap: widget.onVideoTap,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: (v) => _runSearch(v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search videos or music...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textGrey,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppTheme.textGrey),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      ),
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.violet),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 56,
                color: AppTheme.textGrey,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _runSearch(_query),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 56,
              color: AppTheme.textGrey,
            ),
            SizedBox(height: 12),
            Text(
              'Search for videos and music.\nResults appear as you type.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      );
    }
    if (results.isEmpty && !_searching) {
      return Center(
        child: Text(
          'No results for "$_query".',
          style: const TextStyle(color: AppTheme.textGrey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (c, i) => VideoRow(
        video: results[i],
        onTap: () => widget.onVideoTap(results[i]),
      ),
    );
  }
}
