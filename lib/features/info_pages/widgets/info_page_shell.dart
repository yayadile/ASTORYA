import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../info_pages_config.dart';
import 'cropped_asset.dart';
import 'info_back_button.dart';

/// Shared layout for the ASTORYA information pages (Petunjuk & Tentang).
///
/// Port of `InfoPageShell.tsx` + the uniform-scale stage of `MobileCanvas.tsx`:
///
/// * 412 × 917 portrait design canvas, uniformly scaled (one factor for both
///   axes) and centred. Never stretched, never scrolls.
/// * Original background PNG, with `#FCECD0` underneath.
/// * Official ASTORYA emblem + wordmark crops.
/// * Page-specific [children] (title / card crops, CTA, semantics regions).
/// * Optional decorative `— v1.0.0 —` footer ([showVersionFooter]).
/// * Interactive capsule back button, drawn last so it is always on top
///   (React: `z-index: 20`).
///
/// [children] are placed directly in a [Stack], so every child must be a
/// [Positioned] (as [CroppedAsset] and [InfoSemanticsRegion] are).
class InfoPageShell extends StatelessWidget {
  const InfoPageShell({
    super.key,
    required this.pageLabel,
    this.onBack,
    this.showVersionFooter = true,
    this.respectSafeArea = false,
    this.children = const <Widget>[],
  });

  /// Accessible label of the screen (React `<main aria-label>`).
  final String pageLabel;

  /// Called by the back button and the Escape key. Defaults to
  /// `Navigator.maybePop`, which also keeps Android system back consistent.
  final VoidCallback? onBack;

  /// Whether the decorative version footer is shown (React default: true).
  final bool showVersionFooter;

  /// When true the canvas is fitted inside the system safe area instead of the
  /// full window. Default false = identical framing to the React prototype
  /// (full-bleed, letterboxed by the backdrop colour).
  final bool respectSafeArea;

  /// Page-specific content. Must be [Positioned] widgets.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final VoidCallback handleBack = onBack ??
        () {
          Navigator.of(context).maybePop();
        };

    Widget stage = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final double scale = math.min(
          constraints.maxWidth / InfoPagesConfig.canvasWidth,
          constraints.maxHeight / InfoPagesConfig.canvasHeight,
        );
        if (scale <= 0) return const SizedBox.shrink();

        return Center(
          child: SizedBox(
            width: InfoPagesConfig.canvasWidth * scale,
            height: InfoPagesConfig.canvasHeight * scale,
            child: InfoCanvasScope(
              scale: scale,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: InfoPagesConfig.canvasWidth,
                  height: InfoPagesConfig.canvasHeight,
                  child: _InfoCanvas(
                    onBack: handleBack,
                    showVersionFooter: showVersionFooter,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (respectSafeArea) {
      stage = SafeArea(child: stage);
    }

    return Scaffold(
      backgroundColor: InfoPagesConfig.stageBackdropColor,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): handleBack,
        },
        child: Focus(
          autofocus: true,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: pageLabel,
            child: stage,
          ),
        ),
      ),
    );
  }
}

class _InfoCanvas extends StatelessWidget {
  const _InfoCanvas({
    required this.onBack,
    required this.showVersionFooter,
    required this.children,
  });

  final VoidCallback onBack;
  final bool showVersionFooter;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const InfoFooterConfig footer = InfoPagesConfig.footer;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        // Fallback colour + full-bleed original background (React: object-cover
        // on an image that already has the canvas' exact 412 × 917 size).
        const Positioned.fill(
          child: ColoredBox(color: InfoPagesConfig.pageFallbackColor),
        ),
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Image.asset(
                InfoPagesConfig.backgroundAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),

        // Official emblem + wordmark lockup (React: <header aria-label="ASTORYA">).
        Positioned.fill(
          child: Semantics(
            container: true,
            label: 'ASTORYA',
            excludeSemantics: true,
            child: const Stack(
              children: <Widget>[
                CroppedAsset(spec: InfoPagesConfig.emblem, decorative: true),
                CroppedAsset(spec: InfoPagesConfig.wordmark, decorative: true),
              ],
            ),
          ),
        ),

        // Page-specific title / cards / CTA.
        ...children,

        // Decorative version footer.
        if (showVersionFooter)
          Positioned(
            left: 0,
            right: 0,
            top: footer.y,
            child: IgnorePointer(
              child: Semantics(
                container: true,
                label: 'Versi aplikasi ${_versionDigits(footer.versionText)}',
                excludeSemantics: true,
                child: Center(
                  child: Text(
                    footer.versionText,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: footer.color.withValues(alpha: footer.opacity),
                      fontSize: footer.fontSize,
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const <String>[
                        'Times New Roman',
                        'Noto Serif',
                        'serif',
                      ],
                      fontStyle: FontStyle.italic,
                      fontWeight: footer.fontWeight,
                      letterSpacing: footer.letterSpacingEm * footer.fontSize,
                      height: footer.lineHeight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Back button on top of everything (React z-index: 20).
        Positioned(
          left: InfoPagesConfig.backButton.x,
          top: InfoPagesConfig.backButton.y,
          width: InfoPagesConfig.backButton.width,
          height: InfoPagesConfig.backButton.height,
          child: InfoBackButton(onPressed: onBack),
        ),
      ],
    );
  }

  /// "— v1.0.0 —" → "v1.0.0" for the screen-reader label.
  static String _versionDigits(String text) =>
      text.replaceAll('—', '').trim();
}

/// An invisible, correctly sized accessibility region placed over a rectangle
/// of the canvas. Used to expose text that exists only inside a PNG (the
/// illustrated cards) without drawing it a second time.
class InfoSemanticsRegion extends StatelessWidget {
  const InfoSemanticsRegion({
    super.key,
    required this.rect,
    required this.label,
    this.header = false,
  });

  final InfoRect rect;
  final String label;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.x,
      top: rect.y,
      width: rect.w,
      height: rect.h,
      child: Semantics(
        container: true,
        header: header,
        label: label,
        child: const SizedBox.expand(),
      ),
    );
  }
}
