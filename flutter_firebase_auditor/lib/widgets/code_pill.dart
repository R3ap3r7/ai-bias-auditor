import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CodePill extends StatelessWidget {
  final String text;

  const CodePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.codePill,
      child: Text(
        text,
        style: AppTypography.codeMedium,
      ),
    );
  }
}
