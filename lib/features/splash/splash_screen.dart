import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import 'splash_config.dart';

/// Developer preview switch (unchanged from the existing project):
/// `flutter run -d chrome --dart-define=ASTORYA_PREVIEW_HOME=true`
const bool _kPreviewHome = bool.fromEnvironment('ASTORYA_PREVIEW_HOME');

/// Animated ASTORYA splash — native Flutter port of the React prototype.
///
/// * Fixed 412 x 917 logical canvas, uniformly scaled (FittedBox/contain).
/// * One linear 6 s clock; every layer derives its state from `t` seconds
///   using the same windows and easing formulas as the React source.
/// * Does NOT touch the AR scanner or request camera permission.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (kTotalDurationSec * 1000).round()),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goHome();
      });

    if (_kPreviewHome) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !_kPreviewHome) {
      _started = true;
      _precacheAndPlay();
    }
  }

  /// Decode all artwork first so the 6 s timeline never starts mid-decode.
  Future<void> _precacheAndPlay() async {
    try {
      await Future.wait(
        SplashLayers.all.map((l) => precacheImage(AssetImage(l.asset), context)),
      );
    } catch (_) {
      // A failed precache must never block the app; images still load lazily.
    }
    if (!mounted) return;
    _clock.forward();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: SplashColors.primaryCream,
      body: Center(
        // Desktop Chrome: portrait canvas stays centered and is never stretched.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: kDesignWidth,
            height: kDesignHeight,
            child: ClipRect(
              child: ColoredBox(
                color: SplashColors.primaryCream,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => _SplashCanvas(
                    t: _clock.value * kTotalDurationSec,
                    reducedMotion: reduced,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 412 x 917 composition for a given time `t` (seconds).
/// In the React source ambient time equals playback time during the
/// splash, so a single `t` drives both.
class _SplashCanvas extends StatelessWidget {
  const _SplashCanvas({required this.t, required this.reducedMotion});

  final double t;
  final bool reducedMotion;

  Widget _img(SplashLayer l) => Image.asset(
        l.asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );

  Widget _placed(SplashLayer l, Widget child) => Positioned(
        left: l.x,
        top: l.y,
        width: l.w,
        height: l.h,
        child: IgnorePointer(child: child),
      );

  @override
  Widget build(BuildContext context) {
    final rm = reducedMotion;
    final ambient = t;

    // ---- A: background (0 – 0.78 s) --------------------------------------
    final bgP = easeOutCubic(progressIn(t, SplashTimeline.backgroundFade));
    final bgScale = rm ? 1.0 : lerp(1.02, 1.0, bgP);
    final sunBreath = rm ? 0.24 : 0.22 + 0.06 * math.sin(ambient * 0.85);

    // ---- B: candi (2.9 – 3.85 s) -----------------------------------------
    final candiP = easeOutQuart(progressIn(t, SplashTimeline.candiReveal));
    final candiY = (rm ? 0.0 : lerp(12, 0, candiP)) +
        (rm ? 0.0 : math.sin(ambient * 0.55) * 0.8);

    // ---- C: wayang watermark (0.8 – 1.72 s) ------------------------------
    final wayP = easeOutCubic(progressIn(t, SplashTimeline.wayangReveal));
    final wayScale = rm ? 1.0 : lerp(0.985, 1.0, wayP);
    final wayAmbient = rm ? 0.0 : math.sin(ambient * 0.6) * 0.012;
    final wayOpacity =
        (wayP * 0.13 + wayAmbient * wayP).clamp(0.0, 0.15).toDouble();

    // ---- D: top clouds (0.88 – 1.8 s) ------------------------------------
    final topP = easeOutCubic(progressIn(t, SplashTimeline.topCloudsReveal));
    final topX = rm ? 0.0 : math.sin(ambient * 0.6) * 2.2;
    final topY = (rm ? 0.0 : lerp(-10, 0, topP)) +
        (rm ? 0.0 : math.cos(ambient * 0.48) * 1.4);

    // ---- H / I: lower clouds (1.8 – 2.52 s) ------------------------------
    final lowerP = easeOutQuart(progressIn(t, SplashTimeline.lowerCloudsReveal));
    final midX = rm ? 0.0 : math.sin(ambient * 0.55 + 0.4) * 2.0;
    final midY = (rm ? 0.0 : lerp(26, 0, lowerP)) +
        (rm ? 0.0 : math.cos(ambient * 0.45) * 1.4);
    final fgX = rm ? 0.0 : math.sin(ambient * 0.7 + 1.6) * 2.4;
    final fgY = (rm ? 0.0 : lerp(20, 0, lowerP)) +
        (rm ? 0.0 : math.sin(ambient * 0.85) * 1.6);

    // ---- G: Rama & Sinta -------------------------------------------------
    final charFade = easeOutCubic(progressIn(t, SplashTimeline.charactersFade));
    final peekP = easeOutCubic(progressIn(t, SplashTimeline.charactersPeekRise));
    final fullP = easeInOutCubic(progressIn(t, SplashTimeline.charactersFullRise));
    final charY = rm ? 0.0 : lerp(248, 164, peekP) - lerp(0, 164, fullP);

    // ---- E / F: emblem & wordmark ----------------------------------------
    final emblemP = easeOutCubic(progressIn(t, SplashTimeline.emblemReveal));
    final emblemScale = rm ? 1.0 : lerp(0.96, 1.0, emblemP);
    final emblemY = rm ? 0.0 : lerp(6, 0, emblemP);
    final wordP = easeOutCubic(progressIn(t, SplashTimeline.wordmarkReveal));
    final wordY = rm ? 0.0 : lerp(10, 0, wordP);

    // Stack order == CSS z-index order (0,10,20,30,35,40,50,60,80,90).
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // A — background (object-cover, scale about center, + sun glow)
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: bgP,
              child: Transform.scale(
                scale: bgScale,
                alignment: Alignment.center,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          SplashLayers.background.asset,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        left: (kDesignWidth - 260) / 2,
                        top: 48,
                        width: 260,
                        height: 210,
                        child: Opacity(
                          opacity: sunBreath.clamp(0.0, 1.0).toDouble(),
                          child: const CustomPaint(painter: _SunGlowPainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // B — distant temples (bottom 22% fades out via mask)
        _placed(
          SplashLayers.candi,
          Opacity(
            opacity: candiP,
            child: Transform.translate(
              offset: Offset(0, candiY),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Color(0x00000000)],
                  stops: [0.0, 0.78, 1.0],
                ).createShader(rect),
                child: _img(SplashLayers.candi),
              ),
            ),
          ),
        ),

        // C — wayang watermark (max opacity 0.15, origin center 55%)
        _placed(
          SplashLayers.wayang,
          Opacity(
            opacity: wayOpacity,
            child: Transform.scale(
              scale: wayScale,
              alignment: const Alignment(0, 0.1),
              child: _img(SplashLayers.wayang),
            ),
          ),
        ),

        // D — upper clouds (translate, then scale 1.018 about 48% / top)
        _placed(
          SplashLayers.topClouds,
          Opacity(
            opacity: topP,
            child: Transform.translate(
              offset: Offset(topX, topY),
              child: Transform.scale(
                scale: 1.018,
                alignment: const Alignment(-0.04, -1),
                child: _img(SplashLayers.topClouds),
              ),
            ),
          ),
        ),

        // H — middle clouds (behind characters)
        _placed(
          SplashLayers.middleClouds,
          Opacity(
            opacity: lowerP,
            child: Transform.translate(
              offset: Offset(midX, midY),
              child: Transform.scale(
                scale: 1.018,
                alignment: Alignment.bottomCenter,
                child: _img(SplashLayers.middleClouds),
              ),
            ),
          ),
        ),

        // G — Rama & Sinta
        _placed(
          SplashLayers.characters,
          Opacity(
            opacity: charFade,
            child: Transform.translate(
              offset: Offset(0, charY),
              child: _img(SplashLayers.characters),
            ),
          ),
        ),

        // E — emblem (scale origin center 69%)
        _placed(
          SplashLayers.emblem,
          Opacity(
            opacity: emblemP,
            child: Transform.translate(
              offset: Offset(0, emblemY),
              child: Transform.scale(
                scale: emblemScale,
                alignment: const Alignment(0, 0.38),
                child: _img(SplashLayers.emblem),
              ),
            ),
          ),
        ),

        // F — wordmark
        _placed(
          SplashLayers.wordmark,
          Opacity(
            opacity: wordP,
            child: Transform.translate(
              offset: Offset(0, wordY),
              child: _img(SplashLayers.wordmark),
            ),
          ),
        ),

        // I — frontmost clouds (cover the characters' lower attire)
        _placed(
          SplashLayers.foregroundClouds,
          Opacity(
            opacity: lowerP,
            child: Transform.translate(
              offset: Offset(fgX, fgY),
              child: Transform.scale(
                scale: 1.02,
                alignment: Alignment.bottomCenter,
                child: _img(SplashLayers.foregroundClouds),
              ),
            ),
          ),
        ),

        // J — loading UI
        _LoadingUi(t: t, reducedMotion: rm),
      ],
    );
  }
}

/// Port of the CSS radial-gradient sun glow:
/// radial-gradient(circle, rgba(255,250,232,.75) 0%, rgba(253,247,234,.22) 52%,
/// rgba(253,247,234,0) 78%) on a 260 x 210 ellipse. A CSS circle gradient
/// defaults to `farthest-corner`, so its radius is hypot(130, 105).
class _SunGlowPainter extends CustomPainter {
  const _SunGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.sqrt(size.width * size.width / 4 +
        size.height * size.height / 4);
    final shader = const RadialGradient(
      colors: [
        Color.fromRGBO(255, 250, 232, 0.75),
        Color.fromRGBO(253, 247, 234, 0.22),
        Color.fromRGBO(253, 247, 234, 0.0),
      ],
      stops: [0.0, 0.52, 0.78],
    ).createShader(Rect.fromCircle(center: rect.center, radius: radius));
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Layer J — LOADING..., progress bar, caption and version.
class _LoadingUi extends StatelessWidget {
  const _LoadingUi({required this.t, required this.reducedMotion});

  final double t;
  final bool reducedMotion;

  static const Color _glow = Color.fromRGBO(253, 247, 234, 0.95);

  @override
  Widget build(BuildContext context) {
    final fadeP = easeOutCubic(progressIn(t, SplashTimeline.loadingFade));
    if (fadeP <= 0.001) return const SizedBox.shrink();

    final barP = easeInOutCubic(progressIn(t, SplashTimeline.loadingProgress));
    final dy = reducedMotion ? 0.0 : (1 - fadeP) * 6;

    return Positioned(
      left: SplashLoadingLayout.x,
      top: SplashLoadingLayout.y,
      width: SplashLoadingLayout.width,
      child: IgnorePointer(
        child: Opacity(
          opacity: fadeP,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Semantics(
              liveRegion: true,
              label: 'Loading ASTORYA, ${(barP * 100).round()} percent',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      SplashLoadingLayout.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.98, // 0.07em
                        color: SplashColors.mainText,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 6,
                            color: Color.fromRGBO(253, 247, 234, 0.92),
                          ),
                          Shadow(blurRadius: 2, color: _glow),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    height: SplashLoadingLayout.barHeight,
                    decoration: BoxDecoration(
                      color: SplashColors.primaryCream,
                      borderRadius: BorderRadius.circular(
                          SplashLoadingLayout.barHeight / 2),
                      border: Border.all(
                          color: SplashColors.barOutline, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Color.fromRGBO(138, 90, 18, 0.16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          SplashLoadingLayout.barHeight / 2 - 1.5),
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.diagonal3Values(barP, 1, 1),
                        child: const SizedBox.expand(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFE4B754),
                                  Color(0xFFC6902A),
                                  Color(0xFF9B6716),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          SplashLoadingLayout.caption,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B361A),
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 5,
                                color: _glow,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          SplashLoadingLayout.version,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: SplashColors.secondaryText,
                            decoration: TextDecoration.none,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 5,
                                color: _glow,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
