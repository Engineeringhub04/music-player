import 'package:flutter/material.dart';

import '../services/history_service.dart';
import '../theme.dart';

/// Two tabs: Watched / Downloaded.
class HistoryScreen extends StatefulWidget {
  final HistoryService history;

  const HistoryScreen({super.key, required this.history});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'History',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.fg,
            unselectedLabelColor: AppTheme.textGrey,
            tabs: [
              Tab(text: 'Watched'),
              Tab(text: 'Downloaded'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _list(
              widget.history.watched,
              empty: 'No watched videos yet.',
              onClear: () async {
                await widget.history.clearWatched();
                setState(() {});
              },
            ),
            _list(
              widget.history.downloaded,
              empty: 'No downloads recorded yet.',
              onClear: () async {
                await widget.history.clearDownloaded();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    List<HistoryEntry> entries, {
    required String empty,
    required Future<void> Function() onClear,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          empty,
          style: const TextStyle(color: AppTheme.textGrey),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final e = entries[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.primary,
                  ),
                ),
                title: Text(
                  e.title.isEmpty ? 'Untitled' : e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _timeAgo(e.at),
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: const Text('Clear history?'),
                  content: const Text(
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(true),
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) await onClear();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}
