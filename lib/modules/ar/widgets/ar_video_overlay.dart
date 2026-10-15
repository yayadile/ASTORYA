import 'dart:async';

import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controllers/astorya_ar_controller.dart';
import '../models/ar_story_config.dart';
import '../utils/marker_homography.dart';

/// Overlay video yang menempel pada bidang marker secara 3D.
///
/// Plugin AR tidak punya node video, jadi video dirender sebagai widget
/// Flutter di atas [ARView]. Agar video benar-benar menempel (ikut posisi &
/// perspektif marker), native fork `ar_flutter_plugin_plus` mengirim 4 sudut
/// layar marker tiap frame ([ARMarkerCorners]); overlay ini menghitung
/// homografi dari rect video ke 4 sudut tersebut lalu menerapkannya lewat
/// `Transform` bersudut pandang (perspektif).
///
/// Fallback: bila sudut marker belum pernah diterima (mis. di iOS yang native
///-nya belum mengirim `onMarkerCorners`), video tampil sebagai overlay datar
/// mengambang seperti perilaku lama.
///
/// Sinkronisasi dengan [AstoryaArController]:
/// - marker terdeteksi + cerita `playing`  -> video diputar
/// - cerita `paused` / `completed` / `ready` -> video dijeda
/// - cerita `replay`                        -> video di-seek ke awal lalu main
class ArVideoOverlay extends StatefulWidget {
  const ArVideoOverlay({
    super.key,
    required this.controller,
    required this.config,
    this.markerCorners,
  });

  /// Sumber state playback (markerDetected, state, replay) yang diikuti video.
  final AstoryaArController controller;

  /// Konfigurasi video (path, ukuran, posisi, muted, loop).
  final ArStoryConfig config;

  /// Sudut layar marker per frame dari native (null = marker hilang/belum
  /// tersedia). Bila diberikan, video di-warp menempel pada marker.
  final ValueListenable<ARMarkerCorners?>? markerCorners;

  @override
  State<ArVideoOverlay> createState() => _ArVideoOverlayState();
}

class _ArVideoOverlayState extends State<ArVideoOverlay> {
  VideoPlayerController? _video;
  bool _initialized = false;
  String? _error;

  /// Guard agar play/pause/seek tidak dipanggil berulang tiap rebuild.
  bool _isPlaying = false;

  /// Sudut marker terkini dari native. Nilai null dengan
  /// [_cornersEverReceived] = true berarti marker hilang dari pandangan
  /// (video disembunyikan). Belum pernah menerima apa pun = mode fallback
  /// datar (mis. iOS).
  final ValueNotifier<ARMarkerCorners?> _corners =
      ValueNotifier<ARMarkerCorners?>(null);

  @override
  void initState() {
    super.initState();
    widget.markerCorners?.addListener(_onCornersChanged);
    _setupVideo();
    // Dengarkan perubahan state cerita (play/pause/replay/marker).
    widget.controller.addListener(_onStoryChanged);
  }

