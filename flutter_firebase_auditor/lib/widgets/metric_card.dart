import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'glass_card.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? description;
  final Color? accentColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.description,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentColor != null)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimensions.radiusLg),
                    bottomLeft: Radius.circular(AppDimensions.radiusLg),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.textWhite),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
