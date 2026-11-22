import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../story/story_list_page.dart';
import 'widgets/menu_button.dart';

/// ASTORYA Main Menu — warm Javanese home screen.
///
/// The background PNG already contains the emblem, wordmark, clouds, and
/// candi landscape. Flutter overlays only the four interactive buttons.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ── Palette (matches warm golden theme) ────────────────────────────────────
  static const Color _brownText   = Color(0xFF5C2D00);
  static const Color _goldBorder  = Color(0xFFB07F1E);
  static const Color _fillTop     = Color(0xFFFBEDC0);
  static const Color _fillBottom  = Color(0xFFEED48A);
  static const Color _dialogBg    = Color(0xFFFDF7EA);
  static const Color _subtleText  = Color(0xFF6B5A3E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7EA),
      body: LayoutBuilder(
        builder: (context, box) {
          // Keep 412 × 917 portrait ratio; pillar-box on wide screens.
          const double designW = 412;
          const double designH = 917;
          const double aspect  = designW / designH;

          final double sw = box.maxWidth;
          final double sh = box.maxHeight;

          final double cw, ch;
          if (sw / sh > aspect) {
            ch = sh;
            cw = ch * aspect;
          } else {
            cw = sw;
            ch = cw / aspect;
          }

          return Container(
            color: const Color(0xFFFDF7EA),
            alignment: Alignment.center,
            child: SizedBox(
              width: cw,
              height: ch,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Full-screen background ────────────────────────────────
                  // BoxFit.cover fills the portrait canvas without distortion.
                  Image.asset(
                    'asset/menu_utama/backgorund-menu-utama.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),

                  // ── Menu buttons ─────────────────────────────────────────
                  // The logo+emblem occupies roughly the top 42% of the BG.
                  // Buttons are placed starting at ~43% and spaced downward.
                  SafeArea(
                    child: Align(
                      // Positive Y → push below center → sits in open area.
                      alignment: const Alignment(0, 0.18),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: cw * 0.12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MenuButton(
                              label: 'Mulai',
                              icon: Icons.play_circle_outline_rounded,
                              fillTop: _fillTop,
                              fillBottom: _fillBottom,
                              borderColor: _goldBorder,
                              textColor: _brownText,
                              onTap: () => _goMulai(context),
                            ),
                            SizedBox(height: cw * 0.040),
                            MenuButton(
                              label: 'Petunjuk',
                              icon: Icons.menu_book_rounded,
                              fillTop: _fillTop,
                              fillBottom: _fillBottom,
                              borderColor: _goldBorder,
                              textColor: _brownText,
                              onTap: () => _goPetunjuk(context),
                            ),
                            SizedBox(height: cw * 0.040),
                            MenuButton(
                              label: 'Tentang',
                              icon: Icons.info_outline_rounded,
                              fillTop: _fillTop,
                              fillBottom: _fillBottom,
                              borderColor: _goldBorder,
                              textColor: _brownText,
                              onTap: () => _goTentang(context),
                            ),
                            SizedBox(height: cw * 0.040),
                            MenuButton(
                              label: 'Keluar',
                              icon: Icons.exit_to_app_rounded,
                              fillTop: _fillTop,
                              fillBottom: _fillBottom,
                              borderColor: _goldBorder,
                              textColor: _brownText,
                              onTap: () => _confirmKeluar(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Navigation handlers ───────────────────────────────────────────────────

  void _goMulai(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const StoryListPage()),
    );
  }

  void _goPetunjuk(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const _PlaceholderPage(title: 'Petunjuk')),
    );
  }

  void _goTentang(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const _PlaceholderPage(title: 'Tentang')),
    );
  }

  void _confirmKeluar(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _goldBorder, width: 1.5),
        ),
        title: const Text(
          'Keluar',
          style: TextStyle(
            color: _brownText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(color: _subtleText, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal',
                style: TextStyle(color: _subtleText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldBorder,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // SystemNavigator.pop() exits on Android; is a no-op on web.
              SystemNavigator.pop();
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Minimal placeholder used until Petunjuk and Tentang screens are built.
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF7EA),
        elevation: 0,
        foregroundColor: const Color(0xFF5C2D00),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C2D00),
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Halaman $title',
          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF5C2D00),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
