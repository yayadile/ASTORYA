import 'package:flutter/material.dart';

import '../../modules/ar/astorya_ar.dart';

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
  //   - SRT    : 'assets/srt/page1-english.srt'    (sumber teks subtitle,
  //              disalin manual ke _page1Cues di bawah)

  /// Marker yang dipakai bersama oleh semua cerita di bawah.
  static const String _marker = 'assets/images/a4_1.png';

  /// Plane yang dipakai mode "video model" (native GL quad + WebAR tekstur).
  static const String _plane = 'assets/models/meshplane.glb';

  /// Subtitle cerita halaman 1 — disalin dari `assets/srt/page1-english.srt`
  /// (file .srt TIDAK dibaca otomatis oleh app, jadi setiap ubah .srt wajib
  /// salin ulang ke sini lalu rebuild).
  ///
  /// Sinkron ke posisi Voiceover, jadi hanya tampil pada config yang mengisi
  /// `voiceoverUrl`. Rentang waktu harus sama dengan .srt.
  static const List<SubtitleCue> _page1Cues = <SubtitleCue>[
    SubtitleCue(
      start: 0.0,
      end: 6.0,
      id: 'Di Hutan Dendaka yang indah,\nSinta melihat kijang emas yang berkilau.',
      en: 'In the beautiful Dendaka Forest,\nSinta saw dazzling golden deer.',
    ),
    SubtitleCue(
      start: 6.0,
      end: 8.36,
      id: 'Dia meminta Rama untuk menangkapnya.',
      en: 'She asked Rama to catch it for her.',
    ),
    SubtitleCue(
      start: 8.36,
      end: 14.16,
      id: 'Demi membahagiakan istrinya, Rama masuk jauh ke dalam\nhutan gelap untuk mengejar kijang emas itu.',
      en: 'To make his wife happy, Rama went deep into\nthe dark forest to chase the golden deer',
    ),
  ];

  /// Cerita 1: video 3D + audio - video ditempel pada plane di atas marker
  /// (native: quad GL per-frame; WebAR: tekstur meshplane.glb). Tracking
  /// beneran, bukan overlay widget.
  static final ArStoryConfig _videoStory = ArStoryConfig(
    markerImagePath: _marker,
    voiceoverUrl: 'assets/audio/vo/page1-english.wav',
    bgmUrl: 'assets/audio/bgm/bgm1.mp3',
    modelPath: _plane,
    modelVideoPath: 'assets/videos/pg1.mp4',
    modelVideoRotation: 180,
    modelVideoMirrored: true,
    videoMuted: true, // audio video dibisukan, suara dari Voiceover.
    videoLoop: true,
    subtitles: _page1Cues,
  );

  // -------------------------------------------------------------- handlers --

  void _openStory(BuildContext context, ArStoryConfig config) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AstoryaArView(config: config),
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
