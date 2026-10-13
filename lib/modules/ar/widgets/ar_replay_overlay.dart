import 'package:flutter/material.dart';

/// Overlay tengah layar berisi scrim gelap + tombol "Putar Ulang Cerita".
///
/// Ditampilkan saat Voiceover selesai. Scrim sengaja dibuat *ignore pointer*
/// supaya tombol lain di belakangnya (control bar, subtitle) tetap hidup.
class ArReplayOverlay extends StatelessWidget {
  const ArReplayOverlay({super.key, required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: ColoredBox(color: Color(0x99000000)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: const Color(0xFF7B4BFF),
                  shape: const CircleBorder(),
                  elevation: 8,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onReplay,
                    child: const Padding(
                      padding: EdgeInsets.all(22),
                      child: Icon(
                        Icons.replay_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Putar Ulang Cerita',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
