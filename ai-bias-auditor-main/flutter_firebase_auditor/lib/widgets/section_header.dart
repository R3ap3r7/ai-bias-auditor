import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/gradients.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 2,
          decoration: BoxDecoration(
            gradient: AppGradients.accentGradient,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
