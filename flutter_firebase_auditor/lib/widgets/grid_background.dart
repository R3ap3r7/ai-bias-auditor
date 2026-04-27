import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class GridBackground extends StatefulWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  State<GridBackground> createState() => _GridBackgroundState();
}

class _GridBackgroundState extends State<GridBackground> with SingleTickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 768;

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: GridPainter()),
          ),
        ),
        AnimatedBuilder(
          animation: _blobController,
          builder: (context, child) {
            return Positioned(
              top: size.height * 0.15 + (sin(_blobController.value * pi) * 40),
              right: size.width * 0.1 + (cos(_blobController.value * pi) * 20),
              child: Container(
                width: compact ? 300 : 500,
                height: compact ? 300 : 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentPrimary.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentSecondary.withOpacity(0.1),
                      blurRadius: 100,
                      spreadRadius: 100,
                    )
                  ],
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;

    const spacing = 40.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
