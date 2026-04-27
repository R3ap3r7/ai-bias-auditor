import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/gradients.dart';

class CustomTabBar extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<int> onTabChanged;

  const CustomTabBar({
    super.key,
    required this.labels,
    required this.onTabChanged,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.labels.length, (index) {
          final isSelected = _selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onTabChanged(index);
              },
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppGradients.accentGradient : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.labels[index],
                  style: AppTypography.titleMedium.copyWith(
                    color: isSelected ? AppColors.textWhite : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
