import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../info_pages_config.dart';

/// Top-left capsule back button shared by Petunjuk and Tentang.
///
/// Port of the `.astorya-back-button` button in `InfoPageShell.tsx` / index.css:
/// white capsule, 2.25 px #9D6122 border, #653F15 arrow, hover / pressed
/// shadows, 0.96 pressed scale, 150 ms transitions, keyboard focus ring and
/// Enter / Space activation.
///
/// Sized by its parent; [InfoPageShell] places it at (13, 37) with 68 × 47.
class InfoBackButton extends StatefulWidget {
  const InfoBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<InfoBackButton> createState() => _InfoBackButtonState();
}

class _InfoBackButtonState extends State<InfoBackButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    const InfoBackButtonConfig cfg = InfoPagesConfig.backButton;
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : InfoPagesConfig.interactionDuration;
    const Curve curve = InfoPagesConfig.interactionCurve;

    final List<BoxShadow> shadows = _pressed
        ? cfg.shadowPressed
        : (_hovered ? cfg.shadowHover : cfg.shadowDefault);

    return Semantics(
      button: true,
      label: cfg.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (bool v) => setState(() => _hovered = v),
        onShowFocusHighlight: (bool v) => setState(() => _focusVisible = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? cfg.pressedScale : 1.0,
            duration: duration,
            curve: curve,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? cfg.hoverBackgroundColor
                          : cfg.backgroundColor,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: cfg.borderColor,
                        width: cfg.borderWidth,
                      ),
                      boxShadow: shadows,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(32, 24),
                        painter: _BackArrowPainter(color: cfg.iconColor),
                      ),
                    ),
                  ),
                ),
                // Keyboard focus ring: 2.5 px outline, 3 px offset.
                if (_focusVisible)
                  Positioned(
                    left: -5.5,
                    top: -5.5,
                    right: -5.5,
                    bottom: -5.5,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: cfg.focusRingColor,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back arrow. SVG viewBox 32 × 24, drawn 1:1 (no scaling):
/// `M25.5 12H6.8M13.5 5.2L6.5 12L13.5 18.8`, stroke 3.3, round caps and joins.
class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path()
      ..moveTo(25.5, 12)
      ..lineTo(6.8, 12)
      ..moveTo(13.5, 5.2)
      ..lineTo(6.5, 12)
      ..lineTo(13.5, 18.8);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BackArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
