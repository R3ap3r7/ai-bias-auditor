import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppGradients {
  static const LinearGradient accentGradient = LinearGradient(
    colors: [AppColors.accentPrimary, AppColors.accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(135 * 3.1415927 / 180),
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D0D1A), AppColors.background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
