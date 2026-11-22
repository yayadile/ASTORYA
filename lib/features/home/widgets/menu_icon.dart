import 'package:flutter/material.dart';

import '../home_config.dart';

/// The four custom Main Menu icons, translated path-for-path from
/// src/components/MenuIcons.tsx (SVG viewBox 28 x 28).
class MenuIcon extends StatelessWidget {
  const MenuIcon({
    super.key,
    required this.id,
    this.size = HomeConfig.iconSize,
    this.color = HomeConfig.iconColor,
  });

  final MenuButtonId id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _MenuIconPainter(id: id, color: color)),
      ),
    );
  }
}

class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter({required this.id, required this.color});

  final MenuButtonId id;
  final Color color;

  Paint _fill() => Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true
    ..color = color;

  Paint _stroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / HomeConfig.iconViewBox,
        size.height / HomeConfig.iconViewBox);
    switch (id) {
      case MenuButtonId.start:
        _paintStart(canvas);
      case MenuButtonId.instructions:
        _paintInstructions(canvas);
      case MenuButtonId.about:
        _paintAbout(canvas);
      case MenuButtonId.exit:
        _paintExit(canvas);
    }
    canvas.restore();
  }

  void _paintStart(Canvas canvas) {
    // <circle cx=14 cy=14 r=11.2 stroke strokeWidth=2.3 />
    canvas.drawCircle(
        const Offset(14, 14), 11.2, _stroke(HomeConfig.iconStroke));

    // Rounded play triangle, transform="translate(0 0.5)".
    final p = Path()
      ..moveTo(11.6, 9.85)
      ..cubicTo(11.6, 9.18, 12.33, 8.77, 12.91, 9.11)
      ..lineTo(18.95, 12.76)
      ..cubicTo(19.5, 13.09, 19.5, 13.91, 18.95, 14.24)
      ..lineTo(12.91, 17.89)
      ..cubicTo(12.33, 18.23, 11.6, 17.82, 11.6, 17.15)
      ..lineTo(11.6, 9.85)
      ..close();
    canvas.save();
    canvas.translate(0, 0.5);
    canvas.drawPath(p, _fill());
    canvas.restore();
  }

  void _paintInstructions(Canvas canvas) {
    // Single path, fill-rule evenodd: book body + two cover lines.
    final p = Path()..fillType = PathFillType.evenOdd;

    // Body with bottom page fold.
    p
      ..moveTo(7.6, 3.8)
      ..cubicTo(6.05, 3.8, 4.8, 5.05, 4.8, 6.6)
      ..lineTo(4.8, 20.9)
      ..cubicTo(4.8, 22.75, 6.25, 24.2, 8.1, 24.2)
      ..lineTo(21.5, 24.2)
      ..cubicTo(22.22, 24.2, 22.8, 23.62, 22.8, 22.9)
      ..cubicTo(22.8, 22.18, 22.22, 21.6, 21.5, 21.6)
      ..lineTo(9.1, 21.6)
      ..cubicTo(8.22, 21.6, 7.5, 20.98, 7.5, 20.2)
      ..cubicTo(7.5, 19.42, 8.22, 18.8, 9.1, 18.8)
      ..lineTo(21.1, 18.8)
      ..cubicTo(22.04, 18.8, 22.8, 18.04, 22.8, 17.1)
      ..lineTo(22.8, 5.6)
      ..cubicTo(22.8, 4.6, 22, 3.8, 21, 3.8)
      ..lineTo(7.6, 3.8)
      ..close();

    // Cover line 1.
    p
      ..moveTo(9.3, 8.1)
      ..cubicTo(8.69, 8.1, 8.2, 8.59, 8.2, 9.2)
      ..cubicTo(8.2, 9.81, 8.69, 10.3, 9.3, 10.3)
      ..lineTo(18.5, 10.3)
      ..cubicTo(19.11, 10.3, 19.6, 9.81, 19.6, 9.2)
      ..cubicTo(19.6, 8.59, 19.11, 8.1, 18.5, 8.1)
      ..lineTo(9.3, 8.1)
      ..close();

    // Cover line 2.
    p
      ..moveTo(9.3, 12.6)
      ..cubicTo(8.69, 12.6, 8.2, 13.09, 8.2, 13.7)
      ..cubicTo(8.2, 14.31, 8.69, 14.8, 9.3, 14.8)
      ..lineTo(16.4, 14.8)
      ..cubicTo(17.01, 14.8, 17.5, 14.31, 17.5, 13.7)
      ..cubicTo(17.5, 13.09, 17.01, 12.6, 16.4, 12.6)
      ..lineTo(9.3, 12.6)
      ..close();

    canvas.drawPath(p, _fill());
  }

  void _paintAbout(Canvas canvas) {
    canvas.drawCircle(
        const Offset(14, 14), 11.2, _stroke(HomeConfig.iconStroke));
    // Dot of the "i": <circle cx=14 cy=9.2 r=1.65 />
    canvas.drawCircle(const Offset(14, 9.2), 1.65, _fill());
    // Stem + foot serif, strokeWidth 2.35, round caps/joins:
    // M12.3 13.1 H14.2 V18.8 M12.1 19 H16
    final p = Path()
      ..moveTo(12.3, 13.1)
      ..lineTo(14.2, 13.1)
      ..lineTo(14.2, 18.8)
      ..moveTo(12.1, 19)
      ..lineTo(16, 19);
    canvas.drawPath(p, _stroke(2.35));
  }

  void _paintExit(Canvas canvas) {
    final paint = _stroke(HomeConfig.iconStroke + 0.15); // 2.45

    // Arched doorway (open on the right).
    final door = Path()
      ..moveTo(6.4, 23.2)
      ..lineTo(6.4, 10.6)
      ..cubicTo(6.4, 7.05, 9.05, 4.6, 12.2, 4.6)
      ..cubicTo(14.8, 4.6, 16.95, 6.3, 17.55, 8.75);
    canvas.drawPath(door, paint);

    // Arrow shaft.
    canvas.drawPath(
      Path()
        ..moveTo(11.6, 15.2)
        ..lineTo(22.2, 15.2),
      paint,
    );

    // Arrow head.
    canvas.drawPath(
      Path()
        ..moveTo(18.1, 11.2)
        ..lineTo(22.4, 15.2)
        ..lineTo(18.1, 19.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MenuIconPainter old) =>
      old.id != id || old.color != color;
}
