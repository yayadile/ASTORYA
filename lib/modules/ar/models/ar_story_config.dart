import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'subtitle_cue.dart';

/// Jenis visual yang ditanam di atas marker.
enum ArVisualKind {
  /// Tidak ada visual (kamera saja, cerita tetap jalan).
  none,

  /// File `.glb` dari folder asset Flutter.
  localGlb,

  /// File `.gltf` dari folder asset Flutter.
  localGltf,

  /// File `.glb` dari internet (wajib `.glb`, plugin hanya punya tipe webGLB).
  networkGlb,

  /// Gambar 2D (png) sebagai overlay di atas marker.
  imageOverlay,
}

/// Deskripsi satu cerita AR: marker, audio, subtitle, dan visual 3D.
///
/// [AstoryaArView] hanya membaca config ini, sehingga halaman mana pun bisa
/// memakai ulang modul AR cukup dengan membuat instance config baru -
/// tanpa perlu mengubah isi module.
@immutable
class ArStoryConfig {
  const ArStoryConfig({
    required this.markerImagePath,
    this.voiceoverUrl,
    this.bgmUrl,
    this.subtitles = const <SubtitleCue>[],
    this.modelPath,
    this.modelVideoPath,
    this.modelVideoRotation = 0,
    this.modelVideoMirrored = false,
    this.overlayImagePath,
    this.modelScale = 1.0,
    this.modelLift = 0.0,
    this.modelRotationYDegrees = 0.0,
    this.videoPath,
    this.videoWidthFraction = 0.82,
    this.videoCenterOffset = const Offset(0, -0.04),
    this.videoMuted = true,
    this.videoLoop = true,
    this.initialVoiceoverVolume = 1.0,
    this.initialBgmVolume = 0.3,
    this.loopBgm = true,
    this.autoStartOnMarkerDetected = true,
    this.continuousImageTracking = true,
    this.imageTrackingUpdateIntervalMs = 100,
    this.lightIntensityMultiplier = 1.0,
    this.showCoachingOverlay = true,
    this.hintText = 'Arahkan kamera ke gambar marker ASTORYA',
    this.loadingText = 'Menyiapkan kamera AR...',
  });

  // ---------------------------------------------------------------- marker ---

  /// Path asset gambar marker yang harus dikenali kamera.
  /// Contoh: `assets/markers/marker_borobudur.jpg`
  ///
  /// Catatan: plugin memakai lebar fisik marker **20 cm** (hardcode di native
  /// Android & iOS). Cetak/tampilkan marker dengan lebar ~20 cm (mis. A4
  /// portrait 21 cm) agar skala 3D-nya akurat.
  final String markerImagePath;

  // ----------------------------------------------------------------- audio ---

  /// URL `http(s)://` **atau** path asset Voiceover (`.mp3` / `.wav`).
  /// Contoh asset: `assets/audio/vo/page1-english.wav`
  ///
  /// **Opsional** - bila `null` (atau kosong), cerita tetap berjalan tanpa
  /// suara narasi. Berguna untuk test murni visual/video.
  final String? voiceoverUrl;

  /// URL `http(s)://` **atau** path asset BGM (`.mp3`).
  ///
  /// **Opsional** - bila `null` (atau kosong), BGM tidak diputar.
  final String? bgmUrl;

  /// Volume awal Voiceover, 0.0 - 1.0 (default 100%).
  final double initialVoiceoverVolume;

  /// Volume awal BGM, 0.0 - 1.0 (default 30%).
  final double initialBgmVolume;

  /// BGM di-loop selama cerita berjalan.
  final bool loopBgm;

  // ------------------------------------------------------------- subtitle ---

  /// Daftar subtitle yang di-sync ke posisi Voiceover.
  final List<SubtitleCue> subtitles;

  // ---------------------------------------------------------------- visual ---

  /// Path asset / URL model 3D. Opsional.
  ///
  /// - `.glb` asset : `assets/models/candi.glb`
  /// - `.gltf` asset: `assets/models/candi.gltf` (beserta .bin & teksturnya)
  /// - `.glb` web   : `https://contoh.com/candi.glb`
  ///
  /// Biarkan `null` untuk memakai [overlayImagePath], atau keduanya `null`
  /// bila tidak ingin menampilkan visual di atas marker.
  ///
  /// **Pengecualian**: bila [modelVideoPath] diisi, node model TIDAK
  /// ditambahkan ke scene (native merender video langsung sebagai quad GL
  /// yang nempel marker per-frame). `modelPath` tetap wajib diisi sebagai
  /// penanda plane (`meshplane.glb`) agar WebAR memakai file yang sama.
  final String? modelPath;

