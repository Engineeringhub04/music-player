import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../theme.dart';

/// Rounded search bar like the reference app.
class SearchBarField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const SearchBarField({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.hint,
          prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// "Top Music Videos" + violet "View" link row.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewTap;

  const SectionHeader({super.key, required this.title, this.onViewTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle)),
        if (onViewTap != null)
          GestureDetector(
            onTap: onViewTap,
            child: const Padding(
              padding: EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Text('View', style: AppText.viewLink),
            ),
          ),
      ],
    );
  }
}

/// Horizontal video card: thumbnail, white 2-line title, violet artist,
/// download button overlay.
class VideoHCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final double width;

  const VideoHCard({
    super.key,
    required this.video,
    required this.onTap,
    required this.onDownload,
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _thumb(video.thumbnailUrl),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onDownload,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.download_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.title.isEmpty ? 'Untitled' : video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              video.channelName.isEmpty ? 'Unknown artist' : video.channelName,
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
              style: const TextStyle(
                color: Colors.white,
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

/// Song row: thumbnail, white title, violet artist, checkmark, 3-dot menu.
class SongRow extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback? onCheckToggle;
  final bool checked;

  const SongRow({
    super.key,
    required this.video,
    required this.onTap,
    required this.onMenu,
    this.onCheckToggle,
    this.checked = false,
  });

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
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
            if (onCheckToggle != null)
              IconButton(
                onPressed: onCheckToggle,
                icon: Icon(
                  checked
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color:
                      checked ? AppTheme.violet : AppTheme.textGrey,
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

/// Settings row: icon, white label, trailing widget / chevron.
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: iconColor ?? Colors.white, size: 24),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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

/// Playlist row card: thumbnail, name, 3-dot menu.
class PlaylistRowCard extends StatelessWidget {
  final String name;
  final String? thumbnailUrl;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const PlaylistRowCard({
    super.key,
    required this.name,
    this.thumbnailUrl,
    this.count = 0,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
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
                      color: AppTheme.violet.withValues(alpha: 0.25),
                      child: const Icon(
                        Icons.queue_music,
                        color: AppTheme.violet,
                        size: 28,
                      ),
                    ),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
          trailing: IconButton(
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

Widget _thumb(String url) {
  if (url.isEmpty) {
    return Container(
      color: AppTheme.cardDark,
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
      color: AppTheme.cardDark,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.violet,
          ),
        ),
      ),
    ),
    errorWidget: (_, __, ___) => Container(
      color: AppTheme.cardDark,
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
