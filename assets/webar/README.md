# WebAR ASTORYA (`assets/webar/`)

Mode WebAR (MindAR) berjalan dari folder ini.

## Cara halaman disajikan ke WebView

- **Android**: `WebViewAssetLoader` (lihat `WebArView`) menyajikan asset
  Flutter lewat `https://appassets.androidplatform.net/assets/flutter_assets/`.
  Tanpa server TCP → kebal masalah IPv4/IPv6 localhost & cleartext, dan
  otomatis secure context (syarat kamera). **Offline penuh.**
- **iOS/lainnya**: `InAppLocalhostServer` `http://localhost:8080/`.

## File

| File | Keterangan |
|---|---|
| `index.html` | Halaman MindAR (three.js). Jangan ganti nama (di-load `WebArView`). |
| `targets.mind` | Target image hasil kompilasi gambar marker (sudah ada ✅). |
| `vendor/` | Library JS lokal (three 0.147.0 + MindAR three 1.2.5) → WebAR **offline**, tanpa CDN. Jangan upgrade tanpa menguji. |

## Cara membuat `targets.mind` (sekali per gambar marker)

> ✅ File-mu (`targets.mind` dari `a4_1.png`) sudah ada — bagian ini hanya
> untuk regenerasi bila gambar marker diganti.

1. Siapkan gambar marker (mis. `assets/images/a4_1.png`).
2. Kompilasi dengan **MindAR Image Target Compiler** resmi
   (dokumentasi: `mind-ar-js-doc` → bagian Tools → Image Targets).
   Bisa lewat halaman web compiler (drag & drop PNG) atau CLI-nya.
3. Hasilnya **satu file** berisi satu target (index 0).
4. Simpan sebagai `assets/webar/targets.mind` (nama persis ini, karena
   default `WebArConfig.mindTarget` menunjuk ke sana).
5. Daftarkan? Tidak perlu - `assets/webar/` sudah terdaftar di
   `pubspec.yaml`, file baru otomatis ikut ter-bundle saat build berikutnya.

## Syarat `meshplane.glb` (PENTING)

File di `assets/models/meshplane.glb` sudah diperbaiki dari versi asli:

- Node transform = **identitas** (rotasi `[0,0,0,1]`, translasi nol). Versi
  asli punya rotasi 120° + lift 0.49 (sisa Blender belum Apply) yang bikin
  plane berdiri/melayang di kedua engine. Backup asli:
  `backups/meshplane.orig.glb` (di luar folder asset agar tidak ikut APK).
- Mesh: plane 1.414 × 1.0 di bidang XZ + UV penuh → pas rasio A4 landscape.
- Halaman web otomatis: `rotation.x = rx` (default -90, via
  `WebArConfig.modelRotationXDegrees`), material DoubleSide, dan
  auto-fit lebar = 1 unit anchor.

## Aturan

- Satu `.mind` = satu gambar marker (targetIndex 0). Untuk multi-marker,
  kompilasi beberapa gambar jadi satu `.mind` lalu tambah anchor
  (`addAnchor(i)`) di `index.html`.
- `meshplane.glb` tinggal di **`assets/models/`** (sumber tunggal, dipakai
  mode native + WebAR). **Jangan** duplikat ke `assets/webar/`.
  File ini **wajib punya UV** agar tekstur video menempel benar.
  Geometri/ukuran plane mengikuti file GLB ini (bukan config Flutter).
  Material asli GLB diganti `MeshBasicMaterial` agar kecerahan video
  konsisten (tidak dipengaruhi lighting scene).
- Library JS **lokal** di `vendor/` (three.js 0.147.0 + MindAR 1.2.5) →
  mode WebAR jalan **offline**, tanpa CDN/internet. Jangan upgrade tanpa
  menguji (API berubah antar major).
- Video sebaiknya dari asset lokal (`../videos/...`) agar lolos CORS
  tekstur WebGL. Video URL jaringan butuh header CORS yang benar.
