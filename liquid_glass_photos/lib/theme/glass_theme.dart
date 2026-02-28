import 'package:flutter/material.dart';

/// Design tokens for the Liquid Glass aesthetic
class GlassColors {
  // Primary Backgrounds - iOS 26 Standard
  static const backgroundLight = Color(0xFFF5F5F7); // Apple off-white
  static const backgroundDark = Color(0xFF000000);  // True OLED black

  // Secondary Backgrounds (Cards / Sheets)
  static const secondaryLight = Color(0xFFFFFFFF);
  static const secondaryDark = Color(0xFF1C1C1E);

  // Grouped / Section Backgrounds
  static const groupedLight = Color(0xFFF2F2F7);
  static const groupedDark = Color(0xFF2C2C2E);

  // Accent Colors - Photos app specific
  static const accentBlue = Color(0xFF007AFF);    // System Blue
  static const accentCyan = Color(0xFF5AC8FA);    // Soft Cyan-Blue

  // Primary palette (kept for backward compatibility with legacy widgets if any)
  static const primary = accentBlue;
  static const secondary = Color(0xFF5E5CE6);
  static const tertiary = Color(0xFFFF375F);

  // Text Colors (iOS accurate hierarchy)
  static const textPrimaryLight = Color(0xFF000000);
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryLight = Color(0xFF6E6E73);
  static const textSecondaryDark = Color(0xFF8E8E93);
  static const textTertiaryLight = Color(0xFFAEAEB2);
  static const textTertiaryDark = Color(0xFF636366);

  // Glass / Liquid Glass Effects (iOS 26 opacities)
  static final glassLight = Colors.white.withValues(alpha: 0.72);
  static final glassDark = const Color(0xFF1C1C1E).withValues(alpha: 0.72);
  static final glassElevatedLight = Colors.white.withValues(alpha: 0.85);
  static final glassElevatedDark = const Color(0xFF2C2C2E).withValues(alpha: 0.85);

  // Separators & Borders (ultra subtle)
  static const separatorLight = Color(0xFFC6C6C8);
  static const separatorDark = Color(0xFF3A3A3C);

  // Legacy compatibility tokens
  static final glassWhite10 = Colors.white.withValues(alpha: 0.10);
  static const surfaceDark = backgroundDark;
  static const surfaceLight = backgroundLight;
  static const surfaceLightDim = groupedLight;
  static const surfaceContainer = secondaryDark;
  static final glassWhite20 = Colors.white.withValues(alpha: 0.20);
  static final glassWhite40 = Colors.white.withValues(alpha: 0.40);
  static final glassWhite60 = Colors.white.withValues(alpha: 0.60);

  // Background helper
  static List<Color> ios26Background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark 
        ? [backgroundDark, backgroundDark] 
        : [backgroundLight, backgroundLight];
  }

  // ⚡️ HELPER: Dynamic surface color
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? surfaceDark 
        : surfaceLight;
  }
}

class GlassTokens {
  static const double cornerRadius = 36.0;
  static const double cornerRadiusSmall = 24.0;
  static const double distortion = 0.15;
  static const double blurStandard = 25.0; // Optimized for iOS 26 vibe
  static const double magnification = 1.05;
  
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 20.0;
  static const double radiusLarge = 28.0;
  static const double blurLarge = 30.0;
  static const double borderThin = 0.5;
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationFluid = Duration(milliseconds: 600);
}

class GlassTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? GlassColors.backgroundDark : GlassColors.backgroundLight,
      colorScheme: isDark 
        ? const ColorScheme.dark(
            primary: GlassColors.accentBlue,
            onSurface: GlassColors.textPrimaryDark,
            surface: GlassColors.secondaryDark,
            onSurfaceVariant: GlassColors.textSecondaryDark,
            outline: GlassColors.separatorDark,
          )
        : const ColorScheme.light(
            primary: GlassColors.accentBlue,
            onSurface: GlassColors.textPrimaryLight,
            surface: GlassColors.secondaryLight,
            onSurfaceVariant: GlassColors.textSecondaryLight,
            outline: GlassColors.separatorLight,
          ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontWeight: FontWeight.w200, fontSize: 64),
        headlineLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 32),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 28),
        titleLarge: const TextStyle(fontWeight: FontWeight.w500, fontSize: 22),
        bodyLarge: TextStyle(
          color: isDark ? GlassColors.textPrimaryDark : GlassColors.textPrimaryLight,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: isDark ? GlassColors.textSecondaryDark : GlassColors.textSecondaryLight,
          fontSize: 14,
        ),
      ),
    );
  }
}
