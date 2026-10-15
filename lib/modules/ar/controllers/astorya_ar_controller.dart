import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/ar_story_config.dart';
import '../models/subtitle_cue.dart';

/// Status playback cerita AR.
enum ArStoryState {
  /// Media belum selesai dimuat / sedang error.
  idle,

  /// Media siap diputar, belum mulai.
  ready,

  /// Sedang diputar.
  playing,

  /// Dijeda manual.
  paused,

  /// Voiceover selesai -> tombol "Putar Ulang Cerita" ditampilkan.
  completed,
}

/// Orkestrator audio + sinkronisasi subtitle untuk [AstoryaArView].
///
/// Dipisahkan dari widget agar logika playback bisa diuji dan diganti tanpa
/// menyentuh kode UI AR. Widget cukup memanggil method-method di bawah ini.
class AstoryaArController extends ChangeNotifier {
  AstoryaArController(this.config)
      : _voiceoverVolume = config.initialVoiceoverVolume.clamp(0.0, 1.0).toDouble(),
        _bgmVolume = config.initialBgmVolume.clamp(0.0, 1.0).toDouble();

  /// Konfigurasi cerita (marker, audio, subtitle, visual).
  final ArStoryConfig config;

  /// Track 1: Voiceover. Sumber utama posisi & event 'completed'.
  final AudioPlayer _voiceover = AudioPlayer();

  /// Track 2: BGM. Volume awal 30%, looping.
  final AudioPlayer _bgm = AudioPlayer();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  ArStoryState _state = ArStoryState.idle;
  bool _markerDetected = false;
  bool _initStarted = false;
  bool _disposed = false;
  SubtitleLanguage _language = SubtitleLanguage.id;
  SubtitleCue? _activeCue;
  String? _error;
  double _voiceoverVolume;
  double _bgmVolume;

  /// Posisi playback mentah. Dipisah dari [notifyListeners] agar nanti bisa
  /// dipakai progress bar tanpa me-rebuild seluruh HUD.
  final ValueNotifier<Duration> position =
      ValueNotifier<Duration>(Duration.zero);

  // ------------------------------------------------------------------ state -

  ArStoryState get state => _state;
  bool get isPlaying => _state == ArStoryState.playing;
  bool get canReplay => _state == ArStoryState.completed;
  bool get markerDetected => _markerDetected;
  SubtitleLanguage get language => _language;
  SubtitleCue? get activeCue => _activeCue;
  String? get error => _error;
  double get voiceoverVolume => _voiceoverVolume;
  double get bgmVolume => _bgmVolume;
  bool get disposed => _disposed;

  /// Teks subtitle yang sedang tampil sesuai bahasa terpilih, atau `null`
  /// bila tidak ada cue aktif / marker belum terdeteksi / cerita sudah selesai.
  String? get subtitleText {
    final cue = _activeCue;
    if (!_markerDetected ||
        cue == null ||
        _state == ArStoryState.completed) {
      return null;
    }
    final text = cue.text(_language);
    return text.isEmpty ? null : text;
  }

  // ------------------------------------------------------------------ init --

