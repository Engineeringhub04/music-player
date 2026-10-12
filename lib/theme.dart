import 'package:flutter/material.dart';

/// App-wide theme: dark AMOLED-first, violet primary.
/// Palette cloned from the reference music app, recolored to our violet.
class AppTheme {
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDim = Color(0xFF6D28D9);
  static const Color pink = Color(0xFFEC4899);

  /// Page background.
  static const Color scaffoldBlack = Color(0xFF0A0A0A);

  /// Card / surface color (rows, buttons, search bars).
  static const Color cardDark = Color(0xFF1E1B2E);
  static const Color cardLight = Color(0xFFF5F5F7);

  /// Muted grey text.
  static const Color textGrey = Color(0xFFB0B0B0);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [violet, violetDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBlack,
      colorScheme: const ColorScheme.dark(
        primary: violet,
        secondary: violet,
        surface: cardDark,
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
      dialogTheme: const DialogThemeData(backgroundColor: cardDark),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
    );
  }

  static ThemeData light() => dark(); // App is dark-only by design.
}

/// Explicit text styles — never rely on theme defaults for text color.
class AppText {
  static const TextStyle title = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.3,
  );
  static const TextStyle titleLarge = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 22,
  );
  static const TextStyle pageTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 20,
  );
  static const TextStyle artist = TextStyle(
    color: AppTheme.violet,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );
  static const TextStyle body = TextStyle(
    color: Color(0xFFB0B0B0),
    fontSize: 14,
  );
  static const TextStyle bodyWhite = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle hint = TextStyle(
    color: Color(0xFFB0B0B0),
    fontSize: 15,
  );
  static const TextStyle sectionTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 21,
  );
  static const TextStyle viewLink = TextStyle(
    color: AppTheme.violet,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );
  static const TextStyle navLabel = TextStyle(fontSize: 12);
}

/// Big call-to-action button with the violet gradient.
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
              color: AppTheme.violet.withValues(alpha: 0.35),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
