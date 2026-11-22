// ASTORYA Main Menu configuration — ported 1:1 from the React project's
// src/config/menuConfig.ts, src/components/MenuIcons.tsx and src/index.css.

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Logical design canvas (412 x 917, portrait).
const double kHomeDesignWidth = 412;
const double kHomeDesignHeight = 917;

enum MenuButtonId { start, instructions, about, exit }

class MenuButtonConfig {
  const MenuButtonConfig({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.x,
    required this.y,
  });

  final MenuButtonId id;
  final String label;
  final double width;
  final double height;
  final double x;
  final double y;
}

/// One visual state (default / hover / pressed) of a button's depth cues.
/// Mirrors the CSS box-shadow strings and the :hover / :active rules.
class MenuButtonLook {
  const MenuButtonLook({
    required this.scale,
    required this.brightness,
    required this.outerDy,
    required this.outerBlur,
    required this.outerColor,
    required this.highlightDy,
    required this.highlightColor,
    required this.lowShadowDy,
    required this.lowShadowColor,
  });

  final double scale;
  final double brightness;
  final double outerDy;
  final double outerBlur;
  final Color outerColor;
  final double highlightDy;
  final Color highlightColor;
  final double lowShadowDy;
  final Color lowShadowColor;

  MenuButtonLook withBrightness(double b) => MenuButtonLook(
        scale: scale,
        brightness: b,
        outerDy: outerDy,
        outerBlur: outerBlur,
        outerColor: outerColor,
        highlightDy: highlightDy,
        highlightColor: highlightColor,
        lowShadowDy: lowShadowDy,
        lowShadowColor: lowShadowColor,
      );

  static MenuButtonLook lerp(MenuButtonLook a, MenuButtonLook b, double t) {
    double d(double x, double y) => x + (y - x) * t;
    return MenuButtonLook(
      scale: d(a.scale, b.scale),
      brightness: d(a.brightness, b.brightness),
      outerDy: d(a.outerDy, b.outerDy),
      outerBlur: d(a.outerBlur, b.outerBlur),
      outerColor: Color.lerp(a.outerColor, b.outerColor, t)!,
      highlightDy: d(a.highlightDy, b.highlightDy),
      highlightColor: Color.lerp(a.highlightColor, b.highlightColor, t)!,
      lowShadowDy: d(a.lowShadowDy, b.lowShadowDy),
      lowShadowColor: Color.lerp(a.lowShadowColor, b.lowShadowColor, t)!,
    );
  }
}

class HomeConfig {
  HomeConfig._();

  /// Existing project asset (note the original "backgorund" spelling).
  static const String backgroundAsset =
      'asset/menu_utama/backgorund-menu-utama.png';

  /// Page backdrop behind the canvas (MobileCanvas: bg-[#F3EFE9]).
  static const Color pageBackdrop = Color(0xFFF3EFE9);

  static const List<MenuButtonConfig> buttons = [
    MenuButtonConfig(
        id: MenuButtonId.start,
        label: 'Mulai',
        width: 202, height: 69, x: 105, y: 327),
    MenuButtonConfig(
        id: MenuButtonId.instructions,
        label: 'Petunjuk',
        width: 274, height: 69, x: 69, y: 432),
    MenuButtonConfig(
        id: MenuButtonId.about,
        label: 'Tentang',
        width: 274, height: 69, x: 69, y: 535),
    MenuButtonConfig(
        id: MenuButtonId.exit,
        label: 'Keluar',
        width: 278, height: 69, x: 67, y: 646),
  ];

  // ---- Typography -------------------------------------------------------
  /// Static TTF instance (wght 860, opsz 36, SOFT 100 + WONK 1 baked in).
  static const String fontFamily = 'FrauncesSuperSoftWonky';
  static const double fontSize = 34;
  static const FontWeight fontWeight = FontWeight.w900; // asset declared as 900
  static const Color textColor = Color(0xFF60300D);
  static const double letterSpacing = -0.01 * 34; // -0.01em
  static const double lineHeight = 1.1;
  static const double textOpticalDy = -1; // translateY(-1px)

  // ---- Icons ------------------------------------------------------------
  static const double iconSize = 30;
  static const double iconSpacing = 14;
  static const Color iconColor = Color(0xFF60300D);
  static const double iconStroke = 2.3;
  static const double iconViewBox = 28;

  // ---- Button -----------------------------------------------------------
  static const double borderRadius = 35;
  static const double borderWidth = 1.75;

  static const List<Color> gradientColors = [
    Color(0xFFFFE3B8),
    Color(0xFFFFD9A1),
    Color(0xFFF0BD77),
  ];
  static const List<double> gradientStops = [0.0, 0.5, 1.0];

  static const Color borderTop = Color(0xFFF5C687);
  static const Color borderSide = Color(0xFFE3A95E);
  static const Color borderBottom = Color(0xFFCB8636);

  static const Color focusRing = Color(0xFF60300D);
  static const double focusRingWidth = 2.5;
  static const double focusRingOffset = 3;

  // ---- Interaction ------------------------------------------------------
  static const Duration duration = Duration(milliseconds: 150);
  static const Curve easing = Cubic(0.22, 1, 0.36, 1);
  static const double pressedScale = 0.975;
  static const double hoverBrightness = 1.03;

  static const MenuButtonLook lookDefault = MenuButtonLook(
    scale: 1,
    brightness: 1,
    outerDy: 3,
    outerBlur: 4,
    outerColor: Color.fromRGBO(151, 86, 23, 0.22),
    highlightDy: 1.5,
    highlightColor: Color.fromRGBO(255, 248, 234, 0.72),
    lowShadowDy: -1.5,
    lowShadowColor: Color.fromRGBO(203, 134, 54, 0.35),
  );

  static const MenuButtonLook lookHover = MenuButtonLook(
    scale: 1,
    brightness: hoverBrightness,
    outerDy: 4,
    outerBlur: 6,
    outerColor: Color.fromRGBO(151, 86, 23, 0.28),
    highlightDy: 1.5,
    highlightColor: Color.fromRGBO(255, 250, 240, 0.8),
    lowShadowDy: -1.5,
    lowShadowColor: Color.fromRGBO(203, 134, 54, 0.35),
  );

  static const MenuButtonLook lookPressed = MenuButtonLook(
    scale: pressedScale,
    brightness: 1,
    outerDy: 1.5,
    outerBlur: 2,
    outerColor: Color.fromRGBO(151, 86, 23, 0.18),
    highlightDy: 1,
    highlightColor: Color.fromRGBO(255, 245, 224, 0.55),
    lowShadowDy: -1,
    lowShadowColor: Color.fromRGBO(203, 134, 54, 0.45),
  );
}
