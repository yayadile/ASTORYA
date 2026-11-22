import 'package:flutter/widgets.dart';

/// ASTORYA Info Sub-Pages (Petunjuk & Tentang) — configuration.
///
/// Direct port of `src/config/infoPagesConfig.ts` (and the canvas / interaction
/// values from `src/config/menuConfig.ts`) from the Google AI Studio React
/// prototype. Every number below is copied from that source; nothing is
/// estimated.
///
/// Logical design canvas: 412 × 917 (portrait), identical to the Home Screen.

/// A rectangle in logical canvas pixels (or in source-image pixels for crops).
@immutable
class InfoRect {
  const InfoRect(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;

  /// Returns the [index]-th of [count] equal horizontal bands of this rect.
  /// Used only to place accessibility regions over illustrated rows.
  InfoRect verticalSlice(int index, int count) {
    final double bandHeight = h / count;
    return InfoRect(x, y + bandHeight * index, w, bandHeight);
  }
}

/// One rendered region of a transparent PNG.
///
/// Mirrors `CroppedAssetSpec` from the React config.
@immutable
class CroppedAssetSpec {
  const CroppedAssetSpec({
    required this.src,
    required this.semanticLabel,
    required this.naturalWidth,
    required this.naturalHeight,
    required this.crop,
    required this.target,
  });

  /// Flutter asset key (must be declared in pubspec.yaml).
  final String src;

  /// Label used only when the asset is NOT rendered as decorative.
  final String semanticLabel;

  /// Natural pixel size of the PNG the crop rectangle was measured against.
  final int naturalWidth;
  final int naturalHeight;

  /// Source crop rectangle, in natural-image pixels.
  final InfoRect crop;

  /// Destination rectangle, in logical canvas pixels.
  final InfoRect target;
}

@immutable
class InstructionStepText {
  const InstructionStepText({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;
}

@immutable
class InfoBackButtonConfig {
  const InfoBackButtonConfig({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.borderWidth,
    required this.backgroundColor,
    required this.hoverBackgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.focusRingColor,
    required this.shadowDefault,
    required this.shadowHover,
    required this.shadowPressed,
    required this.pressedScale,
    required this.semanticLabel,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double borderWidth;
  final Color backgroundColor;

  /// `.astorya-back-button:hover { background-color: #FFFDF8 }` in index.css.
  final Color hoverBackgroundColor;
  final Color borderColor;
  final Color iconColor;

  /// `.astorya-back-button:focus-visible { outline: 2.5px solid #60300D }`.
  final Color focusRingColor;
  final List<BoxShadow> shadowDefault;
  final List<BoxShadow> shadowHover;
  final List<BoxShadow> shadowPressed;
  final double pressedScale;
  final String semanticLabel;
}

@immutable
class InfoStartButtonConfig {
  const InfoStartButtonConfig({
    required this.label,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.centerX,
  });

  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  final double centerX;
}

@immutable
class InfoFooterConfig {
  const InfoFooterConfig({
    required this.versionText,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.opacity,
    required this.letterSpacingEm,
    required this.lineHeight,
    required this.fontWeight,
  });

  final String versionText;
  final double y;
  final Color color;
  final double fontSize;
  final double opacity;
  final double letterSpacingEm;
  final double lineHeight;
  final FontWeight fontWeight;
}

/// Layout and plaque options for one informational section on Tentang.
@immutable
class AboutInfoSectionConfig {
  const AboutInfoSectionConfig({
    required this.y,
    required this.title,
    required this.containerWidth,
    required this.plaqueWidth,
    required this.plaqueHeight,
    required this.plaqueFontSize,
    required this.containerRadius,
    required this.contentPadding,
    this.compactOrnaments = false,
    this.extendedOrnaments = false,
  });

  final double y;
  final String title;
  final double containerWidth;
  final double plaqueWidth;
  final double plaqueHeight;
  final double plaqueFontSize;
  final double containerRadius;
  final EdgeInsets contentPadding;
  final bool compactOrnaments;
  final bool extendedOrnaments;
}

@immutable
class AboutPageTheme {
  const AboutPageTheme({
    required this.plaqueTop,
    required this.plaqueMid,
    required this.plaqueBottom,
    required this.plaqueBorder,
    required this.plaqueText,
    required this.containerTop,
    required this.containerBottom,
    required this.containerBorder,
    required this.ornamentGold,
    required this.ornamentHighlight,
    required this.textPrimary,
  });

  final Color plaqueTop;
  final Color plaqueMid;
  final Color plaqueBottom;
  final Color plaqueBorder;
  final Color plaqueText;
  final Color containerTop;
  final Color containerBottom;
  final Color containerBorder;
  final Color ornamentGold;
  final Color ornamentHighlight;
  final Color textPrimary;
}

/// Central source of truth for the Petunjuk and Tentang pages.
abstract final class InfoPagesConfig {
  // ---------------------------------------------------------------- canvas
  static const double canvasWidth = 412;
  static const double canvasHeight = 917;

  /// Neutral backdrop around the centred portrait canvas
  /// (`bg-[#F3EFE9]` in `MobileCanvas.tsx`).
  static const Color stageBackdropColor = Color(0xFFF3EFE9);

  /// Fallback colour painted under the background PNG
  /// (`backgroundColor: '#FCECD0'` in `InfoPageShell.tsx`).
  static const Color pageFallbackColor = Color(0xFFFCECD0);

  // ----------------------------------------------------------- interaction
  /// `MENU_CONFIG.interaction.durationMs`.
  static const Duration interactionDuration = Duration(milliseconds: 150);

  /// `MENU_CONFIG.interaction.easing` = cubic-bezier(0.22, 1, 0.36, 1).
  static const Curve interactionCurve = Cubic(0.22, 1, 0.36, 1);

  /// `.astorya-screen-enter` fade: 180 ms, same easing.
  static const Duration screenEnterDuration = Duration(milliseconds: 180);

  // ------------------------------------------------------------ background
  static const String backgroundAsset =
      'asset/petunjuk&tentang/background_petunjuk_tentang.png';

  // ----------------------------------------------------------- back button
  static const InfoBackButtonConfig backButton = InfoBackButtonConfig(
    x: 13,
    y: 37,
    width: 68,
    height: 47,
    borderWidth: 2.25,
    backgroundColor: Color(0xFFFFFFFF),
    hoverBackgroundColor: Color(0xFFFFFDF8),
    borderColor: Color(0xFF9D6122),
    iconColor: Color(0xFF653F15),
    focusRingColor: Color(0xFF60300D),
    // 0px 2px 6px rgba(122, 70, 24, 0.18)
    shadowDefault: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(122, 70, 24, 0.18),
        offset: Offset(0, 2),
        blurRadius: 6,
      ),
    ],
    // 0px 3px 8px rgba(122, 70, 24, 0.24)
    shadowHover: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(122, 70, 24, 0.24),
        offset: Offset(0, 3),
        blurRadius: 8,
      ),
    ],
    // 0px 1px 2px rgba(122, 70, 24, 0.16)
    shadowPressed: <BoxShadow>[
      BoxShadow(
        color: Color.fromRGBO(122, 70, 24, 0.16),
        offset: Offset(0, 1),
        blurRadius: 2,
      ),
    ],
    pressedScale: 0.96,
    semanticLabel: 'Kembali ke Menu Utama',
  );

