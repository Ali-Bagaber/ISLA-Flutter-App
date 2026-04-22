import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class IslaTheme {
  static TextTheme _buildTextTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      displayMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: onSurfaceVariant,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData get dark {
    final textTheme = _buildTextTheme(
      onSurface: IslaColors.onSurface,
      onSurfaceVariant: IslaColors.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: IslaColors.background,
      colorScheme: const ColorScheme.dark(
        primary: IslaColors.primary,
        onPrimary: IslaColors.onPrimary,
        primaryContainer: IslaColors.primaryContainer,
        onPrimaryContainer: IslaColors.onPrimaryContainer,
        secondary: IslaColors.secondary,
        onSecondary: IslaColors.onSecondary,
        tertiary: IslaColors.tertiary,
        onTertiary: IslaColors.onTertiary,
        error: IslaColors.error,
        onError: IslaColors.onError,
        surface: IslaColors.surface,
        onSurface: IslaColors.onSurface,
        surfaceContainerHighest: IslaColors.surfaceContainerHighest,
        outline: IslaColors.outline,
      ),
      textTheme: textTheme,
      dividerColor: IslaColors.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: IslaColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: IslaColors.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IslaColors.surfaceContainerLow.withValues(alpha: 0.85),
        hintStyle: GoogleFonts.inter(
          color: IslaColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IslaColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IslaColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IslaColors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IslaColors.primary,
          foregroundColor: IslaColors.onPrimaryContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: IslaColors.outlineVariant),
          foregroundColor: IslaColors.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: IslaColors.surfaceContainerLow.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: IslaColors.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: IslaColors.primary,
        foregroundColor: IslaColors.onPrimaryContainer,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IslaColors.surfaceContainerHigh;
          }
          return IslaColors.surfaceContainerHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IslaColors.primary;
          }
          return IslaColors.surfaceContainer;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        labelColor: IslaColors.primary,
        unselectedLabelColor: IslaColors.onSurfaceVariant,
        indicatorColor: IslaColors.primary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: IslaColors.surfaceContainer,
        selectedItemColor: IslaColors.primary,
        unselectedItemColor: IslaColors.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: IslaColors.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(color: IslaColors.onSurface),
      ),
    );
  }

  static ThemeData get light {
    const lightBackground = Color(0xFFF4FBFE);
    const lightSurface = Color(0xFFFFFFFF);
    const lightSurfaceLow = Color(0xFFF7FBFD);
    const lightSurfaceHigh = Color(0xFFEAF2F6);
    const lightSurfaceHighest = Color(0xFFDFEAF0);
    const lightOutline = Color(0xFFBCC8CF);
    const lightOutlineVariant = Color(0xFFD4DEE4);
    const lightOnSurface = Color(0xFF0F1A1F);
    const lightOnSurfaceVariant = Color(0xFF596770);
    const lightPrimary = Color(0xFF007E90);
    const lightPrimaryContainer = Color(0xFF9BEFFF);
    const lightOnPrimary = Color(0xFFFFFFFF);
    const lightOnPrimaryContainer = Color(0xFF00313A);

    final textTheme = _buildTextTheme(
      onSurface: lightOnSurface,
      onSurfaceVariant: lightOnSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: lightOnPrimaryContainer,
        secondary: Color(0xFF3E6670),
        onSecondary: Color(0xFFFFFFFF),
        tertiary: Color(0xFF316FBC),
        onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFFBA1A1A),
        onError: Color(0xFFFFFFFF),
        surface: lightSurface,
        onSurface: lightOnSurface,
        surfaceContainerHighest: lightSurfaceHighest,
        outline: lightOutline,
      ),
      textTheme: textTheme,
      dividerColor: lightOutlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: lightOnSurface,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceLow,
        hintStyle: GoogleFonts.inter(
          color: lightOnSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: lightOutlineVariant),
          foregroundColor: lightOnSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: lightOnPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightSurface;
          }
          return lightSurfaceHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightPrimary;
          }
          return lightSurfaceHigh;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        labelColor: lightPrimary,
        unselectedLabelColor: lightOnSurfaceVariant,
        indicatorColor: lightPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightOnSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightSurface,
        contentTextStyle: GoogleFonts.inter(color: lightOnSurface),
      ),
    );
  }
}
