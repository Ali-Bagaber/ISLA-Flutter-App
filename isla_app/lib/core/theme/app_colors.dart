import 'package:flutter/material.dart';

class IslaColors {
  // Core
  static const background = Color(0xFF0C0E0F);
  static const surface = Color(0xFF0C0E0F);
  static const surfaceDim = Color(0xFF0C0E0F);
  static const surfaceContainer = Color(0xFF181A1B);
  static const surfaceContainerLow = Color(0xFF111415);
  static const surfaceContainerHigh = Color(0xFF1D2021);
  static const surfaceContainerHighest = Color(0xFF232628);
  static const surfaceBright = Color(0xFF2A2C2E);
  static const surfaceVariant = Color(0xFF232628);

  // Primary (Cyan)
  static const primary = Color(0xFF81ECFF);
  static const primaryFixed = Color(0xFF00E3FD);
  static const primaryFixedDim = Color(0xFF00D4EC);
  static const primaryDim = Color(0xFF00D4EC);
  static const primaryContainer = Color(0xFF00E3FD);
  static const onPrimary = Color(0xFF005762);
  static const onPrimaryContainer = Color(0xFF004D57);
  static const onPrimaryFixed = Color(0xFF003840);
  static const inversePrimary = Color(0xFF006976);

  // Tertiary (Blue)
  static const tertiary = Color(0xFF70AAFF);
  static const tertiaryDim = Color(0xFF5C9FFC);
  static const tertiaryFixed = Color(0xFF80B2FF);
  static const tertiaryFixedDim = Color(0xFF65A4FF);
  static const tertiaryContainer = Color(0xFF599CF9);
  static const onTertiary = Color(0xFF002A55);
  static const onTertiaryContainer = Color(0xFF001D3F);

  // Secondary
  static const secondary = Color(0xFFC9E8EF);
  static const secondaryFixed = Color(0xFFC9E8EF);
  static const secondaryFixedDim = Color(0xFFBBDAE0);
  static const secondaryDim = Color(0xFFBBDAE0);
  static const secondaryContainer = Color(0xFF2E4B51);
  static const onSecondary = Color(0xFF39565C);
  static const onSecondaryContainer = Color(0xFFB7D6DC);

  // Surface text
  static const onSurface = Color(0xFFF6F6F7);
  static const onSurfaceVariant = Color(0xFFAAABAC);
  static const onBackground = Color(0xFFF6F6F7);

  // Outline
  static const outline = Color(0xFF747577);
  static const outlineVariant = Color(0xFF464849);

  // Error
  static const error = Color(0xFFFF716C);
  static const errorContainer = Color(0xFF9F0519);
  static const errorDim = Color(0xFFD7383B);
  static const onError = Color(0xFF490006);
  static const onErrorContainer = Color(0xFFFFA8A3);

  // Misc
  static const inverseSurface = Color(0xFFF9F9FA);
  static const inverseOnSurface = Color(0xFF545556);
  static const surfaceTint = Color(0xFF81ECFF);

  // Gradients
  static const cyanToBlue = LinearGradient(
    colors: [primary, tertiary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
