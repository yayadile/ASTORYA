import 'package:flutter/foundation.dart';

import '../ar/astorya_ar.dart';

/// Konfigurasi mode WebAR (MindAR di dalam WebView).
///
/// Prinsip berdampingan dengan mode native ([ArStoryConfig] + [AstoryaArView]):
/// - **Native** = ARCore/ARKit, model 3D + warp video widget.
/// - **WebAR** = MindAR image tracking di WebView, video dirender WebGL
///   langsung menempel pada marker.
///
/// Agar tidak ada duplikasi logika, seluruh **audio (VO/BGM), subtitle, dan
/// state playback tetap memakai [AstoryaArController]** yang sama dengan mode
/// native. Yang diganti hanya lapisan render kamera/marker (WebView).
@immutable
class WebArConfig {
  const WebArConfig({
    required this.story,
    this.mindTarget = 'assets/webar/targets.mind',
    this.modelPath = 'assets/models/meshplane.glb',
    this.modelRotationXDegrees = -90.0,
    String? videoPath,
    this.videoMuted = true,
    this.markerHeightRatio = 0.7071,
    this.hintText = 'Arahkan kamera ke gambar marker ASTORYA',
    this.loadingText = 'Menyiapkan kamera WebAR...',
  }) : _videoOverride = videoPath;

  /// Cerita yang dipakai ulang dari mode native: VO, BGM, subtitle, volume,
  /// dan perilaku auto-start. `markerImagePath`-nya dipakai sebagai
  /// dokumentasi sumber gambar yang dikompilasi menjadi `.mind`.
  final ArStoryConfig story;

  /// Target image MindAR: path asset `.mind` **atau** URL `http(s)://`.
  /// File `.mind` dikompilasi dari gambar marker yang sama dengan
  /// [ArStoryConfig.markerImagePath]. Lihat `assets/webar/README.md`.
  final String mindTarget;

  /// Plane GLB yang ditempeli tekstur video: path asset **atau** URL.
  /// Syarat: mesh punya UV + node transform identitas (flat, lihat README).
  /// Geometri plane mengikuti file ini, bukan [markerHeightRatio].
  final String modelPath;

  /// Rotasi plane (derajat) pada sumbu X anchor MindAR. Default -90:
  /// mesh XZ (tiduran, normal +Y) dibaringkan ke bidang anchor XY.
  /// Tanda PENTING: +90 bikin plane menghadap pergi (tak terlihat), -90
  /// + material double-sided = tegak + terlihat + tidak mirror.
  final double modelRotationXDegrees;

  /// Override video khusus WebAR. Bila `null`, memakai `story.videoPath`.
  final String? _videoOverride;

  /// Bisukan audio video agar tidak bentrok dengan Voiceover + BGM.
  final bool videoMuted;

  /// Rasio tinggi/lebar marker (tinggi ÷ lebar). Default A4 landscape
  /// (`2480 ÷ 3508 ≈ 0.7071`). Sekadar dokumentasi fisik kertas; ukuran
  /// plane video mengikuti geometri [modelPath], bukan nilai ini.
  final double markerHeightRatio;

  /// Teks hint saat marker belum ditemukan (ditampilkan HUD Flutter).
  final String hintText;

  /// Teks loading saat halaman WebAR dimuat.
  final String loadingText;

  /// Path/URL video yang dirender di atas marker oleh halaman web.
  /// Urutan: override eksplisit -> `story.modelVideoPath` (mode video model)
  /// -> `story.videoPath` (mode overlay lama).
  String get videoPath {
    final v = _videoOverride?.trim();
    if (v != null && v.isNotEmpty) return v;
    final m = story.modelVideoPath?.trim();
    if (m != null && m.isNotEmpty) return m;
    return story.videoPath?.trim() ?? '';
  }

  bool get hasVideo => videoPath.isNotEmpty;

  /// True bila target adalah URL jaringan.
  bool get isNetworkTarget =>
      ArStoryConfig.isNetworkSource(mindTarget.trim());

  /// Validasi ringan. WebAR **wajib ada video** (tanpa video tidak ada yang
  /// dirender di halaman web) - untuk cerita audio-only pakai mode native.
  String? validate() {
    final storyError = story.validate();
    if (storyError != null) return storyError;
    if (!hasVideo) {
      return 'WebAR membutuhkan video (videoPath kosong)';
    }
    if (mindTarget.trim().isEmpty) {
      return 'mindTarget tidak boleh kosong';
    }
    if (modelPath.trim().isEmpty) {
      return 'modelPath (plane GLB) tidak boleh kosong';
    }
    if (markerHeightRatio <= 0) {
      return 'markerHeightRatio harus > 0';
    }
    return null;
  }

  @override
  String toString() =>
      'WebArConfig(target: $mindTarget, model: $modelPath, video: $videoPath)';
}