  // --------------------------------------------------------------- branding
  // Both crops reuse the official Splash Screen artwork (1543 × 1928).
  static const CroppedAssetSpec emblem = CroppedAssetSpec(
    src: 'asset/splash_screen/emblem_astoryaa.png',
    semanticLabel: 'Emblem ASTORYA',
    naturalWidth: 1543,
    naturalHeight: 1928,
    crop: InfoRect(32, 732, 1477, 1196),
    target: InfoRect(154, 115, 104, 84),
  );

  static const CroppedAssetSpec wordmark = CroppedAssetSpec(
    src: 'asset/splash_screen/wordmark.png',
    semanticLabel: 'ASTORYA',
    naturalWidth: 1543,
    naturalHeight: 1928,
    crop: InfoRect(18, 1605, 1507, 323),
    target: InfoRect(140, 204, 133, 28.5),
  );

  // ----------------------------------------------------------------- footer
  static const InfoFooterConfig footer = InfoFooterConfig(
    versionText: '— v1.0.0 —',
    y: 794,
    color: Color(0xFF5D3310),
    fontSize: 12,
    opacity: 0.9,
    letterSpacingEm: 0.03,
    lineHeight: 1.2,
    fontWeight: FontWeight.w600,
  );

  // --------------------------------------------------------------- petunjuk
  static const String petunjukPageLabel = 'Petunjuk Penggunaan ASTORYA';
  static const String petunjukHeading = 'Petunjuk';

  static const CroppedAssetSpec petunjukTitle = CroppedAssetSpec(
    src: 'asset/petunjuk&tentang/isian_petunjuk.png',
    semanticLabel: 'Petunjuk',
    naturalWidth: 941,
    naturalHeight: 1672,
    crop: InfoRect(151, 289, 638, 101),
    target: InfoRect(71.5, 243, 269, 42.6),
  );

  static const CroppedAssetSpec petunjukCards = CroppedAssetSpec(
    src: 'asset/petunjuk&tentang/isian_petunjuk.png',
    semanticLabel: 'Langkah-langkah penggunaan ASTORYA AR: '
        '1. Siapkan buku atau wayang, 2. Arahkan kamera ke marker, '
        '3. Nikmati pengalaman AR',
    naturalWidth: 941,
    naturalHeight: 1672,
    crop: InfoRect(48, 416, 844, 808),
    target: InfoRect(28, 296.5, 356, 340.8),
  );

