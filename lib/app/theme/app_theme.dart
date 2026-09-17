import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette (Velocity Admin Design System) ──────────────────────────────
  static const Color _primary = Color(0xFFFFB693);
  static const Color _primaryContainer = Color(0xFFFF6B00);
  static const Color _onPrimaryContainer = Color(0xFF572000);
  static const Color _surface = Color(0xFF131313);
  static const Color _surfaceContainer = Color(0xFF201F1F);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color _surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color _surfaceContainerHighest = Color(0xFF353534);
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFE2BFB0);
  static const Color _outlineVariant = Color(0xFF5A4136);
  static const Color _outline = Color(0xFFA98A7D);
  static const Color _inputBackground = Color(0xFF050505);
  static const Color _error = Color(0xFFCF6679);
  static const Color _errorContainer = Color(0xFF93000A);
  static const Color _onErrorContainer = Color(0xFFFFDAD6);
  static const Color _secondaryContainer = Color(0xFFEA6B1E);
  static const Color _tertiaryContainer = Color(0xFFAF947C);
  static const Color _tertiary = Color(0xFFDFC1A8);

  // ── Public aliases ────────────────────────────────────────────────────────
  static const Color inputBackground = _inputBackground;
  static const Color surface = _surface;
  static const Color onSurface = _onSurface;
  static const Color surfaceContainerHigh = _surfaceContainerHigh;
  static const Color surfaceContainer = _surfaceContainer;
  static const Color surfaceContainerLow = _surfaceContainerLow;
  static const Color surfaceContainerLowest = _surfaceContainerLowest;
  static const Color surfaceContainerHighest = _surfaceContainerHighest;
  static const Color primaryContainer = _primaryContainer;
  static const Color onPrimaryContainer = _onPrimaryContainer;
  static const Color onSurfaceVariant = _onSurfaceVariant;
  static const Color outlineVariant = _outlineVariant;
  static const Color outline = _outline;
  static const Color errorContainer = _errorContainer;
  static const Color onErrorContainer = _onErrorContainer;
  static const Color secondaryContainer = _secondaryContainer;
  static const Color tertiaryContainer = _tertiaryContainer;
  static const Color tertiary = _tertiary;

  // ── Gradient Presets ──────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFD45900)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGlowGradient = LinearGradient(
    colors: [Color(0xFFFF6B00), Color(0xFFE65C00)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Decoration Helpers ────────────────────────────────────────────────────
  static BoxDecoration get glassCard => BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceContainerHigh.withValues(alpha: 0.5)),
      );

  static BoxDecoration get glassCardHover => glassCard.copyWith(
        border: Border.all(color: _primaryContainer.withValues(alpha: 0.3)),
      );

  static BoxDecoration get primaryGlowDecoration => BoxDecoration(
        gradient: primaryGlowGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primaryContainer.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.black,
      primaryContainer: _primaryContainer,
      onPrimaryContainer: _onPrimaryContainer,
      secondary: _onSurfaceVariant,
      onSecondary: Colors.black,
      secondaryContainer: _secondaryContainer,
      onSecondaryContainer: const Color(0xFF4B1B00),
      tertiary: _tertiary,
      onTertiary: Colors.black,
      tertiaryContainer: _tertiaryContainer,
      onTertiaryContainer: const Color(0xFF402D1B),
      surface: _surface,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceVariant,
      outlineVariant: _outlineVariant,
      outline: _outline,
      error: _error,
      onError: Colors.black,
      errorContainer: _errorContainer,
      onErrorContainer: _onErrorContainer,
      surfaceContainerLowest: _surfaceContainerLowest,
      surfaceContainerLow: _surfaceContainerLow,
      surfaceContainer: _surfaceContainer,
      surfaceContainerHigh: _surfaceContainerHigh,
      surfaceContainerHighest: _surfaceContainerHighest,
    );

    final textTheme = TextTheme(
      // ── Display / Headlines (Montserrat) ───────────────────────────────
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 48,
        height: 1.16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: _onSurface,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 40,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01,
        color: _onSurface,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: _onSurface,
      ),
      // ── Titles (Inter) ────────────────────────────────────────────────
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      // ── Body (Inter) ──────────────────────────────────────────────────
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: _onSurface,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: _onSurface,
      ),
      bodySmall: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: _onSurfaceVariant,
      ),
      // ── Labels (Montserrat - uppercase tracking) ──────────────────────
      labelLarge: GoogleFonts.spaceGrotesk(
        fontSize: 12,
        height: 1.3,
        letterSpacing: 0.05,
        fontWeight: FontWeight.w700,
        color: _onSurfaceVariant,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        height: 1.3,
        letterSpacing: 0.06,
        fontWeight: FontWeight.w700,
        color: _onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        height: 1.3,
        letterSpacing: 0.08,
        fontWeight: FontWeight.w700,
        color: _onSurfaceVariant,
      ),
    );

    return ThemeData(
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surface,
      textTheme: textTheme,

      // ── Icons ──────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: _onSurface, size: 24),

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _onSurface, size: 24),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _onSurface,
          letterSpacing: -0.2,
        ),
      ),

      // ── Inputs ─────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          color: _onSurfaceVariant.withValues(alpha: 0.4),
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: _onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryContainer, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
      ),

      // ── Elevated button ────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryContainer,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Filled button (IconButton.filled, etc.) ────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryContainer,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurfaceVariant,
          side: const BorderSide(color: _outlineVariant, width: 1),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text button ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryContainer,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryContainer,
        foregroundColor: _onPrimaryContainer,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Card ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _outlineVariant, width: 1),
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceContainerHigh,
        selectedColor: _secondaryContainer,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        side: const BorderSide(color: _outlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: _outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── BottomSheet ────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 0,
      ),

      // ── ListTile ───────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        subtitleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          color: _onSurfaceVariant,
        ),
        iconColor: _onSurfaceVariant,
      ),

      // ── TabBar ─────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: _primaryContainer,
        unselectedLabelColor: _onSurfaceVariant,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: _primaryContainer,
        dividerColor: _outlineVariant,
      ),

      // ── Switch ─────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return _onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _secondaryContainer;
          return _surfaceContainerHigh;
        }),
      ),

      // ── Slider ─────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryContainer,
        inactiveTrackColor: _surfaceContainerHigh,
        thumbColor: _primaryContainer,
        overlayColor: _primaryContainer.withValues(alpha: 0.1),
      ),

      // ── DataTable ─────────────────══════════════════════════════════════
      dataTableTheme: DataTableThemeData(
        headingTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: _onSurfaceVariant,
        ),
        dataTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: _onSurface,
        ),
        headingRowColor: WidgetStateProperty.all(_surfaceContainerHighest),
        dividerThickness: 1,
        horizontalMargin: 0,
        columnSpacing: 0,
      ),

      // ── Dialog ─────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _onSurface,
        ),
        contentTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          color: _onSurfaceVariant,
        ),
      ),

      // ── SnackBar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceContainer,
        contentTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 13,
          color: _onSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
