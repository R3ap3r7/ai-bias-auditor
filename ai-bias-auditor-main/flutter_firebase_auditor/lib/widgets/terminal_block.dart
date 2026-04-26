import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TerminalSpan {
  final String text;
  final Color color;

  TerminalSpan(this.text, {this.color = Colors.white});
}

class TerminalBlock extends StatelessWidget {
  final List<List<TerminalSpan>> lines;

  const TerminalBlock({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBar(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) {
                return RichText(
                  text: TextSpan(
                    style: AppTypography.codeMedium,
                    children: line.map((span) => TextSpan(
                          text: span.text,
                          style: TextStyle(color: span.color),
                        )).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _dot(AppColors.severityCritical),
          const SizedBox(width: 8),
          _dot(AppColors.severityMedium),
          const SizedBox(width: 8),
          _dot(AppColors.severityLow),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