  /// Same geometry as the Home "Mulai" button, moved below card 3.
  static const InfoStartButtonConfig petunjukStartButton =
      InfoStartButtonConfig(
    label: 'Mulai',
    x: 105,
    y: 651,
    width: 202,
    height: 69,
    centerX: 206,
  );

  static const List<InstructionStepText> petunjukSteps = <InstructionStepText>[
    InstructionStepText(
      number: 1,
      title: '1. Siapkan buku atau wayang',
      description: 'Gunakan halaman buku bergambar atau wayang yang tersedia.',
    ),
    InstructionStepText(
      number: 2,
      title: '2. Arahkan kamera ke marker',
      description: 'Pastikan gambar terlihat jelas di dalam bingkai kamera.',
    ),
    InstructionStepText(
      number: 3,
      title: '3. Nikmati pengalaman AR',
      description: 'Lihat karakter muncul dan dengarkan narasinya.',
    ),
  ];

  // ----------------------------------------------------------------- tentang
  static const String tentangPageLabel = 'Tentang ASTORYA';
  static const String tentangHeading = 'Tentang';
  static const String tentangSectionLabel = 'Informasi tentang ASTORYA';
  static const double tentangBrandOffsetY = -24;
  static const double tentangDividerY = 581;
  static const double tentangDividerWidth = 298;
  static const double tentangDividerHeight = 18;

  static const CroppedAssetSpec tentangTitle = CroppedAssetSpec(
    src: 'asset/petunjuk&tentang/menu_tentang.png',
    semanticLabel: 'Tentang',
    naturalWidth: 3506,
    naturalHeight: 4381,
    crop: InfoRect(20, 163, 3470, 458),
    target: InfoRect(56, 222, 300, 39.6),
  );

  static const CroppedAssetSpec tentangCard = CroppedAssetSpec(
    src: 'asset/petunjuk&tentang/isian_tentang.png',
    semanticLabel: 'Tentang ASTORYA: media edukasi interaktif kisah Ramayana '
        'berbasis Augmented Reality',
    naturalWidth: 3506,
    naturalHeight: 4381,
    crop: InfoRect(53, 129, 3411, 2636),
    target: InfoRect(19.5, 282, 373, 288.2),
  );

  static const List<String> tentangSections = <String>[
    'ASTORYA adalah media edukasi interaktif kisah Ramayana berbasis '
        'Augmented Reality.',
    'Aplikasi ini membantu anak-anak mengenal cerita, tokoh, dan budaya '
        'Nusantara dengan cara yang menyenangkan.',
    'Fitur utama: pembelajaran interaktif, visual AR, dan narasi bilingual.',
  ];

  static const AboutInfoSectionConfig tentangVersionSection =
      AboutInfoSectionConfig(
    y: 608,
    title: 'Versi Aplikasi',
    containerWidth: 152,
    plaqueWidth: 118,
    plaqueHeight: 22,
    plaqueFontSize: 12.5,
    containerRadius: 20,
    contentPadding: EdgeInsets.fromLTRB(12, 14, 12, 6),
    compactOrnaments: true,
  );
  static const String tentangVersionValue = 'v1.0.0';

  static const AboutInfoSectionConfig tentangDeveloperSection =
      AboutInfoSectionConfig(
    y: 676,
    title: 'Pengembang',
    containerWidth: 350,
    plaqueWidth: 146,
    plaqueHeight: 25,
    plaqueFontSize: 14.5,
    containerRadius: 25,
    contentPadding: EdgeInsets.fromLTRB(12, 19, 12, 10),
    extendedOrnaments: true,
  );

  static const List<String> tentangDevelopers = <String>[
    'Ummi Imaroh',
    'Adinda Massa Merah Lawan Tirani',
  ];
  static const String tentangInstitution = 'Politeknik Negeri Semarang';

  static const AboutPageTheme tentangTheme = AboutPageTheme(
    plaqueTop: Color(0xFFCC8D27),
    plaqueMid: Color(0xFFA56315),
    plaqueBottom: Color(0xFF8F510E),
    plaqueBorder: Color(0xFFF0BC52),
    plaqueText: Color(0xFFFFF6E4),
    containerTop: Color.fromRGBO(255, 247, 228, 0.95),
    containerBottom: Color.fromRGBO(255, 238, 204, 0.94),
    containerBorder: Color(0xFFEECA82),
    ornamentGold: Color(0xFFE5A13B),
    ornamentHighlight: Color(0xFFF3C15A),
    textPrimary: Color(0xFF60300D),
  );
}
