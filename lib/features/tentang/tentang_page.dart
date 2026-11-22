import 'package:flutter/widgets.dart';

import '../info_pages/info_pages_config.dart';
import '../info_pages/widgets/cropped_asset.dart';
import '../info_pages/widgets/info_page_shell.dart';

/// ASTORYA Tentang (About) page.
///
/// Port of `TentangPage.tsx`: shared shell, cropped title, cropped illustrated
/// information panel. No Mulai button. The paragraphs are exposed to screen
/// readers only; the PNG already draws them.
class TentangPage extends StatelessWidget {
  const TentangPage({
    super.key,
    this.onBack,
    this.showVersionFooter = true,
  });

  /// Back navigation. Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  final bool showVersionFooter;

  @override
  Widget build(BuildContext context) {
    final InfoRect panel = InfoPagesConfig.tentangCard.target;
    final List<String> sections = InfoPagesConfig.tentangSections;

    return InfoPageShell(
      pageLabel: InfoPagesConfig.tentangPageLabel,
      onBack: onBack,
      showVersionFooter: showVersionFooter,
      children: <Widget>[
        // Title "Tentang" with golden cloud ornaments (cropped from PNG).
        const CroppedAsset(spec: InfoPagesConfig.tentangTitle, decorative: true),
        InfoSemanticsRegion(
          rect: InfoPagesConfig.tentangTitle.target,
          label: InfoPagesConfig.tentangHeading,
          header: true,
        ),

        // Rounded cream information panel with three illustrated rows.
        const CroppedAsset(spec: InfoPagesConfig.tentangCard, decorative: true),
        for (int i = 0; i < sections.length; i++)
          InfoSemanticsRegion(
            rect: panel.verticalSlice(i, sections.length),
            label: sections[i],
          ),
      ],
    );
  }
}
