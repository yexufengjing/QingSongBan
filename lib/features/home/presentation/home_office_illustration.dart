import 'package:flutter/material.dart';

/// A code-native version of the small office illustration in the home reference.
class HomeOfficeIllustration extends StatelessWidget {
  const HomeOfficeIllustration({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 116,
    height: 78,
    child: CustomPaint(painter: _OfficePainter()),
  );
}

class _OfficePainter extends CustomPainter {
  const _OfficePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 116, size.height / 78);
    final white = Paint()..color = Colors.white.withValues(alpha: .9);
    for (final cloud in const [
      (25.0, 28.0, 15.0),
      (41.0, 18.0, 17.0),
      (92.0, 29.0, 19.0),
      (109.0, 35.0, 15.0),
    ]) {
      canvas.drawCircle(Offset(cloud.$1, cloud.$2), cloud.$3, white);
    }
    canvas.drawOval(
      const Rect.fromLTWH(0, 68, 116, 10),
      Paint()..color = const Color(0xFFAFD5FA),
    );
    void building(
      double x,
      double y,
      double w,
      double h, {
      bool large = false,
    }) {
      final front = Rect.fromLTWH(x, y, w, h);
      canvas.drawRect(
        front,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF4FAFF), Color(0xFFB6DEFF)],
          ).createShader(front),
      );
      final side = Path()
        ..moveTo(x + w, y)
        ..lineTo(x + w + 9, y + 6)
        ..lineTo(x + w + 9, y + h)
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(
        side,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF60ABF8), Color(0xFF1C6BDC)],
          ).createShader(side.getBounds()),
      );
      final roof = Path()
        ..moveTo(x, y)
        ..lineTo(x + 9, y - 4)
        ..lineTo(x + w + 9, y + 2)
        ..lineTo(x + w, y + 6)
        ..close();
      canvas.drawPath(roof, white);
      final cols = large ? 4 : 3;
      final rows = large ? 7 : 4;
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + 3 + col * ((w - 4) / cols),
              y + 8 + row * ((h - 12) / rows),
              3,
              large ? 5 : 4,
            ),
            Paint()..color = const Color(0xFF2385EF),
          );
        }
      }
    }

    building(15, 40, 22, 33);
    building(82, 35, 19, 38);
    building(52, 10, 28, 63, large: true);
    canvas.drawRect(
      const Rect.fromLTWH(32, 56, 23, 17),
      Paint()..color = const Color(0xFFC7E6FF),
    );
    canvas.drawRect(
      const Rect.fromLTWH(37, 59, 14, 14),
      Paint()..color = const Color(0xFF318CED),
    );
    void tree(double x, double y, double scale) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y - 8 * scale),
          width: 13 * scale,
          height: 25 * scale,
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF97D77D), Color(0xFF25AD6C)],
          ).createShader(Rect.fromLTWH(x - 8, y - 24, 16, 26)),
      );
      canvas.drawLine(
        Offset(x, y - 10),
        Offset(x, y + 7),
        Paint()
          ..color = const Color(0xFF80664C)
          ..strokeWidth = 1.3,
      );
    }

    tree(8, 66, .8);
    tree(47, 69, .65);
    tree(109, 63, 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