  @override
  void didUpdateWidget(covariant ArVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markerCorners != widget.markerCorners) {
      oldWidget.markerCorners?.removeListener(_onCornersChanged);
      widget.markerCorners?.addListener(_onCornersChanged);
      _onCornersChanged();
    }
  }

  void _onCornersChanged() {
    _corners.value = widget.markerCorners?.value;
  }

  Future<void> _setupVideo() async {
    final controller = widget.controller;
    final video = controller.config.videoPath!.trim();

    final VideoPlayerController created;
    if (ArStoryConfig.isNetworkSource(video)) {
      created = VideoPlayerController.networkUrl(Uri.parse(video));
    } else {
      created = VideoPlayerController.asset(
        ArStoryConfig.normalizeAssetKey(video),
      );
    }
    _video = created;

    try {
      await created.initialize();
      if (!mounted) return;

      await created.setLooping(widget.config.videoLoop);
      // Video dibisukan secara bawaan agar tidak bentrok dengan Voiceover.
      await created.setVolume(widget.config.videoMuted ? 0.0 : 1.0);

      setState(() => _initialized = true);
      // Samakan posisi/video dgn state cerita terkini (mis. marker sudah
      // terdeteksi sebelum video selesai dimuat).
      _applyStoryState();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat video: $e');
    }
  }

  void _onStoryChanged() {
    if (!mounted) return;
    _applyStoryState();
  }

  /// Terapkan state playback cerita ke video.
  Future<void> _applyStoryState() async {
    final video = _video;
    if (video == null || !_initialized || _error != null) return;

    final c = widget.controller;
    // Video hanya tampil & diputar setelah marker terdeteksi.
    final shouldPlay = c.markerDetected && c.isPlaying;

    if (shouldPlay) {
      if (!_isPlaying) {
        _isPlaying = true;
        unawaited(video.play());
      }
    } else {
      if (_isPlaying) {
        _isPlaying = false;
        unawaited(video.pause());
      }
      // Saat cerita diulang (replay), kembalikan video ke detik 0.
      if (c.state == ArStoryState.ready) {
        unawaited(video.seekTo(Duration.zero));
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStoryChanged);
    widget.markerCorners?.removeListener(_onCornersChanged);
    _corners.dispose();
    // Dispose sinkron agar aman dipanggil dari dispose() widget induk.
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder memastikan overlay ikut rebuild tiap state cerita
    // berubah (marker terdeteksi, play/pause, replay) tanpa me-rebuild ARView.
    // _corners menambah rebuild halus tiap frame saat marker terlihat.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListenableBuilder(
        listenable: _corners,
        builder: (context, _) => _buildVideo(context),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    final video = _video;
    if (video == null || _error != null) return const SizedBox.shrink();

    // Tunggu marker terdeteksi baru tampilkan (sebelumnya layar kosong).
    // Setelah marker PERNAH terdeteksi, video TETAP tampil walau marker
    // hilang sesaat (mis. user rotate HP) — jatuh ke overlay datar agar
    // tidak kedip hilang.
    if (!_initialized || !widget.controller.markerDetected) {
      return const SizedBox.shrink();
    }

    final aspect = video.value.aspectRatio <= 0 ? 16 / 9 : video.value.aspectRatio;

    // Mode warp: video menempel perspektif pada marker (Android, native fork).
    final corners = _corners.value;
    if (corners != null) {
      return _buildWarpedVideo(context, video, corners, aspect);
    }

    // Sudut belum ada / hilang sesaat / warp gagal (quad/matrix null):
    // tampilkan datar di tengah agar video tetap kelihatan saat rotate HP.
    return _buildFlatVideo(context, video, aspect);
  }

  /// Video di-warp lewat homografi agar menempel pada bidang marker 3D.
  ///
  /// Koordinat sudut marker dari native ternormalisasi terhadap permukaan AR,
  /// yang ukurannya == ukuran Stack ini (ARView mengisi Stack penuh). Pakai
  /// ukuran Stack via LayoutBuilder (bukan MediaQuery, karena bisa berbeda
  /// akibat status bar).
  Widget _buildWarpedVideo(
    BuildContext context,
    VideoPlayerController video,
    ARMarkerCorners corners,
    double aspect,
  ) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackSize = constraints.biggest;
            if (stackSize.isEmpty) return const SizedBox.shrink();

            final quad = computeVideoQuad(
              markerCorners: corners.corners,
              canvasSize: stackSize,
              markerAspect: corners.markerAspect <= 0 ? 1 : corners.markerAspect,
              videoAspect: aspect,
            );
            // Warp gagal (marker nyaris sejajar garis pandang / titik
            // degenerate): jatuh ke overlay datar agar video tetap kelihatan
            // saat rotate HP, bukan hilang.
            if (quad == null) return _buildFlatVideo(context, video, aspect);

            // Ukuran sumber (dipakai rasterisasi video). Kualitas makin tajam
            // bila mendekati ukuran quad di layar; kalikan devicePixelRatio
            // agar hasil warp tidak buram saat marker tampak besar.
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final srcWidth =
                stackSize.width * widget.config.videoWidthFraction * dpr;
            final srcSize = Size(srcWidth, srcWidth / aspect);

            final matrix = videoWarpMatrix(srcSize: srcSize, quad: quad);
            // Matriks liar (sudut nyaris segaris saat rotate ekstrem):
            // fallback datar, jangan hilangkan video.
            if (matrix == null) return _buildFlatVideo(context, video, aspect);

            return Stack(
              children: [
                // Origin (0,0) koordinat sumber dipaku di kiri-atas Stack;
                // homografi sudah memetakan (0,0)-(W,H) ke quad marker di
                // koordinat Stack.
                Positioned(
                  left: 0,
                  top: 0,
                  child: Transform(
                    transform: matrix,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: srcSize.width,
                      height: srcSize.height,
                      // Full-bleed menempel marker: TANPA radius/shadow agar
                      // terlihat menyatu dengan kertas, bukan seperti player.
                      // Border hairline ikut ter-warp sehingga tepi video
                      // terlihat jelas menempel pada tepi marker.
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xB3FFFFFF),
                            width: 2,
                          ),
                        ),
                        child: VideoPlayer(video),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Perilaku lama: video sebagai overlay datar mengambang di tengah layar.
  Widget _buildFlatVideo(
    BuildContext context,
    VideoPlayerController video,
    double aspect,
  ) {
    final size = Size(aspect, 1);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final width = screenWidth * widget.config.videoWidthFraction;
    final height = width / (size.width / size.height);

    final dx = widget.config.videoCenterOffset.dx * screenWidth;
    final dy = widget.config.videoCenterOffset.dy * screenHeight;

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              // ClipRRect agar sudut video ikut membulat mengikuti Container.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: VideoPlayer(video),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
