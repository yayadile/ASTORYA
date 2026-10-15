import 'dart:async';
import 'dart:math' as math;

import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:ar_flutter_plugin_plus/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'controllers/astorya_ar_controller.dart';
import 'models/ar_story_config.dart';
import 'widgets/ar_fullscreen_video.dart';
import 'widgets/ar_video_overlay.dart';
import 'widgets/astorya_ar_hud.dart';

/// Halaman AR utama ASTORYA.
///
/// Menggabungkan kamera AR + image tracking marker dengan overlay HUD
/// (control bar, popup volume, subtitle, hint, tombol replay).
///
/// Widget ini **terisolasi dari UI utama** - cukup push dari halaman mana pun:
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => AstoryaArView(config: config)),
/// );
/// ```
class AstoryaArView extends StatefulWidget {
  const AstoryaArView({
    super.key,
    required this.config,
    this.onClose,
  });

  /// Konfigurasi marker / audio / subtitle / visual untuk cerita ini.
  final ArStoryConfig config;

  /// Dipanggil saat user menutup layar AR.
  /// Default: `Navigator.maybePop(context)`.
  final VoidCallback? onClose;

  @override
  State<AstoryaArView> createState() => _AstoryaArViewState();
}

class _AstoryaArViewState extends State<AstoryaArView> {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  ARNode? _visualNode;

  late final AstoryaArController _controller;

  bool _sessionInitialized = false;
  bool _trackingConfigured = false;
  String? _arError;
  bool _disposed = false;

  /// Guard agar event tracking rapat tidak membuat node ganda.
  bool _nodeAddInFlight = false;

  /// Status terakhir sudut marker, untuk log transisi warp <-> flat
  /// (sekali per perubahan, bukan tiap frame).
  bool _cornersActive = false;

  /// Sudut layar marker per frame dari native, diteruskan ke
  /// [ArVideoOverlay] agar video bisa di-warp menempel pada marker.
  final ValueNotifier<ARMarkerCorners?> _markerCorners =
      ValueNotifier<ARMarkerCorners?>(null);

  @override
  void initState() {
    super.initState();

    final validationError = widget.config.validate();
    if (validationError != null) {
      // Ditulis langsung (bukan lewat setState) karena masih sebelum build.
      _arError = 'Konfigurasi AR tidak valid: $validationError';
    }

    _controller = AstoryaArController(widget.config);
    _controller.addListener(_onControllerChanged);
    if (validationError == null) {
      unawaited(_controller.init());
    }
  }

  /// Teruskan state cerita ke video marker native (main/jeda/seek replay),
  /// sejajar dengan [ArVideoOverlay] pada mode overlay widget.
  void _onControllerChanged() {
    if (_disposed) return;
    final objects = _objectManager;
    if (objects == null || !widget.config.hasModelVideo) return;
    final c = _controller;
    final wantPlaying = c.markerDetected && c.isPlaying;
    debugPrint(
      '[ASTORYA] markerVideo wantPlaying=$wantPlaying '
      '(marker=${c.markerDetected} state=${c.state.name})',
    );
    unawaited(
      objects.setMarkerVideoPlaying(wantPlaying),
    );
    // Saat cerita diulang (replay), kembalikan video ke detik 0.
    if (c.state == ArStoryState.ready) {
      unawaited(objects.seekMarkerVideo(Duration.zero));
    }
  }

  // ============================================================ AR SESSION ==

  Future<void> _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    if (_disposed) {
      // Widget sudah dilepas ketika callback tiba - langsung rapikan agar
      // sesi kamera tidak bocor.
      unawaited(arSessionManager.dispose());
      return;
    }

    _sessionManager = arSessionManager;
    _objectManager = arObjectManager;

    // Callback dipasang SEBELUM onInitialize agar tidak kehilangan event.
    arSessionManager.onImageTrackingConfigured = _onImageTrackingConfigured;
    arSessionManager.onImageDetected = _onImageDetected;
    arSessionManager.onMarkerCorners = _onMarkerCorners;