  /// Path asset / URL video (`.mp4`) yang ditempel pada plane model di atas
  /// marker — mode native "video model" (tracking 3D beneran).
  ///
  /// Syarat: [modelPath] wajib diisi (`meshplane.glb`). Bila diisi, overlay
  /// widget video ([videoPath]/[hasVideo]) HARUS kosong agar tidak tampil
  /// ganda — video hanya dirender native sebagai quad GL per-frame.
  ///
  /// WebAR memakai field yang sama sebagai tekstur `meshplane.glb`.
  final String? modelVideoPath;

  /// Rotasi video model searah jarum jam dalam derajat: 0, 90, 180, 270.
  ///
  /// Samakan dengan orientasi cetak marker: bila video tampak miring/
  /// kebalik di atas kertas, naikkan ke 90/180/270 sampai tegak. Tidak
  /// berpengaruh ke audio/subtitle.
  final int modelVideoRotation;

  /// Balik video secara horizontal (efek kaca).
  ///
  /// `true` bila teks/gambar di video tampak kebaca terbalik kiri-kanan
  /// di atas marker (sumbu-X marker vs layar berlawanan arah). Tidak
  /// berpengaruh ke audio/subtitle. Bisa dikombinasi dengan
  /// [modelVideoRotation].
  final bool modelVideoMirrored;

  /// Path asset gambar 2D (.png) yang dirender di atas marker,
  /// dipakai bila [modelPath] tidak diisi.
  final String? overlayImagePath;

  /// Skala tambahan untuk model di atas marker. `1.0` = memakai skala bawaan
  /// native (iOS x0.4, Android x0.33).
  final double modelScale;

  /// Jarak angkat model dari permukaan marker, dalam **meter**.
  /// Contoh: `0.02` = mengambang 2 cm di atas marker.
  final double modelLift;

  /// Rotasi model terhadap sumbu Y marker, dalam derajat.
  final double modelRotationYDegrees;

  // --------------------------------------------------------------- video ---

  /// Path asset / URL video (`.mp4`) yang ditampilkan sebagai overlay
  /// **mengambang di atas marker**.
  ///
  /// Berbeda dengan [modelPath] (node 3D AR), video dirender sebagai widget
  /// Flutter (`video_player`) sehingga tidak mengikuti perspektif/miring
  /// marker secara 3D - cocok untuk "layar" yang menempel di atas marker.
  ///
  /// - Asset : `assets/videos/borobudur.mp4`
  /// - URL   : `https://contoh.com/borobudur.mp4`
  ///
  /// Biarkan `null` bila tidak menampilkan video.
  final String? videoPath;

  /// Lebar video overlay sebagai fraksi dari lebar layar. `0.82` = 82% lebar.
  final double videoWidthFraction;

  /// Posisi video overlay terhadap tengah layar dalam satuan fraksi
  /// (x = lebar layar, y = tinggi layar). `0` = persis di tengah,
  /// negatif = naik ke atas. Default sedikit di atas tengah agar tidak
  /// tertutup subtitle di bawah.
  final Offset videoCenterOffset;

  /// Bisukan audio video. `true` (default) agar tidak bentrok dengan
  /// Voiceover + BGM yang sudah diatur terpisah oleh controller.
  final bool videoMuted;

  /// Putar video berulang (loop) selama cerita berjalan.
  final bool videoLoop;

  // ------------------------------------------------------------- perilaku ---

  /// Mulai cerita otomatis saat marker pertama kali terdeteksi.
  final bool autoStartOnMarkerDetected;

  /// Terus update posisi model agar "nempel" mengikuti marker.
  /// Matikan bila hanya butuh deteksi sekali.
  final bool continuousImageTracking;

  /// Interval update tracking dalam ms (hanya relevan bila
  /// [continuousImageTracking] true). Kecil = mulus tapi lebih boros CPU.
  final int imageTrackingUpdateIntervalMs;

