import 'package:flutter/material.dart';

/// Overlay transparan di atas halaman AR untuk mode video fullscreen.
///
/// Videonya sendiri digambar oleh NATIVE (quad menutupi layar, player yang
/// sama dengan mode marker) sehingga Voiceover/BGM tidak kehilangan audio
/// focus - tidak ada player kedua. Widget ini hanya berisi tombol tutup
/// (+ hint bila marker belum terdeteksi).
///
/// Harus dibuka lewat route transparan (`PageRouteBuilder(opaque: false)`)
/// agar quad native di bawahnya tetap terlihat.
class ArFullscreenVideo extends StatelessWidget {
  const ArFullscreenVideo({
    super.key,
    required this.markerDetected,
  });

  /// True bila marker sudah pernah terdeteksi (video sedang tampil penuh).
  final bool markerDetected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Hint hanya bila video belum tampil (player belum siap).
            if (!markerDetected)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Arahkan kamera ke marker untuk memulai video',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
            // Tombol tutup selalu terlihat di kiri atas.
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: const Color(0xF20B0E1A),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.fullscreen_exit_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
