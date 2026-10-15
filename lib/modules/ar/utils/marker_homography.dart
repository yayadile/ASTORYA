import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' as vm;

/// Util homografi untuk "menempelkan" video datar pada bidang marker 3D.
///
/// Native AR (fork `ar_flutter_plugin_plus`) mengirim 4 sudut layar marker
/// ternormalisasi [0,1] tiap frame. Dari 4 titik itu kita menghitung homografi
/// (proyeksi perspektif 3x3) yang memetakan persegi panjang video ke bidang
/// marker, sehingga video ikut miring/tertutup perspektif mengikuti marker.
///
/// Pemetaan yang dipakai (berurutan):
///   1. Unit square (u,v) [0,1]^2 -> quad marker di layar  (via DLT)
///   2. Rect video di dalam marker -> 4 titik layar        (interpilasi
///      perspektif pada homografi no. 1, sehingga tepi tetap lurus)
///   3. Rect sumber video (0,0)-(W,H) -> 4 titik layar     (via DLT, dipakai
///      `Transform` Flutter sebagai matriks proyektif)

/// Homografi 3x3 dari 4 pasang titik sumber -> tujuan, memakai DLT
/// (Direct Linear Transform) dengan eliminasi Gauss + partial pivoting.
///
/// [src]/[dst] harus berupa 4 titik berurutan: kiri-atas, kanan-atas,
/// kanan-bawah, kiri-bawah. Return `null` bila sistem degenerate (titik
/// segaris / koordinat tidak valid).
///
/// Hasil disimpan sebagai [vm.Matrix4] dengan konvensi kolom-vektor Flutter:
/// widget 2D (x, y, 0, 1) dipetakan ke (u*w, v*w, 0, w) dengan
/// u = h00*x + h01*y + h02, v = h10*x + h11*y + h12,
/// w = h20*x + h21*y + 1. Suku translasi WAJIB di kolom 3
/// (bukan kolom 2 yang merupakan sumbu Z) agar `Transform` merender benar.
vm.Matrix4? solveHomography(List<Offset> src, List<Offset> dst) {
  if (src.length != 4 || dst.length != 4) return null;

  // Sistem 8x8: h22 = 1 (normalisasi). Untuk tiap pasang titik:
  //   x*h00 + y*h01 + h02 - u*(x*h20 + y*h21) = u
  //   x*h10 + y*h11 + h12 - v*(x*h20 + y*h21) = v
  final a = List.generate(8, (_) => List<double>.filled(8, 0));
  final b = List<double>.filled(8, 0);

  for (var i = 0; i < 4; i++) {
    final x = src[i].dx;
    final y = src[i].dy;
    final u = dst[i].dx;
    final v = dst[i].dy;

    // Baris untuk u.
    a[i * 2][0] = x;
    a[i * 2][1] = y;
    a[i * 2][2] = 1;
    a[i * 2][6] = -u * x;
    a[i * 2][7] = -u * y;
    b[i * 2] = u;

    // Baris untuk v.
    a[i * 2 + 1][3] = x;
    a[i * 2 + 1][4] = y;
    a[i * 2 + 1][5] = 1;
    a[i * 2 + 1][6] = -v * x;
    a[i * 2 + 1][7] = -v * y;
    b[i * 2 + 1] = v;
  }

  final h = _solveLinearSystem(a, b);
  if (h == null) return null;

  // Matrix4 vector_math bersifat kolom-vektor (m * v), sama seperti konvensi
  // Transform Flutter: widget 2D masuk sebagai (x, y, 0, 1), hasil proyeksi
  // dibagi komponen w (baris ke-4). Translasi (h02, h12) di kolom 3, dan
  // konstanta homogen 1 di (3,3) — BUKAN di kolom 2 (sumbu Z).
  final m = vm.Matrix4.identity()
    ..setEntry(0, 0, h[0])
    ..setEntry(0, 1, h[1])
    ..setEntry(0, 3, h[2])
    ..setEntry(1, 0, h[3])
    ..setEntry(1, 1, h[4])
    ..setEntry(1, 3, h[5])
    ..setEntry(2, 2, 1)
    ..setEntry(3, 0, h[6])
    ..setEntry(3, 1, h[7])
    ..setEntry(3, 3, 1);
  return m;
}

/// Terapkan homografi (dari [solveHomography]) ke satu titik 2D, termasuk
/// pembagian perspektif w. Rumus memakai slot matriks yang sama dengan
/// konvensi `Transform` Flutter: translasi di kolom 3, konstanta di (3,3).
Offset applyHomography(vm.Matrix4 m, Offset p) {
  final w = m.entry(3, 0) * p.dx + m.entry(3, 1) * p.dy + m.entry(3, 3);
  if (w.abs() < 1e-9) return p;
  return Offset(
    (m.entry(0, 0) * p.dx + m.entry(0, 1) * p.dy + m.entry(0, 3)) / w,
    (m.entry(1, 0) * p.dx + m.entry(1, 1) * p.dy + m.entry(1, 3)) / w,
  );
}

