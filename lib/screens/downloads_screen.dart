import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../theme.dart';

/// Active download queue (progress, speed, pause/resume/cancel) + completed.
class DownloadsScreen extends StatelessWidget {
  final DownloadManager downloads;

  const DownloadsScreen({super.key, required this.downloads});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downloads',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: downloads,
        builder: (context, _) {
          final active = downloads.active;
          final done = downloads.completed;
          if (active.isEmpty && done.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 56,
                    color: AppTheme.textGrey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No downloads yet.\nFind a video and tap Download.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                const _SectionTitle('Active'),
                const SizedBox(height: 8),
                ...active.map((e) => _ActiveTile(entry: e, manager: downloads)),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionTitle('Completed'),
                const SizedBox(height: 8),
                ...done.map((e) => _DoneTile(entry: e, manager: downloads)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppTheme.textGrey,
        ),
      );
}

class _ActiveTile extends StatelessWidget {
  final DownloadEntry entry;
  final DownloadManager manager;

  const _ActiveTile({required this.entry, required this.manager});

  @override
  Widget build(BuildContext context) {
    final pct = entry.progress < 0
        ? null
        : (entry.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    final speed = entry.speedMbps >= 0 && entry.status == DlStatus.running
        ? '${entry.speedMbps.toStringAsFixed(1)} MB/s'
        : null;
    final statusText = switch (entry.status) {
      DlStatus.queued => 'Queued',
      DlStatus.running =>
        '${pct ?? '—'}%${speed == null ? '' : ' • $speed'}',
      DlStatus.paused => 'Paused at ${pct ?? '—'}%',
      DlStatus.failed => entry.error ?? 'Failed',
      DlStatus.complete => 'Complete',
      DlStatus.canceled => 'Canceled',
    };
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    entry.audio ? Icons.audiotrack : Icons.videocam_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: entry.status == DlStatus.failed
                              ? Colors.redAccent
                              : AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: entry.progress < 0 ? null : entry.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.status == DlStatus.running ||
                    entry.status == DlStatus.queued)
                  IconButton(
                    tooltip: 'Pause',
                    icon: const Icon(Icons.pause_circle_outline),
                    onPressed: () => manager.pause(entry.taskId),
                  ),
                if (entry.status == DlStatus.paused ||
                    entry.status == DlStatus.failed)
                  IconButton(
                    tooltip: 'Resume',
                    icon: const Icon(
                      Icons.play_circle_outline,
                      color: AppTheme.primary,
                    ),
                    onPressed: () => manager.resume(entry.taskId),
                  ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.redAccent),
                  onPressed: () => manager.cancel(entry.taskId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneTile extends StatelessWidget {
  final DownloadEntry entry;
  final DownloadManager manager;

  const _DoneTile({required this.entry, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            entry.audio ? Icons.audiotrack : Icons.videocam_outlined,
            color: Colors.greenAccent,
          ),
        ),
        title: Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text(
          'Download complete',
          style: TextStyle(color: Colors.greenAccent, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: 'Dismiss',
          icon: const Icon(Icons.close, color: AppTheme.textGrey),
          onPressed: () => manager.dismiss(entry.taskId),
        ),
      ),
    );
  }
}
