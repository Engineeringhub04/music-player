import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// One row inside a [GlassPopup].
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

/// iPhone-style frosted-glass context menu.
/// White text left, icon right, grouped with dividers — like the reference app.
Future<void> showGlassPopup(
  BuildContext context, {
  required List<GlassMenuItem> items,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (c, _, __) => _GlassPopupDialog(items: items),
    transitionBuilder: (c, anim, _, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _GlassPopupDialog extends StatelessWidget {
  final List<GlassMenuItem> items;

  const _GlassPopupDialog({required this.items});

  @override
  Widget build(BuildContext context) {
    final textColor =
        AppTheme.isLight ? Colors.black : Colors.white;
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 96, right: 10, left: 60),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: AppTheme.isLight
                        ? Colors.white.withValues(alpha: 0.72)
                        : const Color(0xFF2C2C2E)
                            .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 0.6,
                            color: textColor.withValues(alpha: 0.14),
                            indent: 16,
                            endIndent: 0,
                          ),
                        _row(items[i], textColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(GlassMenuItem item, Color textColor) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.destructive
                        ? AppTheme.primary
                        : textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                item.icon,
                color: item.destructive
                    ? AppTheme.primary
                    : textColor.withValues(alpha: 0.92),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
