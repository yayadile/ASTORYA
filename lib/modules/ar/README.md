# Modul AR ASTORYA (`AstoryaArView`)

Modul AR **native Flutter** (ARKit / ARCore) berbasis image tracking marker,
lengkap dengan dual audio (Voiceover + BGM) dan subtitle ID/EN yang di-sync ke
timestamp Voiceover. Dirancang **terisolasi dari UI utama** sehingga bisa
di-push dari halaman mana pun dan gampang dipindah antar project.

---

## 1. Struktur folder

```
ASTORYA/
├── pubspec.yaml
├── assets/
│   ├── markers/                  # gambar marker (lebar cetak ~20 cm)
│   ├── models/                   # model 3D .glb / .gltf
│   ├── images/                   # overlay gambar 2D .png (alternatif model)
│   └── audio/
│       ├── vo/                   # voiceover .mp3
│       └── bgm/                  # bgm .mp3
├── lib/
│   ├── main.dart
│   ├── features/
│   │   └── story/
│   │       └── story_list_page.dart      # contoh pemanggilan
│   └── modules/
│       └── ar/                            # ← SELURUH MODUL, bebas dipindah
│           ├── astorya_ar.dart            # barrel export (import 1 file)
│           ├── astorya_ar_view.dart       # widget utama (entry point)
│           ├── README.md
│           ├── controllers/
│           │   └── astorya_ar_controller.dart   # audio + sinkron subtitle
│           ├── models/
│           │   ├── ar_story_config.dart         # parameter marker/vo/bgm/subtitle
│           │   └── subtitle_cue.dart            # model subtitle + enum bahasa
│           └── widgets/
│               ├── astorya_ar_hud.dart          # komposer seluruh overlay
│               ├── ar_control_bar.dart          # top bar: play/vo/bgm/bahasa
│               ├── ar_volume_popup.dart         # popup slider volume
│               ├── ar_subtitle_overlay.dart     # subtitle bawah layar
│               ├── ar_replay_overlay.dart       # tombol "Putar Ulang Cerita"
│               └── ar_marker_hint.dart          # hint arahkan kamera
```

**Prinsipnya:** `lib/modules/ar/` adalah unit yang utuh. Untuk memindahkannya
ke project lain, cukup salin folder itu + `assets/` yang dipakai + dependency di
`pubspec.yaml` (lihat checklist di bagian 5).

---

## 2. Cara pakai dari halaman lain

```dart
import 'package:astorya/modules/ar/astorya_ar.dart';   // barrel - 1 import

final config = ArStoryConfig(
  // Wajib -------------------------------------------------------------
  markerImagePath: 'assets/markers/marker_borobudur.jpg',
  voiceoverUrl:    'assets/audio/vo/borobudur.mp3',     // boleh juga URL https
  bgmUrl:          'assets/audio/bgm/ambient.mp3',      // boleh juga URL https

  // Visual 3D / overlay (opsional) -------------------------------------
  modelPath: 'assets/models/candi_borobudur.glb',       // .glb / .gltf / URL .glb
  // overlayImagePath: 'assets/images/candi.png',       // alternatif: gambar 2D
  modelScale: 1.0,
  modelLift:  0.02,        // 2 cm di atas marker

  // Subtitle ------------------------------------------------------------
  subtitles: const [
    SubtitleCue(start: 0.0, end: 4.5,
        id: 'Selamat datang di Borobudur.',
        en: 'Welcome to Borobudur.'),
    SubtitleCue(start: 4.5, end: 9.0,
        id: 'Candi Buddha terbesar di dunia.',
        en: 'The largest Buddhist temple in the world.'),
  ],

  // Perilaku (opsional) -------------------------------------------------
  initialVoiceoverVolume: 1.0,   // 100 %
  initialBgmVolume:       0.3,   // 30 %
  loopBgm:                true,
  autoStartOnMarkerDetected: true,
);

Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => AstoryaArView(config: config)),
);
```

