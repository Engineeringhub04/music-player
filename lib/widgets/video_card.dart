import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/video_info.dart';
import '../theme.dart';

/// 16:9 thumbnail card with duration badge, title, channel and views.
class VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;

  const VideoCard({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (video.channelName.isNotEmpty) video.channelName,
      if (video.viewCount > 0) '${formatCount(video.viewCount)} views',
    ].join(' • ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  video.thumbnailUrl.isEmpty
                      ? Container(
                          color: AppTheme.cardDark,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: AppTheme.textGrey,
                            size: 40,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, _) => Shimmer.fromColors(
                            baseColor: AppTheme.cardDark,
                            highlightColor: const Color(0xFF2A2A2A),
                            child: Container(color: AppTheme.cardDark),
                          ),
                          errorWidget: (c, _, _) => Container(
                            color: AppTheme.cardDark,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppTheme.textGrey,
                              size: 32,
                            ),
                          ),
                        ),
                  if (video.durationSecs > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatDuration(video.durationSecs),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            video.title.isEmpty ? 'Untitled' : video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal list row variant used by search results.
class VideoRow extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;

  const VideoRow({super.key, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (video.channelName.isNotEmpty) video.channelName,
      if (video.viewCount > 0) '${formatCount(video.viewCount)} views',
    ].join(' • ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 150,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      video.thumbnailUrl.isEmpty
                          ? Container(
                              color: AppTheme.cardDark,
                              child: const Icon(
                                Icons.play_circle_outline,
                                color: AppTheme.textGrey,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: video.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (c, _) => Shimmer.fromColors(
                                baseColor: AppTheme.cardDark,
                                highlightColor: const Color(0xFF2A2A2A),
                                child:
                                    Container(color: AppTheme.cardDark),
                              ),
                              errorWidget: (c, _, _) => Container(
                                color: AppTheme.cardDark,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                            ),
                      if (video.durationSecs > 0)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              formatDuration(video.durationSecs),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
