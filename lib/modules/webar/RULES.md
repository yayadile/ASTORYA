# RULES - Native AR vs WebAR

Kedua mode **hidup berdampingan**, bukan saling mengganti. Pilih per cerita.

## Perbandingan

| Aspek | Native (`modules/ar`) | WebAR (`modules/webar`) |
|---|---|---|
| Engine | ARCore (Android) / ARKit (iOS) via `ar_flutter_plugin_plus` (fork lokal) | MindAR image tracking di WebView (`flutter_inappwebview`) + three.js |
| Render marker | Quad GL video per-frame (`modelVideoPath`) / widget warp (`videoPath`) / node 3D Filament | GLB `meshplane.glb` bertekstur video, di-anchor langsung ke target (warp tracking beneran: okulsi + perspektif asli) |
| Model 3D (`.glb`) | ✅ node Filament | ❌ tidak didukung |
| Video di atas marker | ✅ overlay warp (butuh sudut per-frame dari native) | ✅ plane video (`<a-plane>`) |
| VO / BGM / subtitle / HUD | ✅ `AstoryaArController` + `AstoryaArHud` | ✅ **sama persis** (dipakai ulang, bukan duplikat) |
| Butuh Google Play Services for AR | ✅ ya (Android) | ❌ tidak |
| Butuh internet saat jalan | ❌ tidak (semua lokal) | ❌ tidak (JS di-vendor lokal di `assets/webar/vendor/`) |
| File target | Gambar mentah (`.png`/`.jpg` di `assets/`) | `.mind` hasil kompilasi + `meshplane.glb` ber-UV dari `assets/models/` (lihat `assets/webar/README.md`) |
| iOS | ✅ ARKit native | ⚠️ kamera di WKWebView dalam-app sering bermasalah → fallback buka Safari / pakai native |

## Kapan pakai apa

- **Video menempel kertas + device low-end / tanpa Play Services** → WebAR.
- **Model 3D `.glb` / offline penuh / iOS** → Native.
- **Cerita audio-only (tanpa visual)** → Native (`ArVisualKind.none`).
- **WebAR wajib ada video** (`WebArConfig.validate()` menolak video kosong).

## Ketergantungan versi (catatan build)

- `flutter_inappwebview` dipakai versi **prerelease `6.2.0-beta.3`** (bukan
  stable `6.1.5`), karena stable gagal build di Android Gradle baru
  (`getDefaultProguardFile('proguard-android.txt')` sudah dihapus AGP).
  Jangan downgrade ke stable tanpa memastikan build release lolos.

## Kontrak event marker (SAMA di kedua mode)

| Native | WebAR | Efek |
|---|---|---|
| `onImageDetected` | JS `onTargetFound` → `controller.onMarkerDetected()` | Mulai cerita sekali (VO+BGM+subtitle+video) |
| marker hilang | JS `onTargetLost` (no-op) | Audio **jalan terus** di kedua mode |

## Batasan WebAR yang disengaja (bukan bug)

1. Video loop terus setelah pertama ditemukan; replay audio (tombol replay)
   tidak me-seek ulang video web. Selisih drift kecil dapat diterima demo.
2. `videoWidthFraction` / `videoCenterOffset` config native **diabaikan** di
   WebAR (geometri plane mengikuti `meshplane.glb`, bukan config Flutter).
3. Satu `.mind` default berisi satu target (index 0). Multi-marker butuh edit
   `index.html` + kompilasi ulang.
4. Jangan upgrade versi vendor three.js/MindAR di `assets/webar/vendor/`
   tanpa menguji - API image-target berubah antar major.
5. Geometri plane video = geometri `meshplane.glb`. Kalau video terlihat
   gepeng/terpotong, yang dibetulkan UV/ukuran GLB-nya, bukan config Flutter.
6. Orientasi plane diatur `WebArConfig.modelRotationXDegrees` (default -90).
   Jangan pakai +90 tanpa DoubleSide (menghadap pergi = tak terlihat).