  /// Muat Voiceover + BGM. Aman dipanggil berulang (hanya jalan sekali).
  Future<void> init() async {
    if (_initStarted || _disposed) return;
    _initStarted = true;

    try {
      // Muat hanya audio yang diisi. VO & BGM kini opsional, jadi cerita
      // bisa jalan tanpa keduanya (mis. test murni video/marker).
      final loads = <Future<void>>[];
      if (config.hasVoiceover) {
        loads.add(_load(_voiceover, config.voiceoverUrl!));
      }
      if (config.hasBgm) {
        loads.add(_load(_bgm, config.bgmUrl!));
      }
      if (loads.isNotEmpty) {
        await Future.wait<void>(loads);
      }
      if (_disposed) return;

      if (config.hasVoiceover) {
        await _voiceover.setVolume(_voiceoverVolume);
        await _voiceover.setLoopMode(LoopMode.off);
        _positionSub = _voiceover.positionStream.listen(_onPosition);
        _playerStateSub = _voiceover.playerStateStream.listen(_onPlayerState);
      }
      if (config.hasBgm) {
        await _bgm.setVolume(_bgmVolume);
        await _bgm.setLoopMode(config.loopBgm ? LoopMode.all : LoopMode.off);
      }

      _setState(ArStoryState.ready);

      // Marker bisa terdeteksi lebih dulu daripada audio selesai dimuat.
      // Bila begitu, mulai cerita begitu media siap.
      if (!_disposed &&
          _markerDetected &&
          config.autoStartOnMarkerDetected) {
        unawaited(play());
      }
    } catch (e) {
      _error = 'Gagal memuat audio: $e';
      // Audio gagal tidak boleh membunuh video: bila ada video, cerita
      // tetap ready agar video bisa jalan (mode suara jadi hening).
      // Tanpa video pun, biarkan ready bila salah satu track opsional?
      // Tidak — tanpa media sama sekali tetap idle agar HUD menampilkan error.
      if (config.hasVideo) {
        _setState(ArStoryState.ready);
      } else {
        _setState(ArStoryState.idle);
      }
      // _setState bisa no-op bila state sudah sama, jadi notify eksplisit
      // agar HUD pasti menampilkan banner error.
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _load(AudioPlayer player, String source) async {
    final raw = source.trim();
    if (ArStoryConfig.isNetworkSource(raw)) {
      await player.setUrl(raw);
    } else {
      await player.setAsset(ArStoryConfig.normalizeAssetKey(raw));
    }
  }

  // --------------------------------------------------------- event marker --

  /// Dipanggil [AstoryaArView] setiap kali native mengirim `onImageDetected`.
  ///
  /// Karena tracking bisa terus-menerus mengirim event, aksi "mulai cerita"
  /// hanya dipicu **sekali** pada deteksi pertama.
  ///
  /// Return `true` bila event inilah yang memulai pemutaran.
  bool onMarkerDetected() {
    if (_disposed) return false;

    var started = false;
    if (!_markerDetected) {
      _markerDetected = true;
      notifyListeners();
    }

    if (config.autoStartOnMarkerDetected &&
        _state == ArStoryState.ready &&
        _error == null) {
      unawaited(play());
      started = true;
    }
    return started;
  }

  // -------------------------------------------------------------- playback --

  /// Mulai / lanjutkan cerita. VO + BGM dijalankan **bersamaan** agar
  /// terdengar bareng; satu track yang gagal tidak boleh menggagalkan
  /// track lain / video (video ikut state `playing`, bukan sukses audio).
  Future<void> play() async {
    if (_disposed) return;
    if (_state == ArStoryState.completed) {
      await replay();
      return;
    }
    if (_state == ArStoryState.idle) return; // media belum siap

    // Set playing DULU agar overlay video langsung jalan tanpa nunggu
    // ExoPlayer selesai start (await play() bisa lambat/gagal di satu track).
    _setState(ArStoryState.playing);

    final starts = <Future<void>>[];
    if (config.hasBgm) {
      starts.add(_bgm.play().catchError((Object e) {
        _error = 'Gagal memutar BGM: $e';
        return;
      }));
    }
    if (config.hasVoiceover) {
      starts.add(_voiceover.play().catchError((Object e) {
        _error = 'Gagal memutar voiceover: $e';
        return;
      }));
    }
    if (starts.isNotEmpty) {
      // Jalan bareng, tidak berurutan. Tidak di-await berurutan agar
      // VO tidak nunggu BGM selesai start.
      unawaited(Future.wait(starts).then((_) {
        if (!_disposed) notifyListeners();
      }));
    }
  }

  /// Jeda semua playback (Voiceover + BGM).
  Future<void> pause() async {
    if (_disposed) return;
    if (config.hasVoiceover) await _voiceover.pause();
    if (config.hasBgm) await _bgm.pause();
    if (_state != ArStoryState.completed) _setState(ArStoryState.paused);
  }

  /// Tombol play/pause manual pada control bar.
  Future<void> toggle() async {
    if (_state == ArStoryState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Main ulang cerita dari detik 0.
  Future<void> replay() async {
    if (_disposed) return;

    if (config.hasVoiceover) await _voiceover.seek(Duration.zero);
    if (config.hasBgm) await _bgm.seek(Duration.zero);
    if (_disposed) return;

    _activeCue = null;
    position.value = Duration.zero;
    _setState(ArStoryState.ready); // reset dulu agar play() tidak rekursi
    await play();
  }

  // ------------------------------------------------------- sinkron subtitle --

  void _onPosition(Duration p) {
    if (_disposed) return;
    position.value = p;

    // Saat selesai, subtitle wajib disembunyikan (bahkan setelah seek(0)).
    if (_state == ArStoryState.completed) {
      if (_activeCue != null) {
        _activeCue = null;
        notifyListeners();
      }
      return;
    }

    final next = _cueAt(p);
    if (!identical(next, _activeCue)) {
      _activeCue = next;
      notifyListeners();
    }
  }

  SubtitleCue? _cueAt(Duration p) {
    if (config.subtitles.isEmpty) return null;
    final seconds = p.inMilliseconds / 1000.0;
    for (final cue in config.subtitles) {
      if (cue.contains(seconds)) return cue;
    }
    return null;
  }

  void _onPlayerState(PlayerState playerState) {
    if (_disposed) return;
    if (playerState.processingState == ProcessingState.completed) {
      _onStoryCompleted();
    }
  }

  /// Perilaku sesuai spesifikasi saat Voiceover selesai:
  /// pause semua -> sembunyikan subtitle -> tampilkan tombol replay.
  void _onStoryCompleted() {
    _voiceover.pause();
    _bgm.pause();
    _activeCue = null;
    _setState(ArStoryState.completed);
  }

  // --------------------------------------------------------------- kontrol --

  Future<void> setVoiceoverVolume(double value) async {
    _voiceoverVolume = value.clamp(0.0, 1.0).toDouble();
    await _voiceover.setVolume(_voiceoverVolume);
    if (!_disposed) notifyListeners();
  }

  Future<void> setBgmVolume(double value) async {
    _bgmVolume = value.clamp(0.0, 1.0).toDouble();
    await _bgm.setVolume(_bgmVolume);
    if (!_disposed) notifyListeners();
  }

  /// Ganti bahasa subtitle secara dynamic / real-time.
  void setLanguage(SubtitleLanguage language) {
    if (_disposed || _language == language) return;
    _language = language;
    notifyListeners();
  }

  void _setState(ArStoryState next) {
    if (_disposed || _state == next) return;
    _state = next;
    notifyListeners();
  }

  // ---------------------------------------------------------------- dispose --

  /// Lepaskan player & stream agar tidak memory leak.
  /// Sengaja dibuat sinkron supaya bisa dipanggil dari `dispose()` widget.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub = null;
    _playerStateSub = null;

    // AudioPlayer.dispose() berjalan async di native; cukup dilepas tanpa
    // await karena subscription di atas sudah dibatalkan lebih dulu.
    unawaited(_voiceover.dispose());
    unawaited(_bgm.dispose());

    position.dispose();
    super.dispose();
  }
}
