import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ar/astorya_ar.dart';
import 'web_ar_config.dart';

/// Halaman WebAR ASTORYA (mode berdampingan dengan mode native).
///
/// Kamera + tracking marker dirender oleh MindAR di dalam WebView,
/// sedangkan VO/BGM/subtitle/HUD tetap memakai pipa Flutter yang sama
/// ([AstoryaArController] + [AstoryaArHud]) agar perilaku cerita konsisten
/// di kedua mode.
///
/// Alur: halaman web mengirim `targetFound` lewat JS bridge ->
/// [_controller.onMarkerDetected()] -> audio mulai (persis seperti event
/// `onImageDetected` di mode native). Video dikendalikan halaman web
/// (main saat pertama ditemukan, loop terus) agar tidak drift dengan audio.
///
/// Pakai dari mana pun, sejajar dengan [AstoryaArView]:
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => WebArView(config: config)),
/// );
/// ```
class WebArView extends StatefulWidget {
  const WebArView({
    super.key,
    required this.config,
    this.onClose,
  });

  /// Konfigurasi target MindAR + cerita (audio/subtitle) yang dipakai ulang.
  final WebArConfig config;

  /// Dipanggil saat user menutup layar WebAR.
  /// Default: `Navigator.maybePop(context)`.
  final VoidCallback? onClose;

  @override
  State<WebArView> createState() => _WebArViewState();
}

class _WebArViewState extends State<WebArView> {
  late final AstoryaArController _controller;

  InAppLocalhostServer? _server;

  bool _pageLoaded = false;
  String? _arError;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    final validationError = widget.config.validate();
    if (validationError != null) {
      _arError = 'Konfigurasi WebAR tidak valid: $validationError';
    }

