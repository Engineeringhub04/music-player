import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/video_card.dart';

/// Trending grid (2 columns), pull-to-refresh, error + empty states.
class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final void Function(VideoInfo video) onVideoTap;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onVideoTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<VideoInfo>? _videos;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await widget.settings.apiClient.trending();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
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
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: AppTheme.violet, size: 28),
            SizedBox(width: 8),
            Text(
              'Music Player',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.violet,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemCount: 8,
        itemBuilder: (c, _) => Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Icon(
            Icons.cloud_off_outlined,
            size: 64,
            color: AppTheme.textGrey,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    final videos = _videos ?? [];
    if (videos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: AppTheme.textGrey,
          ),
          SizedBox(height: 16),
          Text(
            'No trending videos right now.\nPull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey),
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: videos.length,
      itemBuilder: (c, i) => VideoCard(
        video: videos[i],
        onTap: () => widget.onVideoTap(videos[i]),
      ),
    );
  }
}
