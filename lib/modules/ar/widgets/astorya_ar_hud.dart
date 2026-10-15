import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/astorya_ar_controller.dart';
import 'ar_control_bar.dart';
import 'ar_marker_hint.dart';
import 'ar_replay_overlay.dart';
import 'ar_subtitle_overlay.dart';

/// Seluruh overlay di atas kamera AR: control bar, popup volume,
/// subtitle, hint marker, loading, error, dan tombol replay.
///
/// Widget ini **hanya** membaca [AstoryaArController] lewat [AnimatedBuilder],
/// sehingga perubahan state playback tidak pernah me-rebuild [ARView] di bawahnya.
class AstoryaArHud extends StatefulWidget {
  const AstoryaArHud({
    super.key,
    required this.controller,
    required this.isReady,
    this.arError,
    this.onClose,
    this.onFullscreen,
  });

  final AstoryaArController controller;

  /// true bila session AR + image tracking database sudah siap.
  final bool isReady;

  /// Error dari sisi AR (session/image tracking). Error audio dibaca
  /// langsung dari [AstoryaArController.error].
  final String? arError;

  /// Ditampilkan di tombol tutup control bar.
  final VoidCallback? onClose;

  /// Ditampilkan di tombol fullscreen control bar (hanya bila ada video).
  final VoidCallback? onFullscreen;

  @override
  State<AstoryaArHud> createState() => _AstoryaArHudState();
}

class _AstoryaArHudState extends State<AstoryaArHud> {
  ArControlPopup _activePopup = ArControlPopup.none;

  void _closePopup() {
    if (_activePopup == ArControlPopup.none) return;
    setState(() => _activePopup = ArControlPopup.none);
  }

  void _run(Future<void> future) => unawaited(future);

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.config;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final error = widget.arError ?? c.error;
        final loading = !widget.isReady && error == null;
        final showHint =
            widget.isReady && !c.markerDetected && error == null;

        // Urutan Stack = urutan gambar (paling akhir = paling atas).
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Tombol replay (scrim-nya tidak menangkap tap)
            if (c.canReplay)
              ArReplayOverlay(onReplay: () => _run(c.replay())),

            // 2. Subtitle mengambang di bawah layar
            ArSubtitleOverlay(text: c.subtitleText, language: c.language),

            // 3. Petunjuk arahkan marker
            if (showHint) ArMarkerHint(text: config.hintText),

            // 4. Layar loading inisialisasi AR
            if (loading) _LoadingOverlay(text: config.loadingText),

            // 5. Lapisan penutup popup: tap di luar bar menutup popup
            if (_activePopup != ArControlPopup.none)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closePopup,
                ),
              ),

            // 6. Control bar + banner error (selalu paling atas)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                // Material transparan menjamin widget seperti DropdownButton
                // punya ancestor Material di mana pun halaman ini dipakai.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ArControlBar(
                        state: c.state,
                        voiceoverVolume: c.voiceoverVolume,
                        bgmVolume: c.bgmVolume,
                        language: c.language,
                        activePopup: _activePopup,
                        onActivePopupChanged: (popup) {
                          if (popup == _activePopup) return;
                          setState(() => _activePopup = popup);
                        },
                        onTogglePlay: () => _run(c.toggle()),
                        onVoiceoverVolumeChanged: (v) =>
                            _run(c.setVoiceoverVolume(v)),
                        onBgmVolumeChanged: (v) => _run(c.setBgmVolume(v)),
                        onLanguageChanged: (lang) {
                          _closePopup();
                          c.setLanguage(lang);
                        },
                        onClose: widget.onClose,
                        onFullscreen: widget.onFullscreen,
                      ),
                      if (error != null) _ErrorBanner(message: error),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layar penuh saat kamera AR / image tracking sedang disiapkan.
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xCC000000),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF7B4BFF)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner error di bawah control bar.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF2A3241C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