Karena semua parameter dikirim lewat `ArStoryConfig`, halaman pemanggil tidak
perlu tahu apa pun tentang AR. Update UI/UX aplikasi cukup menyentuh widget di
dalam `lib/modules/ar/widgets/`, tanpa mengubah cara pemanggilan.

---

## 3. Perilaku playback (sesuai spesifikasi)

| Kejadian | Perilaku |
| --- | --- |
| Marker terdeteksi (pertama kali) | Model/overlay ditanam di atas marker, VO + BGM mulai bersamaan |
| Marker terus terdeteksi | Posisi model ikut mengikuti marker (`continuousImageTracking`) |
| BGM | Loop, volume awal 30 % |
| Voiceover | Tidak loop, volume awal 100 % |
| Posisi VO berubah | Subtitle bawah layar ganti cue secara real-time |
| Ganti bahasa ID/EN | Teks langsung berubah tanpa restart audio |
| Voiceover `completed` | Semua audio di-pause, subtitle disembunyikan, tombol **Putar Ulang Cerita** muncul di tengah |
| Tap **Putar Ulang** | `seek(0)` di VO & BGM, lalu play dari detik 0 |
| Halaman ditutup | Node dilepas, sesi AR di-dispose, kedua player di-dispose (tidak ada memory leak) |

---

## 4. Catatan penting & keterbatasan

### 4.1 Package AR: `ar_flutter_plugin_plus`, bukan `ar_flutter_plugin`

`ar_flutter_plugin` versi asli (**0.7.3, terbit Nov 2022**) **tidak punya fitur
image tracking** - isinya hanya plane detection, hit test, anchor, dan cloud
anchor. Marker/pemindaian gambar tidak mungkin dibuat dengannya.

`ar_flutter_plugin_plus` adalah **fork dari plugin yang sama** dengan API
identik (`ARView`, `ARSessionManager`, `ARObjectManager`, `ARAnchorManager`)
dan **penambahan Image Tracking**. Karena itu seluruh kode modul ini tetap
memakai pola API `ar_flutter_plugin` - bila suatu hari plugin aslinya sudah
mendukung marker, tinggal ganti dependency + import di file
`astorya_ar_view.dart`.

### 4.2 Lebar marker hardcode 20 cm

Di native (Android `AugmentedImageDatabase.addImage(..., 0.2f)` dan iOS
`ARReferenceImage(..., physicalWidth: 0.2)`) lebar fisik marker di-hardcode
**0.2 meter**. Artinya:

- Cetak/tampilkan marker dengan **lebar ±20 cm** agar skala model 3D akurat.
- Marker jauh lebih kecil/besar dari 20 cm tetap terdeteksi, tapi skala model
  akan meleset.
- Bila butuh lebar lain, nilai itu harus di-patch di source native plugin.

### 4.3 Animasi model 3D **belum** didukung

Plugin ini **tidak memiliki kode animasi sama sekali** (dicek di seluruh source
native Android/iOS & Dart - nol kemunculan `animation`/`animator`). Jadi:

- File `.glb` yang berisi animasi akan **dirender statis** di pose awalnya.
- Untuk "gerakan", gunakan strategi lain sementara: ganti-ganti `modelPath`
  antar cue, atau animasikan transform dari sisi Flutter (mis. update
  `ARNode.transform` berkala untuk efek putar/melayang).

### 4.4 Format model

- **`.glb` disarankan** - satu file, tanpa sidecar `.bin`/tekstur.
- `.gltf` harus disertai file `.bin` + tekstur dalam folder yang sama, dan seluruh
  folder harus terdaftar di `pubspec.yaml`.
- Model dari internet harus `.glb` (plugin hanya punya tipe `webGLB`).

---

## 5. Checklist pindah ke project lain

1. Salin seluruh folder `lib/modules/ar/` ke project tujuan.
2. Salin folder `assets/` yang dipakai (minimal `markers/`, `models/` atau
   `images/`, `audio/vo/`, `audio/bgm/`).
