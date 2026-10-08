import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The soft blue arcs behind all reference pages.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _CanvasPainter(), child: child);
}

class _CanvasPainter extends CustomPainter {
  const _CanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    canvas.drawOval(
      Rect.fromLTWH(-size.width * .9, -160, size.width * 2.4, 420),
      Paint()..color = const Color(0xFFF7FCFF),
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .2, 28, size.width * 1.7, 330),
      Paint()..color = const Color(0xFFEAF5FF).withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
