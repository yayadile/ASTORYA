import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../story/story_list_page.dart';
import '../info_pages/info_page_route.dart';
import '../petunjuk/petunjuk_page.dart';
import '../tentang/tentang_page.dart';
import 'home_config.dart';
import 'widgets/menu_button.dart';

/// ASTORYA Main Menu (port of MainMenu.tsx + MobileCanvas.tsx).
///
/// The visual canvas is the supplied 412 x 917 Flutter conversion. Optional
/// callbacks allow callers to override navigation, while the no-argument
/// constructor used by the splash screen keeps the existing routes active.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onStart,
    this.onInstructions,
    this.onAbout,
    this.onExit,
  });

  final VoidCallback? onStart;
  final VoidCallback? onInstructions;
  final VoidCallback? onAbout;
  final VoidCallback? onExit;

  VoidCallback _callbackFor(BuildContext context, MenuButtonId id) {
    switch (id) {
      case MenuButtonId.start:
        return _startHandler(context);
      case MenuButtonId.instructions:
        return onInstructions ?? () => _goPetunjuk(context);
      case MenuButtonId.about:
        return onAbout ?? () => _goTentang(context);
      case MenuButtonId.exit:
        return onExit ?? () => _confirmKeluar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeConfig.pageBackdrop,
      body: Center(
        // Uniform scale: min(width / 412, height / 917), centered, no stretch.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: kHomeDesignWidth,
            height: kHomeDesignHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        HomeConfig.backgroundAsset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  for (final button in HomeConfig.buttons)
                    Positioned(
                      left: button.x,
                      top: button.y,
                      width: button.width,
                      height: button.height,
                      child: MenuButton(
                        config: button,
                        onPressed: _callbackFor(context, button.id),
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

  VoidCallback _startHandler(BuildContext context) =>
      onStart ?? () => _goMulai(context);

  // Existing Mulai behavior is retained; scanner-route changes are outside
  // this information-page integration.
  void _goMulai(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const StoryListPage()),
    );
  }

  void _goPetunjuk(BuildContext context) {
    Navigator.push<void>(
      context,
      InfoPageRoute<void>(
        builder: (_) => PetunjukPage(
          onStart: _startHandler(context),
          startButtonBuilder: (_, config, onPressed) => MenuButton(
            config: MenuButtonConfig(
              id: MenuButtonId.start,
              label: config.label,
              width: config.width,
              height: config.height,
              x: config.x,
              y: config.y,
            ),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  void _goTentang(BuildContext context) {
    Navigator.push<void>(
      context,
      InfoPageRoute<void>(builder: (_) => const TentangPage()),
    );
  }

  void _confirmKeluar(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFDF7EA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFB07F1E), width: 1.5),
        ),
        title: const Text(
          'Keluar',
          style: TextStyle(
            color: Color(0xFF5C2D00),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(color: Color(0xFF6B5A3E), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF6B5A3E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB07F1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // SystemNavigator.pop() exits on Android; it is a no-op on web.
              SystemNavigator.pop();
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }
}
