import 'package:flutter/material.dart';

/// App-wide theme: dark-first, iOS pink primary (#FF2D55).
/// Palette cloned from the reference music app (pink accent, near-black bg).
class AppTheme {
  /// iOS system pink — the app's primary accent.
  static const Color primary = Color(0xFFFF2D55);
  static const Color primaryDim = Color(0xFFD61F44);

  /// Page background (dark).
  static const Color scaffoldBlack = Color(0xFF0A0A0A);

  /// Dark surface / sheet color.
  static const Color surfaceDark = Color(0xFF1C1C1E);

  /// Card / row / search-bar color (dark).
  static const Color cardDark = Color(0xFF2C2C2E);
  static const Color cardLight = Color(0xFFF2F2F7);

  /// Muted grey text (readable on both themes).
  static const Color textGrey = Color(0xFF8E8E93);

  /// Set by the app root before building; drives [AppText].
  static bool isLight = false;

  /// Primary foreground (text/icon) color for the active theme.
  static Color get fg => isLight ? Colors.black : Colors.white;

  /// Page background for the active theme.
  static Color get scaffoldBg => isLight ? Colors.white : scaffoldBlack;

  /// Surface (sheets/dialogs) for the active theme.
  static Color get surface => isLight ? Colors.white : surfaceDark;

  /// Card/row fill for the active theme.
  static Color get card => isLight ? cardLight : cardDark;

  /// Faint overlay tint that works on both themes (for dividers, tracks).
  static Color get faint => isLight
      ? Colors.black.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.1);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBlack,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surfaceDark,
        onSurface: Colors.white,
      ),
      cardColor: cardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGrey),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surfaceDark),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: cardLight,
        onSurface: Colors.black,
      ),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGrey),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.black,
        iconColor: Colors.black,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }
}

/// Explicit text styles — never rely on theme defaults for text color.
/// These adapt to the active brightness via [AppTheme.isLight], which is why
/// they are getters (not consts): do NOT use them inside `const` widgets.
class AppText {
  static Color get _title => AppTheme.isLight ? Colors.black : Colors.white;

  static TextStyle get title => TextStyle(
        color: _title,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.3,
      );
  static TextStyle get titleLarge => TextStyle(
        color: _title,
        fontWeight: FontWeight.w800,
        fontSize: 22,
      );
  static TextStyle get pageTitle => TextStyle(
        color: _title,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      );
  static const TextStyle artist = TextStyle(
    color: AppTheme.primary,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );
  static const TextStyle body = TextStyle(
    color: Color(0xFF8E8E93),
    fontSize: 14,
  );
  static TextStyle get bodyWhite => TextStyle(
        color: _title,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );
  static const TextStyle hint = TextStyle(
    color: Color(0xFF8E8E93),
    fontSize: 15,
  );
  static TextStyle get sectionTitle => TextStyle(
        color: _title,
        fontWeight: FontWeight.w800,
        fontSize: 21,
      );
  static const TextStyle viewLink = TextStyle(
    color: AppTheme.primary,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );
  static const TextStyle navLabel = TextStyle(fontSize: 12);
}

/// Big call-to-action button with the pink gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 12 : 16,
                horizontal: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: compact ? 18 : 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ).copyWith(
                        fontSize: compact ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
