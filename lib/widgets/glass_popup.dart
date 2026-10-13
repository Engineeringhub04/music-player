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
///
/// [anchorContext] should be the BuildContext of the 3-dot button that was
/// tapped — the menu opens right below/near it. When omitted, falls back to
/// the top-right corner (legacy behavior).
Future<void> showIosMenu(
  BuildContext context, {
  required List<GlassMenuItem> items,
  BuildContext? anchorContext,
}) {
  if (items.isEmpty) return Future.value();
  final position = _anchorRect(context, anchorContext);
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

/// Compute where the menu should appear: just below the tapped button,
/// right-aligned to it (like iOS). Falls back to top-right corner.
Rect _anchorRect(BuildContext context, BuildContext? anchorContext) {
  if (anchorContext != null) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      final size = box.size;
      // Menu is ~250px wide; right-align its trailing edge with the
      // button's trailing edge, open just below the button.
      const menuWidth = 250.0;
      final screenW = MediaQuery.of(context).size.width;
      var left = offset.dx + size.width - menuWidth;
      if (left < 8) left = 8;
      if (left + menuWidth > screenW - 8) left = screenW - menuWidth - 8;
      return Rect.fromLTWH(left, offset.dy + size.height + 4, 40, 40);
    }
  }
  final size = MediaQuery.of(context).size;
  return Rect.fromLTWH(size.width - 60, 90, 40, 40);
}

/// A 3-dot button that opens [items] in an iOS popup anchored to itself.
/// Use this for row/header 3-dot menus so the popup appears near the tap.
class IosMenuAnchor extends StatelessWidget {
  final List<GlassMenuItem> Function() itemsBuilder;
  final double iconSize;
  final Color? iconColor;
  final String? tooltip;

  const IosMenuAnchor({
    super.key,
    required this.itemsBuilder,
    this.iconSize = 20,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (btnCtx) => IconButton(
        tooltip: tooltip,
        onPressed: () => showIosMenu(
          context,
          anchorContext: btnCtx,
          items: itemsBuilder(),
        ),
        icon: Icon(
          Icons.more_vert,
          color: iconColor ?? Colors.grey,
          size: iconSize,
        ),
      ),
    );
  }
}
