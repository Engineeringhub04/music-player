import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../theme.dart';
import '../widgets/app_widgets.dart';
import 'playlist_detail_screen.dart';

/// Playlists: title + add, search, Create New / Recently Played cards,
/// playlist rows.
class PlaylistsScreen extends StatefulWidget {
  final LibraryService library;

  const PlaylistsScreen({super.key, required this.library});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  String _query = '';

  void _openPlaylist(UserPlaylist p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlist: p,
          library: widget.library,
        ),
      ),
    );
  }

  Future<void> _createDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'New Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(c).pop(controller.text.trim()),
            child: const Text(
              'Create',
              style: TextStyle(color: AppTheme.violet),
            ),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.library.createPlaylist(name);
    }
  }

  void _playlistMenu(UserPlaylist p) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.play_arrow, color: AppTheme.violet),
              title: const Text(
                'Play',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(c).pop();
                _openPlaylist(p);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.drive_file_rename_outline,
                color: Colors.white,
              ),
              title: const Text(
                'Rename',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.of(c).pop();
                final controller =
                    TextEditingController(text: p.name);
                final name = await showDialog<String>(
                  context: context,
                  builder: (cc) => AlertDialog(
                    backgroundColor: AppTheme.cardDark,
                    title: const Text(
                      'Rename Playlist',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      style:
                          const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: 'Playlist name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(cc).pop(),
                        child: const Text(
                          'Cancel',
                          style:
                              TextStyle(color: AppTheme.textGrey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(cc)
                            .pop(controller.text.trim()),
                        child: const Text(
                          'Save',
                          style:
                              TextStyle(color: AppTheme.violet),
                        ),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  await widget.library.renamePlaylist(p, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.of(c).pop();
                await widget.library.deletePlaylist(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBlack,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (context, _) {
            final playlists = widget.library.playlists
                .where((p) => p.name
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Center(
                        child:
                            Text('Playlists', style: AppText.pageTitle),
                      ),
                    ),
                    IconButton(
                      onPressed: _createDialog,
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SearchBarField(
                  hint: 'Search',
                  onChanged: (v) =>
                      setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _actionCard(
                        icon: Icons.add_circle_outline,
                        label: 'Create New Playlist',
                        onTap: _createDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _actionCard(
                        icon: Icons.watch_later_outlined,
                        label: 'Recently Played',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...playlists.map(
                  (p) => PlaylistRowCard(
                    name: p.name,
                    thumbnailUrl: p.videos.isNotEmpty
                        ? p.videos.first.thumbnailUrl
                        : null,
                    count: p.videos.length,
                    onTap: () => _openPlaylist(p),
                    onMenu: () => _playlistMenu(p),
                  ),
                ),
                if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      'No playlists yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
