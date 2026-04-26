import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    final lower = severity.toLowerCase();
    if (lower == 'low' || lower == 'green') {
      bg = AppColors.severityLowBg;
      text = AppColors.severityLow;
      border = AppColors.severityLow.withOpacity(0.25);
    } else if (lower == 'medium' || lower == 'yellow') {
      bg = AppColors.severityMediumBg;
      text = AppColors.severityMedium;
      border = AppColors.severityMedium.withOpacity(0.25);
    } else if (lower == 'high' || lower == 'orange') {
      bg = AppColors.severityHighBg;
      text = AppColors.severityHigh;
      border = AppColors.severityHigh.withOpacity(0.25);
    } else if (lower == 'critical' || lower == 'red') {
      bg = AppColors.severityCriticalBg;
      text = AppColors.severityCritical;
      border = AppColors.severityCritical.withOpacity(0.25);
    } else {
      bg = Colors.white.withOpacity(0.06);
      text = AppColors.textSecondary;
      border = AppColors.border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity,
        style: AppTypography.labelMedium.copyWith(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
