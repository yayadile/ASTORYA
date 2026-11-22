import 'package:flutter/widgets.dart';

import '../info_pages/info_pages_config.dart';
import '../info_pages/widgets/cropped_asset.dart';
import '../info_pages/widgets/info_page_shell.dart';
import 'widgets/about_info_section.dart';

/// ASTORYA Tentang (About) page.
///
/// Port of `TentangPage.tsx`: shared shell, cropped title, cropped illustrated
/// information panel. No Mulai button. The paragraphs are exposed to screen
/// readers only; the PNG already draws them.
class TentangPage extends StatelessWidget {
  const TentangPage({
    super.key,
    this.onBack,
    this.showVersionFooter = false,
  });

  /// Back navigation. Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  final bool showVersionFooter;

  @override
  Widget build(BuildContext context) {
    final InfoRect panel = InfoPagesConfig.tentangCard.target;
    final List<String> sections = InfoPagesConfig.tentangSections;
    final AboutInfoSectionConfig version =
        InfoPagesConfig.tentangVersionSection;
    final AboutInfoSectionConfig developers =
        InfoPagesConfig.tentangDeveloperSection;

    return InfoPageShell(
      pageLabel: InfoPagesConfig.tentangPageLabel,
      onBack: onBack,
      showVersionFooter: showVersionFooter,
      brandOffsetY: InfoPagesConfig.tentangBrandOffsetY,
      children: <Widget>[
        // Title "Tentang" with golden cloud ornaments (cropped from PNG).
        const CroppedAsset(
            spec: InfoPagesConfig.tentangTitle, decorative: true),
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

        const AboutOrnamentDivider(),

        AboutInfoSection(
          config: version,
          child: Center(
            child: Text(
              InfoPagesConfig.tentangVersionValue,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: InfoPagesConfig.tentangTheme.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.165,
                height: 1.2,
              ),
            ),
          ),
        ),

        AboutInfoSection(
          config: developers,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0;
                  i < InfoPagesConfig.tentangDevelopers.length;
                  i++) ...[
                SizedBox(
                  width: developers.containerWidth - 24,
                  child: Text(
                    InfoPagesConfig.tentangDevelopers[i],
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: _developerNameStyle,
                  ),
                ),
                if (i < InfoPagesConfig.tentangDevelopers.length - 1)
                  const SizedBox(height: 2),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: 196,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0x00E5A13B),
                          const Color(0x94E5A13B),
                          const Color(0x94E5A13B),
                          const Color(0x00E5A13B),
                        ],
                        stops: const [0, 0.25, 0.75, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                InfoPagesConfig.tentangInstitution,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: InfoPagesConfig.tentangTheme.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const TextStyle _developerNameStyle = TextStyle(
  color: Color(0xFF60300D),
  fontSize: 16.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.165,
  height: 1.3,
);