  /// Pengali pencahayaan model. `1.0` = default.
  final double lightIntensityMultiplier;

  /// Tampilkan coaching overlay bawaan ARKit/ARCore.
  final bool showCoachingOverlay;

  /// Teks hint saat marker belum terdeteksi.
  final String hintText;

  /// Teks loading saat kamera AR sedang disiapkan.
  final String loadingText;

  // ------------------------------------------------------------ utilitas ----

  /// True bila sumber audio adalah jaringan (http/https).
  static bool isNetworkSource(String source) {
    final s = source.trim().toLowerCase();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  /// Normalisasi path asset -> kunci asset Flutter.
  /// `asset/assets/audio/vo/x.mp3` -> `assets/audio/vo/x.mp3`
  static String normalizeAssetKey(String source) {
    var s = source.trim();
    while (s.startsWith('asset/')) {
      s = s.substring('asset/'.length);
    }
    return s;
  }

  /// Nama file marker tanpa ekstensi. Native mengirim `imageName` dengan
  /// format ini saat deteksi, dipakai untuk mencocokkan marker yang benar.
  String get markerImageName {
    final fileName = markerImagePath.split('/').last;
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }

  /// true bila ada video overlay yang harus ditampilkan di atas marker.
  bool get hasVideo {
    final v = videoPath?.trim();
    return v != null && v.isNotEmpty;
  }

  /// true bila mode "video model" aktif: video ditempel pada plane model
  /// (`meshplane.glb`) — native via quad GL per-frame, WebAR via tekstur.
  /// BUKAN overlay widget, jadi tidak memakai [videoPath]/[hasVideo].
  bool get hasModelVideo {
    final v = modelVideoPath?.trim();
    return v != null && v.isNotEmpty;
  }

  /// true bila voiceover diisi (tidak null / tidak kosong).
  bool get hasVoiceover {
    final v = voiceoverUrl?.trim();
    return v != null && v.isNotEmpty;
  }

  /// true bila BGM diisi (tidak null / tidak kosong).
  bool get hasBgm {
    final v = bgmUrl?.trim();
    return v != null && v.isNotEmpty;
  }

  /// Jenis visual (node AR 3D / gambar) yang akan dirender di atas marker.
  ///
  /// Catatan: video overlay **tidak** masuk ke [ArVisualKind] karena video
  /// dirender sebagai widget Flutter, bukan node AR. Lihat [hasVideo].
  ArVisualKind get visualKind {
    final model = modelPath?.trim();
    if (model != null && model.isNotEmpty) {
      if (isNetworkSource(model)) return ArVisualKind.networkGlb;
      return model.toLowerCase().endsWith('.gltf')
          ? ArVisualKind.localGltf
          : ArVisualKind.localGlb;
    }
    final overlay = overlayImagePath?.trim();
    if (overlay != null && overlay.isNotEmpty) return ArVisualKind.imageOverlay;
    return ArVisualKind.none;
  }

  /// Validasi ringan. Mengembalikan pesan error pertama, atau `null` bila valid.
  ///
  /// VO & BGM **tidak lagi wajib** - cerita bisa jalan tanpa keduanya
  /// (mis. untuk test murni video/marker). Bila diisi, tidak divalidasi
  /// lebih lanjut di sini.
  String? validate() {
    if (markerImagePath.trim().isEmpty) {
      return 'markerImagePath tidak boleh kosong';
    }
    if (hasModelVideo && (modelPath?.trim().isEmpty ?? true)) {
      return 'modelVideoPath membutuhkan modelPath (meshplane.glb)';
    }
    if (hasModelVideo && hasVideo) {
      return 'modelVideoPath dan videoPath tidak boleh diisi bersamaan';
    }
    if (modelVideoRotation != 0 &&
        modelVideoRotation != 90 &&
        modelVideoRotation != 180 &&
        modelVideoRotation != 270) {
      return 'modelVideoRotation harus 0/90/180/270';
    }
    for (final cue in subtitles) {
      if (cue.end <= cue.start) {
        return 'Subtitle cue "${cue.id}" tidak valid (end <= start)';
      }
    }
    return null;
  }

  @override
  String toString() =>
      'ArStoryConfig(marker: $markerImagePath, visual: ${visualKind.name})';
}
