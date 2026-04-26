import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final bool elevated;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool accentBorder;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.elevated = false,
    this.onTap,
    this.padding = const EdgeInsets.all(24),
    this.accentBorder = false,
    this.width,
    this.height,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final decoration = widget.accentBorder && _isHovered 
        ? AppDecorations.accentBorder.copyWith(
            color: widget.elevated ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          )
        : widget.elevated ? AppDecorations.glassCardElevated : AppDecorations.glassCard;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.width,
      height: widget.height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          splashColor: AppColors.accentPrimary.withOpacity(0.2),
          highlightColor: AppColors.accentPrimary.withOpacity(0.1),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.accentBorder && widget.onTap != null) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }
    return card;
  }
}
