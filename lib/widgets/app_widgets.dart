import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/library_service.dart';
import '../theme.dart';

/// Rounded search bar like the reference app:
/// 12px radius, subtle fill (#2C2C2E dark / #E8E8ED light),
/// search icon + auto clear (x) button, comfortable padding.
class SearchBarField extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final Widget? suffix;

  const SearchBarField({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.suffix,
  });

  @override
  State<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends State<SearchBarField> {
  late final TextEditingController _internal;
  TextEditingController get _controller =>
      widget.controller ?? _internal;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _internal = TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchBarField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  void _onTextChanged() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _internal.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.isLight
            ? const Color(0xFFE8E8ED)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: AppTheme.isLight ? Colors.black : Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppText.hint,
          prefixIcon: const Icon(
            Icons.search,
            color: AppTheme.textGrey,
            size: 22,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: widget.suffix ??
              (_hasText && !widget.readOnly
                  ? IconButton(
                      onPressed: _clear,
                      icon: const Icon(
                        Icons.cancel,
                        color: AppTheme.textGrey,
                        size: 20,
                      ),
                      splashRadius: 18,
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 13,
            horizontal: 4,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

/// "Top Music Videos" + pink "View All" link row.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewTap;
  final String viewLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onViewTap,
    this.viewLabel = 'View All',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle)),
        if (onViewTap != null)
          GestureDetector(
            onTap: onViewTap,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Text(viewLabel, style: AppText.viewLink),
            ),
          ),
      ],
    );
  }
}

