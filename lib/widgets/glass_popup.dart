import 'package:flutter/material.dart';
import 'package:pull_down_button/pull_down_button.dart';

/// One row inside an iOS popup menu.
class GlassMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const GlassMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

/// Shows the REAL iOS pull-down menu (pull_down_button package):
/// compact (~250px), frosted glass, title left / icon right — exactly like
/// the reference iPhone app. Always iOS style, on Android too.
Future<void> showIosMenu(
  BuildContext context, {
  required List<GlassMenuItem> items,
}) {
  if (items.isEmpty) return Future.value();
  final size = MediaQuery.of(context).size;
  // Anchor top-right, like the reference app's popup.
  final position = Rect.fromLTWH(size.width - 60, 90, 40, 40);
  return showPullDownMenu(
    context: context,
    position: position,
    items: [
      for (final item in items)
        PullDownMenuItem(
          title: item.label,
          icon: item.icon,
          isDestructive: item.destructive,
          onTap: item.onTap,
        ),
    ],
  );
}
