import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import '../services/download_manager.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Downloaded files grid with storage bar; tap plays in-app,
/// long-press opens play/share/rename/delete menu.
class LibraryScreen extends StatefulWidget {
  final StorageService storage;
  final SettingsService settings;
  final DownloadManager downloads;
  final HistoryService history;
  final VoidCallback onSettingsChanged;

  const LibraryScreen({
    super.key,
    required this.storage,
    required this.settings,
    required this.downloads,
    required this.history,
    required this.onSettingsChanged,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<StoredFile>? _files;
  int _totalBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final files = await widget.storage.listFiles();
    final total = await widget.storage.totalBytes();
    if (!mounted) return;
    setState(() {
      _files = files;
      _totalBytes = total;
      _loading = false;
    });
  }

  void _play(StoredFile f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LocalPlayerScreen(file: f),
      ),
    );
  }

  void _longPressMenu(StoredFile f) {
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
            ListTile(
              leading: const Icon(Icons.play_arrow, color: AppTheme.violet),
              title: const Text('Play'),
              onTap: () {
                Navigator.of(c).pop();
                _play(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () async {
                Navigator.of(c).pop();
                await widget.storage.share(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(c).pop();
                _renameDialog(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.of(c).pop();
                _deleteConfirm(f);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameDialog(StoredFile f) {
    final controller = TextEditingController(text: f.name);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.storage.rename(f, controller.text);
                if (c.mounted) Navigator.of(c).pop();
                _reload();
              } catch (e) {
                if (c.mounted) Navigator.of(c).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rename failed: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteConfirm(StoredFile f) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Delete file?'),
        content: Text(
          f.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.storage.delete(f);
              if (c.mounted) Navigator.of(c).pop();
              _reload();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(history: widget.history),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  settings: widget.settings,
                  storage: widget.storage,
                  onChanged: () {
                    widget.onSettingsChanged();
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.violet,
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.violet),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _storageBar(),
                  const SizedBox(height: 16),
                  if ((_files ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 56,
                            color: AppTheme.textGrey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No downloaded files yet.',
                            style:
                                TextStyle(color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _files!.length,
                      itemBuilder: (c, i) =>
                          _fileCard(_files![i]),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _storageBar() {
    return Card(
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storage_outlined,
                  color: AppTheme.violet,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Storage used',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  formatBytes(_totalBytes),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.violet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_files?.length ?? 0} files',
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileCard(StoredFile f) {
    return InkWell(
      onTap: () => _play(f),
      onLongPress: () => _longPressMenu(f),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    f.isAudio
                        ? Icons.audiotrack
                        : Icons.videocam_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              f.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatBytes(f.sizeBytes),
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays a downloaded local file (video or audio).
class _LocalPlayerScreen extends StatefulWidget {
  final StoredFile file;
  const _LocalPlayerScreen({required this.file});

  @override
  State<_LocalPlayerScreen> createState() => _LocalPlayerScreenState();
}

class _LocalPlayerScreenState extends State<_LocalPlayerScreen> {
  VideoPlayerController? _player;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final player = VideoPlayerController.file(widget.file.file);
      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _chewie = ChewieController(
          videoPlayerController: player,
          autoPlay: true,
          allowFullScreen: true,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not play file: $e');
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
              )
            : _chewie == null
                ? const CircularProgressIndicator(color: AppTheme.violet)
                : widget.file.isAudio
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              Icons.audiotrack,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 80,
                            child: Chewie(controller: _chewie!),
                          ),
                        ],
                      )
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Chewie(controller: _chewie!),
                      ),
      ),
    );
  }
}
