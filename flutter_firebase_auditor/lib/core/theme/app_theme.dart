import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'gradients.dart';
import 'shadows.dart';

class AppColors {
  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF18181B);
  static const surfaceElevated = Color(0xFF1C1C1F);
  static const border = Color(0xFF27272A);
  static const borderSubtle = Color(0xFF3F3F46);
  static const accentPrimary = Color(0xFF7C3AED);
  static const accentSecondary = Color(0xFF6D28D9);
  static const accentBlue = Color(0xFF2563EB);
  static const textPrimary = Color(0xFFE4E4E7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF71717A);
  static const textWhite = Color(0xFFFFFFFF);
  static const severityLow = Color(0xFF4ADE80);
  static const severityMedium = Color(0xFFFACC15);
  static const severityHigh = Color(0xFFFB923C);
  static const severityCritical = Color(0xFFF87171);
  static const severityLowBg = Color(0x2222C55E);
  static const severityMediumBg = Color(0x22EAB308);
  static const severityHighBg = Color(0x22F97316);
  static const severityCriticalBg = Color(0x22EF4444);
}

class AppDimensions {
  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 16.0;
  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;
  static const spacingXxl = 48.0;
}

class AppDecorations {
  static final glassCard = BoxDecoration(
    color: AppColors.surface,
    border: Border.all(color: AppColors.borderSubtle, width: 1.0),
    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
  );

  static final glassCardElevated = BoxDecoration(
    color: AppColors.surfaceElevated,
    border: Border.all(color: AppColors.border, width: 1.0),
    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
  );

  static final accentBorder = BoxDecoration(
    border: Border.all(color: AppColors.accentPrimary, width: 1.0),
    boxShadow: [AppShadows.accentGlow],
  );

  static final codePill = BoxDecoration(
    color: AppColors.border,
    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
  );
}

class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );
  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );
  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.05 * 12,
        color: AppColors.textMuted,
      );
  static TextStyle get codeMedium => GoogleFonts.sourceCodePro(
        fontSize: 13,
        color: AppColors.textPrimary,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelMedium: labelMedium,
      );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: AppTypography.textTheme,
      colorScheme: const ColorScheme.dark(
        background: AppColors.background,
        surface: AppColors.surface,
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentBlue,
        error: AppColors.severityCritical,
        onPrimary: AppColors.textWhite,
        onSecondary: AppColors.textWhite,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: AppColors.textWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textWhite,
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          side: const BorderSide(color: AppColors.accentPrimary),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.titleMedium,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textWhite,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accentPrimary,
        dividerColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
