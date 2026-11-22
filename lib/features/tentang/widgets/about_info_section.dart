import 'package:flutter/material.dart';

import '../../info_pages/info_pages_config.dart';

/// Decorative golden divider between the illustrated panel and info sections.
class AboutOrnamentDivider extends StatelessWidget {
  const AboutOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left:
          (InfoPagesConfig.canvasWidth - InfoPagesConfig.tentangDividerWidth) /
              2,
      top: InfoPagesConfig.tentangDividerY,
      width: InfoPagesConfig.tentangDividerWidth,
      height: InfoPagesConfig.tentangDividerHeight,
      child: const ExcludeSemantics(
        child: IgnorePointer(
          child: CustomPaint(painter: _AboutOrnamentDividerPainter()),
        ),
      ),
    );
  }
}

/// A rounded cream panel with an overlapping gold plaque and scroll details.
class AboutInfoSection extends StatelessWidget {
  const AboutInfoSection({
    super.key,
    required this.config,
    required this.child,
  });

  final AboutInfoSectionConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AboutPageTheme theme = InfoPagesConfig.tentangTheme;

    return Positioned(
      left: (InfoPagesConfig.canvasWidth - config.containerWidth) / 2,
      top: config.y,
      width: config.containerWidth,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Padding(
          // Keep the previous total layout height while placing the cream
          // panel half a plaque-height below the section's top coordinate.
          padding: EdgeInsets.symmetric(vertical: config.plaqueHeight / 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Paint the panel first. Its child clip is limited to the cream
              // content and cannot clip the overlapping plaque.
              Container(
                width: config.containerWidth,
                padding: config.contentPadding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(config.containerRadius),
                  border: Border.all(color: theme.containerBorder, width: 1.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.containerTop, theme.containerBottom],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(148, 86, 17, 0.08),
                      offset: Offset(0, 3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(config.containerRadius),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      child,
                      const Positioned(
                        left: 2,
                        right: 2,
                        top: 1,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(255, 255, 255, 0.72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Paint the golden plaque after the panel so its lower half
              // remains visible above the panel border.
              Positioned(
                left: 0,
                right: 0,
                top: -config.plaqueHeight / 2,
                child:
                    Center(child: _AboutPlaque(config: config, theme: theme)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutPlaque extends StatelessWidget {
  const _AboutPlaque({required this.config, required this.theme});

  final AboutInfoSectionConfig config;
  final AboutPageTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlaqueScrollWing(
          side: _WingSide.left,
          extended: config.extendedOrnaments,
          compact: config.compactOrnaments,
        ),
        Container(
          width: config.plaqueWidth,
          height: config.plaqueHeight,
          padding: EdgeInsets.symmetric(
            horizontal: config.compactOrnaments ? 11 : 14,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              config.compactOrnaments ? 9 : 10,
            ),
            border: Border.all(
              color: theme.plaqueBorder,
              width: config.compactOrnaments ? 1.75 : 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.plaqueTop, theme.plaqueMid, theme.plaqueBottom],
              stops: const [0, 0.54, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(120, 66, 14, 0.24),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              config.compactOrnaments ? 9 : 10,
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Semantics(
                      header: true,
                      child: Text(
                        config.title,
                        maxLines: 1,
                        softWrap: false,
                        textScaler: TextScaler.noScaling,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.plaqueText,
                          fontSize: config.plaqueFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: config.plaqueFontSize * 0.01,
                          height: 1.15,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(72, 36, 6, 0.45),
                              offset: Offset(0, 1),
                              blurRadius: 1.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  top: 1,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 236, 188, 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _PlaqueScrollWing(
          side: _WingSide.right,
          extended: config.extendedOrnaments,
          compact: config.compactOrnaments,
        ),
      ],
    );
  }
}

enum _WingSide { left, right }

class _PlaqueScrollWing extends StatelessWidget {
  const _PlaqueScrollWing({
    required this.side,
    required this.extended,
    required this.compact,
  });

  final _WingSide side;
  final bool extended;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double scale = compact ? 0.85 : 1;
    final double width = (extended ? 42 : 16) * scale;
    final double height = 20 * scale;

    return Transform.translate(
      offset: Offset(
        side == _WingSide.left ? -3.5 * scale : 3.5 * scale,
        (compact ? 2 : 3) * scale,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          side == _WingSide.right ? -1 : 1,
          1,
          1,
        ),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(width, height),
              painter: _PlaqueScrollPainter(extended: extended),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaqueScrollPainter extends CustomPainter {
  const _PlaqueScrollPainter({required this.extended});

  final bool extended;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / (extended ? 42 : 16);
    canvas.save();
    canvas.scale(scale, scale);

    if (extended) {
      final Paint wingPaint = Paint()..color = const Color(0xFFE5A13B);
      final Path rim = Path()
        ..moveTo(1.5, 11.5)
        ..lineTo(17, 10.5)
        ..lineTo(17, 12.5)
        ..close();
      canvas.drawPath(rim, wingPaint);

      final Path bead = Path()
        ..moveTo(15, 11.5)
        ..lineTo(21, 8.5)
        ..lineTo(26, 11.5)
        ..lineTo(21, 14.5)
        ..close();
      canvas.drawPath(bead, wingPaint);
      canvas.drawCircle(
        const Offset(21, 11.5),
        1.3,
        Paint()..color = const Color(0xFFFFF3D4),
      );
    }

    canvas.save();
    if (extended) canvas.translate(26, 0);
    canvas.drawCircle(
      const Offset(8.2, 11.2),
      6.2,
      Paint()
        ..color = const Color(0xFFE5A13B)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      const Offset(8.2, 11.2),
      6.2,
      Paint()
        ..color = const Color(0xFFF4C562)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final Path curl = Path()
      ..moveTo(11.6, 10.6)
      ..cubicTo(11.6, 8.3, 9.7, 6.8, 7.5, 7.1)
      ..cubicTo(5.5, 7.4, 4.3, 9.2, 4.7, 11.2)
      ..cubicTo(5.1, 13, 6.8, 14.1, 8.6, 13.7)
      ..cubicTo(9.8, 13.4, 10.4, 12.2, 10, 11.1)
      ..cubicTo(9.7, 10.3, 8.8, 9.9, 8, 10.3);
    canvas.drawPath(
      curl,
      Paint()
        ..color = const Color(0xFF8E5010)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlaqueScrollPainter oldDelegate) =>
      oldDelegate.extended != extended;
}

class _AboutOrnamentDividerPainter extends CustomPainter {
  const _AboutOrnamentDividerPainter();

  static const Color _gold = Color(0xFFE5A13B);
  static const Color _highlight = Color(0xFFF3C15A);

  Paint _ornamentFill() => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF5C35B), _gold, Color(0xFFCC8321)],
      stops: [0, 0.55, 1],
    ).createShader(const Rect.fromLTWH(0, 1, 298, 18));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 298, size.height / 20);

    final Paint leftLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.fromRGBO(229, 161, 59, 0.45),
          Color.fromRGBO(229, 161, 59, 0.95),
          _highlight,
        ],
        stops: [0, 0.22, 1],
      ).createShader(const Rect.fromLTWH(2, 0, 126, 20));
    final Paint rightLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _highlight,
          Color.fromRGBO(229, 161, 59, 0.95),
          Color.fromRGBO(229, 161, 59, 0.45),
        ],
        stops: [0, 0.78, 1],
      ).createShader(const Rect.fromLTWH(172, 0, 126, 20));
    canvas.drawLine(const Offset(4, 10), const Offset(126, 10), leftLine);
    canvas.drawLine(const Offset(172, 10), const Offset(294, 10), rightLine);

    final Paint fill = _ornamentFill();
    final Path leftBead = Path()
      ..moveTo(123.5, 10)
      ..lineTo(128.5, 7.2)
      ..lineTo(133.5, 10)
      ..lineTo(128.5, 12.8)
      ..close();
    final Path rightBead = Path()
      ..moveTo(164.5, 10)
      ..lineTo(169.5, 7.2)
      ..lineTo(174.5, 10)
      ..lineTo(169.5, 12.8)
      ..close();
    canvas.drawPath(leftBead, fill);
    canvas.drawPath(rightBead, fill);

    final Path topBud = Path()
      ..moveTo(149, 1.3)
      ..lineTo(152.2, 4.8)
      ..lineTo(149, 7.6)
      ..lineTo(145.8, 4.8)
      ..close();
    final Path bottomBud = Path()
      ..moveTo(149, 18.7)
      ..lineTo(152.2, 15.2)
      ..lineTo(149, 12.4)
      ..lineTo(145.8, 15.2)
      ..close();
    canvas.drawPath(topBud, fill);
    canvas.drawPath(bottomBud, fill);

    for (final double x in [141.5, 156.5]) {
      canvas.drawCircle(Offset(x, 10), 6.2, fill);
      canvas.drawCircle(
          Offset(x, 10), 3.4, Paint()..color = const Color(0xFFFFF7E4));
      canvas.drawCircle(
          Offset(x, 10), 1.55, Paint()..color = const Color(0xFFD58D25));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AboutOrnamentDividerPainter oldDelegate) =>
      false;
}
