import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home_config.dart';
import 'menu_icon.dart';

/// Interactive peach-gold capsule button (port of MenuButton.tsx + the
/// .astorya-menu-button rules in index.css).
///
/// The widget fills the size given by its parent (HomeScreen positions it
/// on the 412 x 917 canvas using [MenuButtonConfig]).
class MenuButton extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.config,
    required this.onPressed,
  });

  final MenuButtonConfig config;
  final VoidCallback? onPressed;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _set({bool? hovered, bool? pressed, bool? focused}) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _pressed = pressed ?? _pressed;
      _focused = focused ?? _focused;
    });
  }

  MenuButtonLook get _look {
    final hoverBrightness = _hovered ? HomeConfig.hoverBrightness : 1.0;
    if (_pressed) {
      // CSS: :active changes transform + box-shadow only, so the hover
      // brightness filter stays while the mouse is still over the button.
      return HomeConfig.lookPressed.withBrightness(hoverBrightness);
    }
    return _hovered ? HomeConfig.lookHover : HomeConfig.lookDefault;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      enabled: enabled,
      label: cfg.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => _set(hovered: v),
        onShowFocusHighlight: (v) => _set(focused: v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(pressed: true) : null,
          onTapUp: enabled ? (_) => _set(pressed: false) : null,
          onTapCancel: enabled ? () => _set(pressed: false) : null,
          onTap: widget.onPressed,
          child: SizedBox(
            width: cfg.width,
            height: cfg.height,
            child: TweenAnimationBuilder<MenuButtonLook>(
              tween: _LookTween(end: _look),
              duration: reduceMotion ? Duration.zero : HomeConfig.duration,
              curve: HomeConfig.easing,
              builder: (context, look, child) {
                final b = look.brightness;
                return Transform.scale(
                  scale: reduceMotion ? 1.0 : look.scale,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(<double>[
                      b, 0, 0, 0, 0, //
                      0, b, 0, 0, 0, //
                      0, 0, b, 0, 0, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: CustomPaint(
                      painter: _ButtonPainter(look: look, focused: _focused),
                      child: child,
                    ),
                  ),
                );
              },
              child: Center(child: _ButtonContent(config: cfg)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LookTween extends Tween<MenuButtonLook> {
  _LookTween({super.begin, super.end});

  @override
  MenuButtonLook lerp(double t) => MenuButtonLook.lerp(begin!, end!, t);
}

/// Single centered [icon + label] group (14 px gap, label nudged -1 px).
class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.config});

  final MenuButtonConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MenuIcon(id: config.id),
        const SizedBox(width: HomeConfig.iconSpacing),
        Transform.translate(
          offset: const Offset(0, HomeConfig.textOpticalDy),
          child: Text(
            config.label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontFamily: HomeConfig.fontFamily,
              fontSize: HomeConfig.fontSize,
              fontWeight: HomeConfig.fontWeight,
              color: HomeConfig.textColor,
              letterSpacing: HomeConfig.letterSpacing,
              height: HomeConfig.lineHeight,
              leadingDistribution: TextLeadingDistribution.even,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints, back to front: blurred outer shadow, directional border ring,
/// gradient fill, lower inset shadow, upper inset highlight, focus ring.
class _ButtonPainter extends CustomPainter {
  const _ButtonPainter({required this.look, required this.focused});

  final MenuButtonLook look;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(
      HomeConfig.borderRadius,
      math.min(size.width, size.height) / 2, // CSS scales oversized radii
    );
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final inner = outer.deflate(HomeConfig.borderWidth);

    // 1. Outer drop shadow (CSS blur radius B == Gaussian sigma B / 2).
    canvas.drawRRect(
      outer.shift(Offset(0, look.outerDy)),
      Paint()
        ..color = look.outerColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, look.outerBlur / 2),
    );

    // 2. Border ring with top / side / bottom colors. Colors meet along the
    //    45-degree corner diagonals, like CSS directional borders.
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(inner),
    );
    final w = size.width;
    final h = size.height;
    final half = h / 2;
    canvas.drawPath(ring, Paint()..color = HomeConfig.borderSide);

    final topWedge = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - half, half)
      ..lineTo(half, half)
      ..close();
    canvas.save();
    canvas.clipPath(topWedge);
    canvas.drawPath(ring, Paint()..color = HomeConfig.borderTop);
    canvas.restore();

    final bottomWedge = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w - half, half)
      ..lineTo(half, half)
      ..close();
    canvas.save();
    canvas.clipPath(bottomWedge);
    canvas.drawPath(ring, Paint()..color = HomeConfig.borderBottom);
    canvas.restore();

    // 3. Vertical gradient fill (0.0 / 0.5 / 1.0).
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: HomeConfig.gradientColors,
          stops: HomeConfig.gradientStops,
        ).createShader(inner.outerRect),
    );

    // 4. CSS inset shadows (blur 0): lower first, highlight on top.
    _inset(canvas, inner, look.lowShadowDy, look.lowShadowColor);
    _inset(canvas, inner, look.highlightDy, look.highlightColor);

    // 5. Keyboard focus ring: outline 2.5px, offset 3px.
    if (focused) {
      canvas.drawRRect(
        outer.inflate(
            HomeConfig.focusRingOffset + HomeConfig.focusRingWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = HomeConfig.focusRingWidth
          ..color = HomeConfig.focusRing,
      );
    }
  }

  /// `inset 0 dy 0 color`: the padding box minus itself shifted by dy.
  void _inset(Canvas canvas, RRect inner, double dy, Color color) {
    canvas.save();
    canvas.clipRRect(inner);
    final region = Path.combine(
      PathOperation.difference,
      Path()..addRect(inner.outerRect.inflate(24)),
      Path()..addRRect(inner.shift(Offset(0, dy))),
    );
    canvas.drawPath(region, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter old) => true;
}
