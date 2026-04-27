import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TheAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final List<Widget>? actions;

  const TheAppBar({super.key, this.showBack = false, this.actions});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.85),
            border: const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: showBack
                      ? InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back, color: AppColors.textMuted, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Home',
                                style: AppTypography.titleMedium.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hexagon, color: AppColors.textWhite, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Themis',
                              style: AppTypography.titleLarge.copyWith(color: AppColors.textWhite),
                            ),
                          ],
                        ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, color: AppColors.accentPrimary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Themis',
                        style: AppTypography.titleLarge.copyWith(color: AppColors.accentPrimary),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions ?? [],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}
