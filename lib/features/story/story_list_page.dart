import 'package:flutter/material.dart';

import '../../modules/ar/astorya_ar.dart';
import '../../modules/webar/webar.dart';

/// Contoh halaman pemanggil modul AR.
///
/// Halaman ini TIDAK tahu apa pun tentang detail AR - cukup menyusun
/// [ArStoryConfig] lalu me-push [AstoryaArView].
class StoryListPage extends StatelessWidget {
  const StoryListPage({super.key});

  // --------------------------------------------------------------- data -----
  //
  // Aset yang benar-benar ada saat ini:
  //   - Marker : 'assets/images/a4_1.png'          (A4, lebar cetak ~21 cm)
  //   - Plane  : 'assets/models/meshplane.glb'     (plane UV-mapped marker)
  //   - Video  : 'assets/videos/pg1.mp4'
  //   - VO     : 'assets/audio/vo/page1-english.wav'
  //   - BGM    : 'assets/audio/bgm/bgm1.mp3'

  /// Marker yang dipakai bersama oleh semua cerita di bawah.
  static const String _marker = 'assets/images/a4_1.png';

  /// Plane yang dipakai mode "video model" (native GL quad + WebAR tekstur).
  static const String _plane = 'assets/models/meshplane.glb';

  /// Cerita 1: video 3D + audio - video ditempel pada plane di atas marker
  /// (native: quad GL per-frame; WebAR: tekstur meshplane.glb). Tracking
  /// beneran, bukan overlay widget.
  static final ArStoryConfig _videoStory = ArStoryConfig(
    markerImagePath: _marker,
    voiceoverUrl: 'assets/audio/vo/page1-english.wav',
    bgmUrl: 'assets/audio/bgm/bgm1.mp3',
    modelPath: _plane,
    modelVideoPath: 'assets/videos/pg1.mp4',
    videoMuted: true, // audio video dibisukan, suara dari Voiceover.
    videoLoop: true,
    subtitles: const <SubtitleCue>[
      SubtitleCue(
        start: 0.0,
        end: 5.0,
        id: 'Selamat datang di cerita ASTORYA.',
        en: 'Welcome to the ASTORYA story.',
      ),
    ],
  );

  /// Cerita 2: video TANPA audio (VO & BGM sengaja dikosongkan).
  /// Berguna buat test murni video/marker tanpa ribet nyiapin suara.
  static final ArStoryConfig _videoOnly = ArStoryConfig(
    markerImagePath: _marker,
    // voiceoverUrl & bgmUrl tidak diisi -> cerita tetap jalan (hening).
    videoPath: 'assets/videos/pg1.mp4',
    videoWidthFraction: 0.82,
    videoMuted: true,
    videoLoop: true,
    subtitles: const <SubtitleCue>[],
  );

  /// Cerita 3: plane 3D mentah (tanpa video) + VO & BGM.
  static final ArStoryConfig _modelStory = ArStoryConfig(
    markerImagePath: _marker,
    voiceoverUrl: 'assets/audio/vo/page1-english.wav',
    bgmUrl: 'assets/audio/bgm/bgm1.mp3',
    modelPath: _plane,
    modelScale: 0.64, // plane 1.414 unit x0.33 android = 0.467 -> x0.64 = 0.299m ≈ lebar marker
    modelLift: 0.02,
    subtitles: const <SubtitleCue>[
      SubtitleCue(
        start: 0.0,
        end: 4.5,
        id: 'Selamat datang di Candi Borobudur.',
        en: 'Welcome to Borobudur Temple.',
      ),
    ],
  );

  /// Cerita 4: mode WebAR (MindAR di WebView) - BERDAMPINGAN dengan mode
  /// native di atas, bukan pengganti. Memakai cerita video+audio yang sama
  /// (VO/BGM/subtitle dipakai ulang), tapi render kamera + tracking marker
  /// oleh MindAR. Butuh `assets/webar/targets.mind` + internet (CDN).
  /// Lihat `lib/modules/webar/RULES.md` untuk kapan memakai mode ini.
  static final WebArConfig _webArStory = WebArConfig(story: _videoStory);

  // -------------------------------------------------------------- handlers --

  void _openStory(BuildContext context, ArStoryConfig config) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AstoryaArView(config: config),
      ),
    );
  }

  void _openWebArStory(BuildContext context, WebArConfig config) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WebArView(config: config),
      ),
    );
  }

  // ---------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASTORYA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StoryCard(
            title: 'Video 3D + Audio',
            subtitle: 'Marker + plane GLB bertekstur video + VO & BGM',
            icon: Icons.play_circle_fill_rounded,
            onTap: () => _openStory(context, _videoStory),
          ),
          const SizedBox(height: 12),
          _StoryCard(
            title: 'Video Saja (Tanpa Audio)',
            subtitle: 'Test murni video/marker, VO & BGM kosong',
            icon: Icons.videocam_rounded,
            onTap: () => _openStory(context, _videoOnly),
          ),
          const SizedBox(height: 12),
          _StoryCard(
            title: 'Model 3D',
            subtitle: 'Marker + plane meshplane.glb mentah + VO & BGM',
            icon: Icons.temple_buddhist,
            onTap: () => _openStory(context, _modelStory),
          ),
          const SizedBox(height: 12),
          _StoryCard(
            title: 'WebAR (MindAR)',
            subtitle: 'Mode browser: video nempel marker, butuh targets.mind',
            icon: Icons.public_rounded,
            onTap: () => _openWebArStory(context, _webArStory),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF151A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF7B4BFF),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