    _controller = AstoryaArController(widget.config.story);
    if (validationError == null) {
      unawaited(_controller.init());
      unawaited(_boot());
    }
  }

  /// 1. Minta izin kamera OS. 2. Siapkan penyajian asset lokal:
  /// - Android: WebViewAssetLoader (https, secure context, tanpa server TCP).
  /// - Lainnya: InAppLocalhostServer `http://localhost` (secure context).
  Future<void> _boot() async {
    final status = await Permission.camera.request();
    if (_disposed) return;
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _arError = status.isPermanentlyDenied
            ? 'Izin kamera ditolak permanen. Aktifkan di Pengaturan > Aplikasi > ASTORYA > Izin.'
            : 'Izin kamera ditolak. WebAR membutuhkan kamera untuk tracking marker.';
      });
      return;
    }
    if (_useAssetLoader) return; // Android: tanpa server lokal.

    try {
      final server = InAppLocalhostServer(documentRoot: 'assets');
      await server.start();
      if (_disposed) {
        await server.close();
        return;
      }
      if (!mounted) return;
      setState(() => _server = server);
    } catch (e) {
      if (_disposed || !mounted) return;
      setState(() => _arError = 'Gagal menyalakan server lokal WebAR: $e');
    }
  }

  /// Android memakai WebViewAssetLoader (pola Flutter resmi: handler
  /// `/assets/` + URL `/assets/flutter_assets/...`). Tanpa TCP localhost
  /// sehingga kebal masalah IPv4/IPv6 & cleartext.
  static const String _assetDomain = 'appassets.androidplatform.net';
  bool get _useAssetLoader =>
      defaultTargetPlatform == TargetPlatform.android;

  /// URL halaman + parameter untuk mode ini. Path asset dipetakan relatif
  /// terhadap `/webar/index.html` (lihat `assets/webar/index.html`).
  WebUri _pageUri() {
    final c = widget.config;
    final params = <String, String>{
      'target': _toPageRelative(c.mindTarget),
      'video': _toPageRelative(c.videoPath),
      'model': _toPageRelative(c.modelPath),
      'muted': c.videoMuted ? '1' : '0',
      'rx': c.modelRotationXDegrees.toString(),
    };
    if (_useAssetLoader) {
      return WebUri.uri(
        Uri.https(
          _assetDomain,
          '/assets/flutter_assets/webar/index.html',
          params,
        ),
      );
    }
    return WebUri.uri(
      Uri.http(
        'localhost:8080',
        '/webar/index.html',
        params,
      ),
    );
  }

  /// `assets/webar/x` -> `x`, `assets/videos/y` -> `../videos/y`,
  /// URL http(s) diteruskan apa adanya.
  String _toPageRelative(String path) {
    final raw = path.trim();
    if (ArStoryConfig.isNetworkSource(raw)) return raw;
    var p = ArStoryConfig.normalizeAssetKey(raw);
    if (p.startsWith('assets/')) p = p.substring('assets/'.length);
    if (p.startsWith('webar/')) return p.substring('webar/'.length);
    return '../$p';
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    // Marker ditemukan di halaman web = event yang sama dengan
    // `onImageDetected` mode native: mulai cerita (sekali saja, di-guard
    // di dalam controller).
    controller.addJavaScriptHandler(
      handlerName: 'onTargetFound',
      callback: (args) => _controller.onMarkerDetected(),
    );
    // Marker hilang: sengaja tidak menghentikan audio, menyamai perilaku
    // mode native (audio jalan terus, video loop di halaman web).
    controller.addJavaScriptHandler(
      handlerName: 'onTargetLost',
      callback: (args) {},
    );
    controller.addJavaScriptHandler(
      handlerName: 'onWebArError',
      callback: (args) {
        if (_disposed || !mounted) return;
        final msg = args.isNotEmpty ? '${args.first}' : 'Error WebAR';
        setState(() => _arError = 'WebAR: $msg');
      },
    );
    // Video web siap di-decode (canplay): hanya diagnostik, playback tetap
    // dikendalikan halaman (main saat target ditemukan).
    controller.addJavaScriptHandler(
      handlerName: 'onVideoReady',
      callback: (args) {
        if (kDebugMode) debugPrint('[webar] video siap diputar');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if ((_useAssetLoader || server != null) && _arError == null)
            InAppWebView(
              key: const ValueKey('astorya-webar'),
              initialUrlRequest: URLRequest(url: _pageUri()),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                // Video harus bisa autoplay muted tanpa tap user.
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useHybridComposition: true,
                allowsBackForwardNavigationGestures: false,
                // Android: sajikan asset Flutter lewat https agar menjadi
                // secure context (syarat getUserMedia) tanpa server lokal.
                webViewAssetLoader: _useAssetLoader
                    ? WebViewAssetLoader(
                        domain: _assetDomain,
                        pathHandlers: [
                          AssetsPathHandler(path: '/assets/'),
                        ],
                      )
                    : null,
              ),
              onWebViewCreated: _onWebViewCreated,
              onLoadStop: (controller, url) {
                if (_disposed || !mounted) return;
                setState(() => _pageLoaded = true);
              },
              onReceivedError: (controller, request, error) {
                if (_disposed || !mounted) return;
                setState(
                  () => _arError =
                      'Gagal memuat halaman WebAR: ${error.description}',
                );
              },
              // Error HTTP file utama saja (sub-resource diabaikan agar tidak
              // false alarm). Menjawab "file apa yang hilang" langsung.
              onReceivedHttpError: (controller, request, errorResponse) {
                if (_disposed || !mounted) return;
                if (request.isForMainFrame != true) return;
                setState(
                  () => _arError = 'WebAR HTTP '
                      '${errorResponse.statusCode ?? '?'}: ${request.url}',
                );
              },
              onPermissionRequest: (controller, request) async {
                // Izin OS sudah diminta di _boot; teruskan ke WebView.
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onConsoleMessage: (controller, message) {
                // Log console halaman (error MindAR dsb.) hanya di debug.
                if (kDebugMode) {
                  debugPrint('[webar] ${message.message}');
                }
              },
            )
          else if (_arError == null)
            // Server lokal belum siap: tampilkan loading (tanpa WebView).
            const SizedBox.shrink(),
          AstoryaArHud(
            controller: _controller,
            isReady: _pageLoaded && _arError == null,
            arError: _arError,
            onClose: widget.onClose ?? () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    // Server lokal dimatikan async; tidak perlu ditunggu dari dispose().
    unawaited(_server?.close());
    _server = null;
    super.dispose();
  }
}