/// Horizontal video card: thumbnail, white 2-line title, pink artist.
/// (Reference app has NO download button on home cards.)
class VideoHCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final double width;

  const VideoHCard({
    super.key,
    required this.video,
    required this.onTap,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _thumb(video.thumbnailUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.title.isEmpty ? 'Untitled' : video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.isLight ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              video.channelName.isEmpty
                  ? 'Unknown artist'
                  : video.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.artist,
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular artist image with name below.
class ArtistCircle extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback? onTap;

  const ArtistCircle({
    super.key,
    required this.name,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 110,
                height: 110,
                child: _thumb(imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.isLight ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Song row: 64px rounded thumbnail, white 2-line title, pink artist,
/// optional checkmark, 3-dot menu — matches the reference list rows.
class SongRow extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback? onCheckToggle;
  final bool checked;
  final bool showCheck;

  const SongRow({
    super.key,
    required this.video,
    required this.onTap,
    required this.onMenu,
    this.onCheckToggle,
    this.checked = false,
    this.showCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        AppTheme.isLight ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _thumb(video.thumbnailUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isEmpty ? 'Untitled' : video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.channelName.isEmpty
                              ? 'Unknown artist'
                              : video.channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.artist,
                        ),
                      ),
                      if (video.isAudio)
                        Container(
                          margin:
                              const EdgeInsets.only(left: 6),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MP3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (showCheck)
              IconButton(
                onPressed: onCheckToggle,
                icon: Icon(
                  checked
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: checked
                      ? AppTheme.primary
                      : AppTheme.textGrey,
                  size: 22,
                ),
              ),
            IconButton(
              onPressed: onMenu,
              icon: const Icon(
                Icons.more_vert,
                color: AppTheme.textGrey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings row: icon, label, trailing widget / chevron.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.isLight ? Colors.white : AppTheme.card;
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: iconColor ?? fg, size: 24),
          title: Text(
            title,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          trailing: trailing ??
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textGrey,
              ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Playlist row card: thumbnail, name, song count, 3-dot menu.
class PlaylistRowCard extends StatelessWidget {
  final String name;
  final String? thumbnailUrl;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final IconData fallbackIcon;

  const PlaylistRowCard({
    super.key,
    required this.name,
    this.thumbnailUrl,
    this.count = 0,
    required this.onTap,
    this.onMenu,
    this.fallbackIcon = Icons.queue_music,
  });

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.isLight ? Colors.white : AppTheme.card;
    final fg = AppTheme.isLight ? Colors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                  ? _thumb(thumbnailUrl!)
                  : Container(
                      color: AppTheme.primary
                          .withValues(alpha: 0.18),
                      child: Icon(
                        fallbackIcon,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            '$count songs',
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 13,
            ),
          ),
          trailing: onMenu == null
              ? null
              : IconButton(
                  onPressed: onMenu,
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppTheme.textGrey,
                  ),
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// "Add To List" bottom sheet from the reference app:
/// pink "Cancel" left, "Add To List" title center, pink "New List" right,
/// then playlist rows. Tapping a row calls [onPick].
Future<void> showAddToListSheet(
  BuildContext context, {
  required LibraryService library,
  required Future<void> Function(UserPlaylist playlist) onPick,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor:
        AppTheme.isLight ? Colors.white : AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Add To List',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.isLight
                          ? Colors.black
                          : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final name = await showIosPrompt(
                      c,
                      title: 'New Playlist',
                      placeholder: 'Playlist name',
                      okLabel: 'Create',
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      final created = await library
                          .createPlaylist(name.trim());
                      await onPick(created);
                    }
                    if (c.mounted) Navigator.of(c).pop();
                  },
                  child: const Text(
                    'New List',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListenableBuilder(
              listenable: library,
              builder: (c2, _) {
                final playlists = library.playlists;
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Text(
                      'No playlists yet.\nTap "New List" to create one.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: playlists.length,
                  itemBuilder: (c3, i) {
                    final p = playlists[i];
                    return _AddToListRow(
                      playlist: p,
                      onTap: () async {
                        await onPick(p);
                        if (c.mounted) Navigator.of(c).pop();
                      },
                    );
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

class _AddToListRow extends StatelessWidget {
  final UserPlaylist playlist;
  final VoidCallback onTap;

  const _AddToListRow({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rowBg = AppTheme.isLight
        ? AppTheme.cardLight
        : AppTheme.card;
    final fg =
        AppTheme.isLight ? Colors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 48,
              height: 48,
              child: playlist.videos.isNotEmpty &&
                      playlist.videos.first.thumbnailUrl.isNotEmpty
                  ? _thumb(playlist.videos.first.thumbnailUrl)
                  : Container(
                      color: AppTheme.primary
                          .withValues(alpha: 0.18),
                      child: const Icon(
                        Icons.queue_music,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
          ),
          title: Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          trailing: const Icon(
            Icons.more_vert,
            color: AppTheme.textGrey,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// iOS-style alert with a text field — used on BOTH platforms so Android
/// matches the reference app exactly.
Future<String?> showIosPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String placeholder = '',
  String okLabel = 'OK',
  String cancelLabel = 'Cancel',
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showCupertinoDialog<String>(
    context: context,
    builder: (c) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message),
          ],
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            autofocus: true,
            onSubmitted: (_) =>
                Navigator.of(c).pop(controller.text.trim()),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(c).pop(),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: CupertinoColors.systemPink),
          ),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () =>
              Navigator.of(c).pop(controller.text.trim()),
          child: Text(
            okLabel,
            style: const TextStyle(color: CupertinoColors.systemPink),
          ),
        ),
      ],
    ),
  );
}

/// iOS-style confirm dialog on both platforms.
Future<bool> showIosConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String okLabel = 'Delete',
  bool destructive = true,
}) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (c) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: CupertinoColors.systemPink),
          ),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(
            okLabel,
            style: const TextStyle(
                color: CupertinoColors.systemPink),
          ),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}

Widget _thumb(String url) {
  if (url.isEmpty) {
    return Container(
      color: AppTheme.isLight
          ? AppTheme.cardLight
          : AppTheme.card,
      child: const Center(
        child: Icon(
          Icons.music_note,
          color: AppTheme.textGrey,
          size: 32,
        ),
      ),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    placeholder: (_, __) => Container(
      color: AppTheme.isLight
          ? AppTheme.cardLight
          : AppTheme.card,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      ),
    ),
    errorWidget: (_, __, ___) => Container(
      color: AppTheme.isLight
          ? AppTheme.cardLight
          : AppTheme.card,
      child: const Center(
        child: Icon(
          Icons.music_note,
          color: AppTheme.textGrey,
          size: 32,
        ),
      ),
    ),
  );
}
