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
    videoMuted: true, // audio video dibisukan, suara dari Voiceover.
    videoLoop: true,
    subtitles: _page1Cues,
  );

  /// Cerita 2: video 3D TANPA audio (VO & BGM sengaja dikosongkan).
  /// Memakai mode "video model" yang sama (plane + quad GL native), jadi
  /// tetap nempel 3D di atas marker — bukan overlay widget datar.
  /// Tanpa Voiceover tidak ada timeline, jadi subtitle selalu kosong.
  static final ArStoryConfig _videoOnly = ArStoryConfig(
    markerImagePath: _marker,
    // voiceoverUrl & bgmUrl tidak diisi -> cerita tetap jalan (hening).
    modelPath: _plane,
    modelVideoPath: 'assets/videos/pg1.mp4',
    modelVideoRotation: 180,
    videoMuted: true,
    videoLoop: true,
    subtitles: const <SubtitleCue>[],
  );

  /// Cerita 3: video 3D + VO (tanpa BGM) — plane yang sama bertekstur video.
  /// Sebelumnya config ini hanya menampilkan `meshplane.glb` mentah tanpa
  /// video sehingga terlihat seperti "model tidak muncul" (plane-nya
  /// transparan). Kini diisi `modelVideoPath` agar selalu ada visual.
  static final ArStoryConfig _modelStory = ArStoryConfig(
    markerImagePath: _marker,
    voiceoverUrl: 'assets/audio/vo/page1-english.wav',
    modelPath: _plane,
    modelVideoPath: 'assets/videos/pg1.mp4',
    modelVideoRotation: 180,
    videoMuted: true,
    videoLoop: true,
    subtitles: _page1Cues,
  );

  /// Cerita 5: video POP-UP tegak (billboard) — konten sama dengan cerita 1
  /// (VO + BGM + subtitle Dendaka), tapi quad digambar vertikal menghadap
  /// kamera dengan kaki di tengah marker, bukan rebah di kertas.
  /// Untuk demo perbandingan: buka tombol 1 vs tombol ini bergantian.
  static final ArStoryConfig _uprightStory = ArStoryConfig(
    markerImagePath: _marker,
    voiceoverUrl: 'assets/audio/vo/page1-english.wav',
    bgmUrl: 'assets/audio/bgm/bgm1.mp3',
    modelPath: _plane,
    modelVideoPath: 'assets/videos/pg1.mp4',
    modelVideoRotation: 180,
    modelVideoUpright: true,
    videoMuted: true,
    videoLoop: true,
    subtitles: _page1Cues,
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
            subtitle: 'Plane + video 3D nempel marker, hening tanpa VO/BGM',
            icon: Icons.videocam_rounded,
            onTap: () => _openStory(context, _videoOnly),
          ),
          const SizedBox(height: 12),
          _StoryCard(
            title: 'Video + VO (Tanpa BGM)',
            subtitle: 'Plane + video 3D + subtitle Dendaka Forest',
            icon: Icons.temple_buddhist,
            onTap: () => _openStory(context, _modelStory),
          ),
          const SizedBox(height: 12),
          _StoryCard(
            title: 'Video Pop-Up (Tegak)',
            subtitle: 'Video berdiri billboard, kaki di tengah marker',
            icon: Icons.slideshow_rounded,
            onTap: () => _openStory(context, _uprightStory),
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
