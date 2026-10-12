import 'package:flutter/material.dart';

/// App-wide theme: dark AMOLED-first, violet primary.
class AppTheme {
  static const Color violet = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color scaffoldBlack = Color(0xFF000000);
  static const Color cardDark = Color(0xFF141414);
  static const Color cardLight = Color(0xFFF5F5F7);
  static const Color textGrey = Color(0xFF9CA3AF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBlack,
      colorScheme: const ColorScheme.dark(
        primary: violet,
        secondary: pink,
        surface: cardDark,
        onSurface: Colors.white,
      ),
      cardColor: cardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: scaffoldBlack,
        selectedItemColor: violet,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGrey),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: violet,
        secondary: pink,
        surface: cardLight,
        onSurface: Colors.black,
      ),
      cardColor: cardLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: violet,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGrey),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1F2937),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Big call-to-action button with the violet->pink gradient.
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