3. Tambahkan ke `pubspec.yaml` project tujuan:

   ```yaml
   dependencies:
     ar_flutter_plugin_plus: ^1.1.3
     just_audio: ^0.10.6
     vector_math: ^2.2.0

   flutter:
     assets:
       - assets/markers/
       - assets/models/
       - assets/images/
       - assets/audio/vo/
       - assets/audio/bgm/
   ```

4. Kerjakan setup native di bagian 6.
5. Panggil `AstoryaArView(config: ...)` via `Navigator.push`.

---

## 6. Setup native

### Android

1. `android/app/build.gradle`:

   ```gradle
   defaultConfig {
       minSdk = 24          // syarat ARCore (wajib)
   }
   ```

2. `android/app/src/main/AndroidManifest.xml` - tambahkan bila memakai
   audio/model dari URL:

   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```

   Izin kamera + `com.google.ar.core` sudah dideklarasikan oleh plugin.

3. **Release wajib `debuggable false`** (bug ARCore membuat tracking mulai
   lambat/kasar bila `debuggable true` - lihat issue
   [google-ar/arcore-android-sdk#1750](https://github.com/google-ar/arcore-android-sdk/issues/1750)).

   ```gradle
   buildTypes {
       release {
           minifyEnabled false
           debuggable false      // penting untuk tracking marker yang halus
           ...
       }
   }
   ```

4. Pastikan **Google Play Services for AR (ARCore)** terpasang di device, dan
   device ada di [daftar ARCore supported](https://developers.google.com/ar/devices).

### iOS

1. `ios/Runner/Info.plist`:

   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Kamera diperlukan untuk pengalaman AR ASTORYA.</string>
   ```

2. `ios/Podfile` - set deployment target 15.0, lalu tambahkan di blok
   `post_install`:

   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
       target.build_configurations.each do |config|
         config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
         config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
           '$(inherited)',
           ## dart: PermissionGroup.camera
           'PERMISSION_CAMERA=1',
         ]
       end
     end
   end
   ```

   > Blok `PERMISSION_CAMERA=1` ini penting: tanpanya kamera bisa tetap hitam
   > walaupun izin sudah diberikan.

3. Bila memakai audio/model dari URL `http://` (bukan `https`), tambahkan
   exception App Transport Security - disarankan pakai `https` saja.

### Device AR yang didukung

- **iOS**: iPhone 6s ke atas / iPad (2017) ke atas (ARKit).
- **Android**: device dengan `ARCore supported` + Play Services for AR.

---

## 7. Alur data di dalam modul

```
AstoryaArView  ── onARViewCreated ──► ARSessionManager.onInitialize(
      │                                   trackingImagePaths: [marker])
      │                                   ARObjectManager.onInitialize()
      │
      ├── onImageDetected(name, transform, w, h)
      │       ├── _syncVisualToMarker()  → ARNode transform = pose marker
      │       └── controller.onMarkerDetected() → play() sekali saja
      │
      └── AstoryaArHud (AnimatedBuilder di controller)
              ├── ArControlBar     → toggle / volume VO / volume BGM / ID-EN
              ├── ArVolumePopup    → slider 0-100 %
              ├── ArSubtitleOverlay← controller.subtitleText (cue aktif)
              ├── ArMarkerHint     → selama marker belum terdeteksi
              └── ArReplayOverlay  → saat state == completed

AstoryaArController (ChangeNotifier)
      ├── AudioPlayer #1 "voiceover"  → positionStream → sinkron cue
      │                              └→ playerStateStream.completed → replay UI
      └── AudioPlayer #2 "bgm"        → LoopMode.all, volume 0.3
```

`AstoryaArHud` hanya mendengarkan controller, sehingga perubahan volume /
subtitle / play-pause **tidak pernah me-rebuild `ARView`** di belakangnya.
