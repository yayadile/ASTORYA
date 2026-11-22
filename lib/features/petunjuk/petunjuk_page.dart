import 'package:flutter/widgets.dart';

import '../info_pages/info_pages_config.dart';
import '../info_pages/widgets/cropped_asset.dart';
import '../info_pages/widgets/info_page_shell.dart';

/// Builds the "Mulai" button for the Petunjuk page.
///
/// The returned widget is placed in a box of exactly [config]'s width × height
/// (105, 651, 202 × 69) — it should fill that box and NOT position itself.
/// Wire [onPressed] to the same handler as Home's "Mulai" button.
typedef PetunjukStartButtonBuilder = Widget Function(
  BuildContext context,
  InfoStartButtonConfig config,
  VoidCallback onPressed,
);

/// ASTORYA Petunjuk (Instructions) page.
///
/// Port of `PetunjukPage.tsx`. Visible artwork is exclusively the original PNG
/// crops (title + three illustrated cards). The instruction text is exposed to
/// screen readers through [InfoSemanticsRegion]s and is never drawn twice.
class PetunjukPage extends StatelessWidget {
  const PetunjukPage({
    super.key,
    required this.onStart,
    required this.startButtonBuilder,
    this.onBack,
    this.showVersionFooter = true,
  });

  /// Starts the AR experience. Must be the SAME callback Home's "Mulai" uses.
  final VoidCallback onStart;

  /// Back navigation. Defaults to `Navigator.maybePop` (returns to the
  /// existing Home route, no Splash replay).
  final VoidCallback? onBack;

  /// Renders the existing Home `MenuButton` in the supplied button slot.
  final PetunjukStartButtonBuilder startButtonBuilder;

  final bool showVersionFooter;

  @override
  Widget build(BuildContext context) {
    const InfoStartButtonConfig button = InfoPagesConfig.petunjukStartButton;
    final InfoRect cards = InfoPagesConfig.petunjukCards.target;
    final List<InstructionStepText> steps = InfoPagesConfig.petunjukSteps;

    return InfoPageShell(
      pageLabel: InfoPagesConfig.petunjukPageLabel,
      onBack: onBack,
      showVersionFooter: showVersionFooter,
      children: <Widget>[
        // Title "Petunjuk" with golden cloud ornaments (cropped from PNG).
        const CroppedAsset(spec: InfoPagesConfig.petunjukTitle, decorative: true),
        InfoSemanticsRegion(
          rect: InfoPagesConfig.petunjukTitle.target,
          label: InfoPagesConfig.petunjukHeading,
          header: true,
        ),

        // Three illustrated instruction cards (cropped from PNG).
        const CroppedAsset(spec: InfoPagesConfig.petunjukCards, decorative: true),
        for (int i = 0; i < steps.length; i++)
          InfoSemanticsRegion(
            rect: cards.verticalSlice(i, steps.length),
            label: '${steps[i].title}. ${steps[i].description}',
          ),

        // Real interactive "Mulai" button.
        Positioned(
          left: button.x,
          top: button.y,
          width: button.width,
          height: button.height,
          child: Builder(
            builder: (BuildContext context) =>
                startButtonBuilder(context, button, onStart),
          ),
        ),
      ],
    );
  }
}
