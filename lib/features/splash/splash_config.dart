// ASTORYA splash — configuration ported 1:1 from the React project's
// src/config/splashConfig.ts and src/utils/easing.ts.
//
// Logical design canvas: 412 x 917, total duration 6.0 s.

import 'dart:math' as math;
import 'dart:ui' show Color;

const double kDesignWidth = 412;
const double kDesignHeight = 917;
const double kTotalDurationSec = 6.0;

/// Colors from ASTORYA_COLORS.
class SplashColors {
  SplashColors._();
  static const Color primaryCream = Color(0xFFFDF7EA);
  static const Color secondaryText = Color(0xFF6B5A3E);
  static const Color mainText = Color(0xFF1B1B1B);
  static const Color barOutline = Color(0xFF5A320A);
}

/// One positioned artwork layer on the 412 x 917 canvas.
class SplashLayer {
  const SplashLayer({
    required this.asset,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String asset;
  final double x;
  final double y;
  final double w;
  final double h;
}

const String _dir = 'asset/splash_screen/';

/// SPLASH_LAYERS. Z-order (back to front) is applied in splash_screen.dart:
/// background 0, candi 10, wayang 20, topClouds 30, middleClouds 35,
/// characters 40, emblem 50, wordmark 60, foregroundClouds 80, loading 90.
class SplashLayers {
  SplashLayers._();

  static const background = SplashLayer(
    asset: '${_dir}background_splashscreen.png',
    x: 0, y: 0, w: kDesignWidth, h: kDesignHeight,
  );
  static const candi = SplashLayer(
    asset: '${_dir}candi.png',
    x: 0, y: 54, w: 412, h: 514.8,
  );
  static const wayang = SplashLayer(
    asset: '${_dir}wayang.png',
    x: 2, y: -14, w: 408, h: 509.8,
  );
  static const topClouds = SplashLayer(
    asset: '${_dir}awan_depan_atas.png',
    x: 0, y: 0, w: 427.52, h: 534.19,
  );
  static const middleClouds = SplashLayer(
    asset: '${_dir}awan_depan_bawah.png',
    x: 0, y: 402.2, w: 412, h: 514.8,
  );
  static const characters = SplashLayer(
    asset: '${_dir}asset_rama&sinta.png',
    x: 5.82, y: 422, w: 407.75, h: 509.49,
  );
  static const emblem = SplashLayer(
    asset: '${_dir}emblem_astoryaa.png',
    x: 80, y: 16, w: 252, h: 314.88,
  );
  static const wordmark = SplashLayer(
    asset: '${_dir}wordmark.png',
    x: 78, y: 82, w: 256, h: 319.88,
  );
  static const foregroundClouds = SplashLayer(
    asset: '${_dir}awan_palingdepan_bawah.png',
    x: 0, y: 402.2, w: 412, h: 514.8,
  );

  static const List<SplashLayer> all = [
    background, candi, wayang, topClouds, middleClouds,
    characters, emblem, wordmark, foregroundClouds,
  ];
}

/// LOADING_LAYOUT.
class SplashLoadingLayout {
  SplashLoadingLayout._();
  static const double x = 39;
  static const double y = 829;
  static const double width = 334;
  static const double barHeight = 17;
  static const String label = 'LOADING...';
  static const String caption = 'Menyiapkan pengalaman AR...';
  static const String version = 'v1.0.0';
}

/// A [start, end] window in seconds.
class TimeWindow {
  const TimeWindow(this.start, this.end);
  final double start;
  final double end;
}

/// TIMELINE_WINDOWS (seconds).
class SplashTimeline {
  SplashTimeline._();
  static const backgroundFade = TimeWindow(0.0, 0.78);
  static const wayangReveal = TimeWindow(0.8, 1.72);
  static const topCloudsReveal = TimeWindow(0.88, 1.8);
  static const lowerCloudsReveal = TimeWindow(1.8, 2.52);
  static const charactersFade = TimeWindow(1.88, 2.38);
  static const charactersPeekRise = TimeWindow(1.85, 2.65);
  static const charactersFullRise = TimeWindow(2.65, 3.38);
  static const candiReveal = TimeWindow(2.9, 3.85);
  static const emblemReveal = TimeWindow(3.05, 3.88);
  static const wordmarkReveal = TimeWindow(3.4, 4.16);
  static const loadingFade = TimeWindow(4.2, 4.58);
  static const loadingProgress = TimeWindow(4.32, 5.95);
}

// ---------------------------------------------------------------------------
// Easing & interpolation (exact ports of easing.ts).
//
// NOTE: These are the polynomial formulas used by the React version, NOT
// Flutter's Curves.* (which are cubic-bezier approximations with slightly
// different shapes). Using the same formulas keeps the motion identical.
// ---------------------------------------------------------------------------

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double lerp(double a, double b, double t) => a + (b - a) * t;

/// progressInRange(): linear progress [0..1] of [tSec] inside [w].
double progressIn(double tSec, TimeWindow w) {
  if (w.end <= w.start) return tSec >= w.end ? 1 : 0;
  return clamp01((tSec - w.start) / (w.end - w.start));
}

double easeOutCubic(double t) => 1 - math.pow(1 - clamp01(t), 3).toDouble();

double easeOutQuart(double t) => 1 - math.pow(1 - clamp01(t), 4).toDouble();

double easeInOutCubic(double t) {
  final x = clamp01(t);
  return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3).toDouble() / 2;
}
