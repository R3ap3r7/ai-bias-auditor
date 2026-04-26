import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/gradients.dart';
import '../core/theme/shadows.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isDisabled ? null : AppGradients.accentGradient,
          color: isDisabled ? AppColors.surfaceElevated : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: _isHovered && !isDisabled ? [AppShadows.accentGlow] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingLg,
                vertical: AppDimensions.spacingMd,
              ),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
          strokeWidth: 2,
        ),
      );
    }

    Widget textWidget = Text(
      widget.text,
      style: AppTypography.titleMedium.copyWith(color: widget.onPressed == null ? AppColors.textMuted : AppColors.textWhite),
    );

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: widget.onPressed == null ? AppColors.textMuted : AppColors.textWhite, size: 18),
            child: widget.icon!,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          textWidget,
        ],
      );
    }

    return textWidget;
  }
}

class OutlinedAccentButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;

  const OutlinedAccentButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  State<OutlinedAccentButton> createState() => _OutlinedAccentButtonState();
}

class _OutlinedAccentButtonState extends State<OutlinedAccentButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHovered && !isDisabled ? AppColors.accentPrimary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isDisabled ? AppColors.borderSubtle : AppColors.accentPrimary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingLg,
                vertical: AppDimensions.spacingMd,
              ),
              child: _buildContent(isDisabled),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDisabled) {
    Widget textWidget = Text(
      widget.text,
      style: AppTypography.titleMedium.copyWith(color: isDisabled ? AppColors.textMuted : AppColors.accentPrimary),
    );

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: isDisabled ? AppColors.textMuted : AppColors.accentPrimary, size: 18),
            child: widget.icon!,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          textWidget,
        ],
      );
    }

    return textWidget;
  }
}
