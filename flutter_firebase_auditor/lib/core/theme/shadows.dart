import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppShadows {
  static final BoxShadow accentGlow = BoxShadow(
    color: AppColors.accentPrimary.withOpacity(0.3),
    blurRadius: 20,
    offset: const Offset(0, 0),
  );

  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.2),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
}
