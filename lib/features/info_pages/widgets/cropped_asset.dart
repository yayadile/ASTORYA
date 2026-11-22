import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../info_pages_config.dart';

/// Exposes the uniform canvas scale (device-independent canvas px → logical
/// screen px) to descendants. [CroppedAsset] uses it to decode large PNGs at a
/// sensible size instead of at their full natural resolution.
class InfoCanvasScope extends InheritedWidget {
  const InfoCanvasScope({
    super.key,
    required this.scale,
    required super.child,
  });

  final double scale;

  /// Returns the current canvas scale, or 1.0 when used outside a shell.
  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<InfoCanvasScope>()
            ?.scale ??
        1.0;
  }

  @override
  bool updateShouldNotify(InfoCanvasScope oldWidget) =>
      scale != oldWidget.scale;
}

/// Renders one precisely cropped region of a high-resolution transparent PNG
/// inside the 412 × 917 design canvas.
///
/// Port of `CroppedAsset.tsx`:
///
/// ```text
/// scaleX = target.w / crop.w          scaleY = target.h / crop.h
/// imageW = naturalWidth  * scaleX     imageH = naturalHeight * scaleY
/// imageLeft = -(crop.x * scaleX)      imageTop = -(crop.y * scaleY)
/// ```
///
/// The full image is laid out at ([imageW] × [imageH]) at offset
/// ([imageLeft], [imageTop]) inside a box of the target size, and the box clips
/// it. Because the image is positioned with explicit tight constraints, Flutter
/// layout cannot shrink it before the crop is applied. Alpha is preserved.
///
/// Must be a direct child of a [Stack] (it returns a [Positioned]).
class CroppedAsset extends StatelessWidget {
  const CroppedAsset({
    super.key,
    required this.spec,
    this.decorative = false,
    this.fallbackLabel,
  });

  final CroppedAssetSpec spec;

  /// When true the image is hidden from assistive technology (used when the
  /// same information is exposed through separate semantics regions).
  final bool decorative;

  /// Text shown if the asset fails to load. Defaults to the spec's label.
  final String? fallbackLabel;

  /// Decode width in physical pixels. Rounded up to a multiple of 128 so that
  /// resizing a browser window does not re-decode the PNG on every frame.
  /// Returns null (decode at natural size) when the natural size is not larger.
  static int? _decodeWidth({
    required double renderedLogicalWidth,
    required double devicePixelRatio,
    required double canvasScale,
    required int naturalWidth,
  }) {
    final double needed = renderedLogicalWidth * devicePixelRatio * canvasScale;
    final int quantised = math.max(128, (needed / 128).ceil() * 128);
    return quantised >= naturalWidth ? null : quantised;
  }

  @override
  Widget build(BuildContext context) {
    final InfoRect crop = spec.crop;
    final InfoRect target = spec.target;

    final double scaleX = target.w / crop.w;
    final double scaleY = target.h / crop.h;

    final double imageWidth = spec.naturalWidth * scaleX;
    final double imageHeight = spec.naturalHeight * scaleY;
    final double imageLeft = -(crop.x * scaleX);
    final double imageTop = -(crop.y * scaleY);

    final int? cacheWidth = _decodeWidth(
      renderedLogicalWidth: imageWidth,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      canvasScale: InfoCanvasScope.of(context),
      naturalWidth: spec.naturalWidth,
    );

    final Widget image = Image.asset(
      spec.src,
      width: imageWidth,
      height: imageHeight,
      fit: BoxFit.fill,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        // The visible window sits at (-imageLeft, -imageTop) inside the
        // oversized image box; draw the fallback exactly there.
        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-imageLeft, -imageTop),
            child: SizedBox(
              width: target.w,
              height: target.h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE6FDF4E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x669D6122)),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      fallbackLabel ?? spec.semanticLabel,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        color: Color(0xFF60300D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Widget cropped = IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned(
            left: imageLeft,
            top: imageTop,
            width: imageWidth,
            height: imageHeight,
            child: image,
          ),
        ],
      ),
    );

    if (decorative) {
      cropped = ExcludeSemantics(child: cropped);
    } else {
      cropped = Semantics(
        image: true,
        label: spec.semanticLabel,
        child: cropped,
      );
    }

    return Positioned(
      left: target.x,
      top: target.y,
      width: target.w,
      height: target.h,
      child: cropped,
    );
  }
}