    try {
      await arSessionManager.onInitialize(
        // Marker-only experience: tanpa plane/feature point.
        showFeaturePoints: false,
        showPlanes: false,
        showWorldOrigin: false,
        handleTaps: false,
        showAnimatedGuide: widget.config.showCoachingOverlay,
        autoHideCoachingOverlay: true,
        // --- Image tracking ---
        trackingImagePaths: <String>[widget.config.markerImagePath],
        continuousImageTracking: widget.config.continuousImageTracking,
        imageTrackingUpdateIntervalMs:
            widget.config.imageTrackingUpdateIntervalMs,
        lightIntensityMultiplier: widget.config.lightIntensityMultiplier,
      );

      arObjectManager.onInitialize();

      // Mode "video model": siapkan video marker native (quad GL yang
      // nempel marker per-frame). Node Filament TIDAK dipakai - quad
      // diposisikan langsung dari sudut marker ARCore tiap frame.
      if (widget.config.hasModelVideo) {
        unawaited(_setupMarkerVideo());
      }

      if (!_disposed && mounted) {
        setState(() => _sessionInitialized = true);
      }
    } catch (e) {
      _setArError('Gagal inisialisasi AR: $e');
    }
  }

  void _onImageTrackingConfigured(bool success) {
    if (_disposed || !mounted) return;
    setState(() {
      _trackingConfigured = true;
      if (!success) {
        _arError = 'Image tracking gagal disiapkan. Pastikan path marker '
            'benar dan sudah terdaftar di bagian assets pubspec.yaml.';
      }
    });
  }

  /// Event dari native setiap kali marker terlihat oleh kamera.
  ///
  /// Dengan `continuousImageTracking: true` callback ini dipanggil berulang,
  /// sehingga: update posisi model dilakukan terus-menerus, sedangkan aksi
  /// "mulai cerita" hanya dipicu sekali (di-guard di dalam controller).
  Future<void> _onImageDetected(
    String imageName,
    vm.Matrix4 transformation,
  ) async {
    if (_disposed || !mounted) return;

    final first = !_controller.markerDetected;
    await _syncVisualToMarker(transformation);
    _controller.onMarkerDetected();
    if (first) {
      debugPrint('[ASTORYA] marker terdeteksi: $imageName (video mulai)');
    }
  }

  /// Sudut layar marker tiap frame dari native. Nilai `null` = marker hilang
  /// dari pandangan (video disembunyikan oleh [ArVideoOverlay]).
  ///
  /// Hanya menulis ke ValueNotifier (tanpa setState) karena event datang
  /// sangat rapat (~tiap frame); rebuild dibatasi pada overlay video.
  void _onMarkerCorners(ARMarkerCorners? corners) {
    if (_disposed) return;
    final active = corners != null;
    if (active != _cornersActive) {
      _cornersActive = active;
      debugPrint(
        active
            ? '[ASTORYA] sudut marker AKTIF -> video warp nempel marker'
            : '[ASTORYA] sudut marker HILANG -> video jatuh ke tengah (flat)',
      );
    }
    _markerCorners.value = corners;
  }

  /// Siapkan video marker native untuk mode "video model".
  Future<void> _setupMarkerVideo() async {
    final objects = _objectManager;
    if (objects == null || _disposed) return;
    final config = widget.config;
    final raw = config.modelVideoPath!.trim();
    final kind = ArStoryConfig.isNetworkSource(raw)
        ? 'url'
        : _isFilePath(raw)
            ? 'file'
            : 'asset';
    final key = ArStoryConfig.normalizeAssetKey(raw);
    debugPrint('[ASTORYA] setupMarkerVideo: kind=$kind path=$key '
        'upright=${config.modelVideoUpright} rotation=${config.modelVideoRotation}');
    try {
      final ok = await objects.setupMarkerVideo(
        key,
        kind: kind,
        loop: config.videoLoop,
        muted: config.videoMuted,
        autoplay: _controller.markerDetected && _controller.isPlaying,
        rotation: config.modelVideoRotation,
        upright: config.modelVideoUpright,
      );
      debugPrint('[ASTORYA] setupMarkerVideo result: $ok');
    } catch (e) {
      debugPrint('[ASTORYA] setupMarkerVideo GAGAL: $e');
      _setArError('Video AR gagal disiapkan: $e');
    }
    if (_disposed) return;
    // Samakan dengan state terkini (mis. marker terdeteksi lebih dulu).
    _onControllerChanged();
    // Diagnostik otomatis: tanyakan status native 2x agar hasilnya
    // kelihatan di console Flutter tanpa perlu adb logcat.
    for (final delay in const [Duration(seconds: 4), Duration(seconds: 10)]) {
      Future.delayed(delay, () async {
        if (_disposed || !mounted) return;
        if (!widget.config.hasModelVideo) return;
        final objects = _objectManager;
        if (objects == null) return;
        final status = await objects.isMarkerVideoReady();
        if (_disposed || !mounted) return;
        debugPrint(
          '[ASTORYA] markerVideoReady (+${delay.inSeconds}s): $status',
        );
      });
    }
  }

  static bool _isFilePath(String path) {
    final p = path.trim();
    return p.startsWith('file://') ||
        p.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(p);
  }

  // ============================================================== VISUAL ====

  Future<void> _syncVisualToMarker(vm.Matrix4 markerTransform) async {
    // Mode "video model": tanpa node - video dirender native sebagai quad GL.
    if (widget.config.hasModelVideo) return;
    final kind = widget.config.visualKind;
    if (kind == ArVisualKind.none) return;

    final objects = _objectManager;
    if (objects == null) return;

    final transform = _buildNodeTransform(markerTransform);
    final existing = _visualNode;
    if (existing != null) {
      // Update transform -> listener bawaan ARObjectManager meneruskannya
      // ke native, jadi model ikut berpindah mengikuti marker.
      existing.transform = transform;
      return;
    }

    // Saat addNode masih berjalan, event tracking berikutnya (interval 100 ms)
    // jangan menambah node kedua.
    if (_nodeAddInFlight) return;

    final node = _buildNode(kind, transform);
    if (node == null) return;

    _nodeAddInFlight = true;
    try {
      final added = await objects.addNode(node);
      if (_disposed) return;
      if (added == true) {
        _visualNode = node;
      } else {
        _setArError('Gagal menambahkan objek AR ke scene.');
      }
    } finally {
      _nodeAddInFlight = false;
    }
  }

  /// Gabungkan pose marker dari native dengan skala / angkat / rotasi model.
  ///
  /// Urutan pemanggilan **penting**: `translate -> scale -> rotate` membentuk
  /// matriks `M * T * S * R`, sehingga rotasi & skala diterapkan di ruang
  /// lokal model, sementara [ArStoryConfig.modelLift] tetap dalam satuan
  /// **meter** ruang marker (tidak ikut ter-skala).
  vm.Matrix4 _buildNodeTransform(vm.Matrix4 markerTransform) {
    final config = widget.config;
    // Salin eksplisit: Matrix4.fromFloat64List() justru meng-alias storage
    // aslinya, sehingga transform marker bisa ikut ter-modifikasi.
    final transform = vm.Matrix4.copy(markerTransform);

    if (config.modelLift != 0) {
      transform.translateByVector3(vm.Vector3(0, 0, config.modelLift));
    }
    if (config.modelScale != 1) {
      final s = config.modelScale;
      transform.scaleByVector3(vm.Vector3(s, s, s));
    }
    if (config.modelRotationYDegrees != 0) {
      transform.rotateY(config.modelRotationYDegrees * math.pi / 180);
    }
    return transform;
  }

  ARNode? _buildNode(ArVisualKind kind, vm.Matrix4 transform) {
    final config = widget.config;
    switch (kind) {
      case ArVisualKind.localGlb:
        return ARNode(
          type: NodeType.localGLB,
          uri: config.modelPath!,
          transformation: transform,
        );
      case ArVisualKind.localGltf:
        return ARNode(
          type: NodeType.localGLTF2,
          uri: config.modelPath!,
          transformation: transform,
        );
      case ArVisualKind.networkGlb:
        return ARNode(
          type: NodeType.webGLB,
          uri: config.modelPath!,
          transformation: transform,
        );
      case ArVisualKind.imageOverlay:
        // Plugin ini TIDAK punya node gambar (NodeType.localPNG tidak ada),
        // jadi overlay gambar dirender sebagai widget Flutter Image di
        // build() - bukan node AR. Return null agar tidak ada node yang
        // ditambahkan ke scene.
        return null;
      case ArVisualKind.none:
        return null;
    }
  }

  void _setArError(String message) {
    if (_disposed || !mounted) return;
    setState(() => _arError = message);
  }

  /// Buka video layar penuh: native menggambar quad menutupi layar dengan
  /// player yang SAMA, jadi Voiceover/BGM terus berbunyi. Overlay Flutter
  /// transparan hanya berisi tombol tutup.
  void _openFullscreen() {
    final objects = _objectManager;
    if (_disposed || !mounted) return;
    if (!widget.config.hasModelVideo || objects == null) return;
    unawaited(objects.setMarkerVideoFullscreen(true));
    Navigator.of(context)
        .push<void>(
          PageRouteBuilder<void>(
            opaque: false,
            barrierDismissible: false,
            pageBuilder: (_, __, ___) => ArFullscreenVideo(
              markerDetected: _controller.markerDetected,
            ),
          ),
        )
        .then((_) async {
      // Kembalikan ke mode marker (abaikan bila view sudah dilepas).
      try {
        await objects.setMarkerVideoFullscreen(false);
      } catch (_) {}
    });
  }

  // ================================================================ BUILD ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),
          // Video overlay menempel pada marker (hanya bila config.videoPath terisi).
          // Sudut marker dari native dipakai untuk warp perspektif; bila native
          // tidak mengirim (mis. iOS), video jatuh ke overlay datar.
          if (widget.config.hasVideo)
            ArVideoOverlay(
              controller: _controller,
              config: widget.config,
              markerCorners: _markerCorners,
            ),
          // Overlay gambar 2D (bila config.overlayImagePath terisi). Dirender
          // sebagai widget Flutter Image karena plugin tak punya node gambar.
          if (widget.config.visualKind == ArVisualKind.imageOverlay)
            _ImageOverlay(
              controller: _controller,
              imagePath: widget.config.overlayImagePath!,
            ),
          AstoryaArHud(
            controller: _controller,
            isReady: _sessionInitialized && _trackingConfigured,
            arError: _arError,
            onClose: widget.onClose ?? () => Navigator.maybePop(context),
            onFullscreen:
                widget.config.hasModelVideo ? _openFullscreen : null,
          ),
        ],
      ),
    );
  }

  // ============================================================== DISPOSE ===

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;

      // 1. Hentikan audio dulu agar suara tidak nyangkut.
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _markerCorners.dispose();

      // 2. Lepas node model dari scene.
      final node = _visualNode;
      final objects = _objectManager;
      _visualNode = null;
      _objectManager = null;
      if (node != null && objects != null) {
        try {
          objects.removeNode(node);
        } catch (_) {
          // Native view sudah lepas - abaikan.
        }
      }

      // 3. Putuskan sesi AR (kamera & platform handler).
      final session = _sessionManager;
      _sessionManager = null;
      if (session != null) {
        unawaited(session.dispose());
      }
    }
    super.dispose();
  }
}

/// Overlay gambar 2D mengambang di atas marker.
///
/// Plugin AR tidak punya node gambar (NodeType.localPNG tidak ada), jadi
/// gambar dirender sebagai widget [Image] Flutter biasa di atas [ARView],
/// muncul setelah marker terdeteksi - persis seperti [ArVideoOverlay].
class _ImageOverlay extends StatelessWidget {
  const _ImageOverlay({
    required this.controller,
    required this.imagePath,
  });

  final AstoryaArController controller;

  /// Path asset gambar overlay.
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Tunggu marker terdeteksi baru tampilkan.
        if (!controller.markerDetected) return const SizedBox.shrink();

        return IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  ArStoryConfig.normalizeAssetKey(imagePath),
                  // Fit biar tidak overflow, jaga rasio asli gambar.
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