/// Titik-titik layar (dalam piksel koordinat tumpukan/Stack) dari rect video
/// yang di-fit di dalam plane marker, memakai urutan TL, TR, BR, BL.
///
/// [markerCorners] = 4 sudut marker ternormalisasi [0,1] (TL, TR, BR, BL).
/// [canvasSize]    = ukuran area AR (piksel logis Stack).
/// [markerAspect]  = rasio lebar/tinggi fisik marker (extentX/extentY).
/// [videoAspect]   = rasio lebar/tinggi video.
///
/// Video di-fit seperti `BoxFit.contain` di dalam marker agar proporsinya
/// tidak gepeng walau aspek video berbeda dari marker. Return `null` bila
/// input tidak valid.
List<Offset>? computeVideoQuad({
  required List<double> markerCorners,
  required Size canvasSize,
  required double markerAspect,
  required double videoAspect,
}) {
  if (markerCorners.length != 8) return null;
  if (canvasSize.isEmpty ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0 ||
      markerAspect <= 0 ||
      videoAspect <= 0) {
    return null;
  }

  final quad = <Offset>[
    for (var i = 0; i < 4; i++)
      Offset(
        markerCorners[i * 2] * canvasSize.width,
        markerCorners[i * 2 + 1] * canvasSize.height,
      ),
  ];

  // Homografi unit square -> quad marker di layar.
  final unitToMarker = solveHomography(const [
    Offset(0, 0), // TL
    Offset(1, 0), // TR
    Offset(1, 1), // BR
    Offset(0, 1), // BL
  ], quad);
  if (unitToMarker == null) return null;

  // Rect video (seperti BoxFit.contain) di ruang UV marker, terpusat.
  double uSpan;
  double vSpan;
  if (videoAspect >= markerAspect) {
    // Lebar penuh, tinggi menyesuaikan.
    uSpan = 1;
    vSpan = markerAspect / videoAspect;
  } else {
    // Tinggi penuh, lebar menyesuaikan.
    vSpan = 1;
    uSpan = videoAspect / markerAspect;
  }
  final u0 = (1 - uSpan) / 2;
  final u1 = u0 + uSpan;
  final v0 = (1 - vSpan) / 2;
  final v1 = v0 + vSpan;

  // Interpilasi perspektif: garis lurus di UV tetap lurus di layar, jadi
  // cukup petakan 4 sudut rect video lewat homografi unit square -> marker.
  final videoQuad = <Offset>[
    applyHomography(unitToMarker, Offset(u0, v0)), // TL
    applyHomography(unitToMarker, Offset(u1, v0)), // TR
    applyHomography(unitToMarker, Offset(u1, v1)), // BR
    applyHomography(unitToMarker, Offset(u0, v1)), // BL
  ];

  for (final p in videoQuad) {
    if (p.dx.isNaN || p.dy.isNaN || p.dx.isInfinite || p.dy.isInfinite) {
      return null;
    }
  }
  return videoQuad;
}

/// Matriks transformasi untuk widget `Transform` Flutter: memetakan rect
/// sumber (0,0)-(srcSize) ke [quad] (urutan TL, TR, BR, BL) di koordinat
/// absolut Stack. Pasangkan dengan `Positioned(left: 0, top: 0)` dan
/// `alignment: Alignment.topLeft` agar koordinat sumber berawal di (0,0).
vm.Matrix4? videoWarpMatrix({
  required Size srcSize,
  required List<Offset> quad,
}) {
  final src = <Offset>[
    Offset.zero,
    Offset(srcSize.width, 0),
    Offset(srcSize.width, srcSize.height),
    Offset(0, srcSize.height),
  ];
  final m = solveHomography(src, quad);
  if (m == null) return null;

  // Tolak hasil liar (mis. sudut marker nyaris sejajar garis pandang) yang
  // bisa membuat video "meledak" memenuhi layar.
  final corners = [
    Offset.zero,
    Offset(srcSize.width, 0),
    Offset(srcSize.width, srcSize.height),
    Offset(0, srcSize.height),
  ];
  final mapped = [for (final p in corners) applyHomography(m, p)];
  final maxX = mapped.map((p) => p.dx).reduce(math.max);
  final maxY = mapped.map((p) => p.dy).reduce(math.max);
  final minX = mapped.map((p) => p.dx).reduce(math.min);
  final minY = mapped.map((p) => p.dy).reduce(math.min);
  if (!maxX.isFinite || !maxY.isFinite) return null;
  // Batas wajar: quad tidak boleh jauh lebih besar dari area marker di layar.
  final limit = math.max(srcSize.width, srcSize.height) * 4;
  if (maxX - minX > limit || maxY - minY > limit) return null;

  return m;
}

/// Eliminasi Gauss dengan partial pivoting. Return `null` bila matriks
/// singular.
List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
  const n = 8;
  for (var col = 0; col < n; col++) {
    // Cari baris pivot terbesar.
    var pivot = col;
    var maxAbs = a[col][col].abs();
    for (var row = col + 1; row < n; row++) {
      final v = a[row][col].abs();
      if (v > maxAbs) {
        maxAbs = v;
        pivot = row;
      }
    }
    if (maxAbs < 1e-12) return null;

    if (pivot != col) {
      final tmpRow = a[col];
      a[col] = a[pivot];
      a[pivot] = tmpRow;
      final tmpB = b[col];
      b[col] = b[pivot];
      b[pivot] = tmpB;
    }

    final inv = 1 / a[col][col];
    for (var row = col + 1; row < n; row++) {
      final factor = a[row][col] * inv;
      if (factor == 0) continue;
      for (var k = col; k < n; k++) {
        a[row][k] -= factor * a[col][k];
      }
      b[row] -= factor * b[col];
    }
  }

  final x = List<double>.filled(n, 0);
  for (var row = n - 1; row >= 0; row--) {
    var sum = b[row];
    for (var k = row + 1; k < n; k++) {
      sum -= a[row][k] * x[k];
    }
    x[row] = sum / a[row][row];
  }
  return x;
}
