// Test matematika homografi untuk warp video-on-marker.
//
// Bagian paling riskan dari fitur ini adalah kalkulasinya (tidak bisa diuji
// langsung tanpa perangkat AR), jadi dipastikan dulu di sini:
// - homografi identity (src == dst) tidak mengubah titik,
// - pemetaan persegi panjang -> quad miring tetap memetakan sudut dengan benar,
// - computeVideoQuad mem-fitz video di dalam marker tanpa gepeng,
// - videoWarpMatrix menolak quad liar (nyaris sejajar).

import 'dart:ui';

import 'package:astorya/modules/ar/utils/marker_homography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('solveHomography', () {
    test('identity: src == dst mengembalikan titik yang sama', () {
      const src = [
        Offset(0, 0),
        Offset(100, 0),
        Offset(100, 50),
        Offset(0, 50),
      ];
      final m = solveHomography(src, src);
      expect(m, isNotNull);

      for (final p in src) {
        final out = applyHomography(m!, p);
        expect(out.dx, closeTo(p.dx, 1e-6));
        expect(out.dy, closeTo(p.dy, 1e-6));
      }
    });

    test('skala + translasi dipetakan persis', () {
      const src = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(10, 10),
        Offset(0, 10),
      ];
      // Skala 3x lalu geser (50, 70).
      const dst = [
        Offset(50, 70),
        Offset(80, 70),
        Offset(80, 100),
        Offset(50, 100),
      ];
      final m = solveHomography(src, dst);
      expect(m, isNotNull);

      final center = applyHomography(m!, const Offset(5, 5));
      expect(center.dx, closeTo(65, 1e-6));
      expect(center.dy, closeTo(85, 1e-6));
    });

    test('quad miring (perspektif) memetakan 4 sudut dengan benar', () {
      const src = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      // Unit square -> quad trapesium (seperti marker dilihat dari samping).
      const dst = [
        Offset(100, 50),
        Offset(300, 80),
        Offset(320, 300),
        Offset(80, 260),
      ];
      final m = solveHomography(src, dst);
      expect(m, isNotNull);

      for (var i = 0; i < 4; i++) {
        final out = applyHomography(m!, src[i]);
        expect(out.dx, closeTo(dst[i].dx, 1e-6));
        expect(out.dy, closeTo(dst[i].dy, 1e-6));
      }
    });

    test('titik tengah unit square terpetakan ke tengah quad proyektif', () {
      const src = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      const dst = [
        Offset(100, 50),
        Offset(300, 80),
        Offset(320, 300),
        Offset(80, 260),
      ];
      final m = solveHomography(src, dst)!;
      final center = applyHomography(m, const Offset(0.5, 0.5));

      // Bukan rata-rata linear (itu berarti affine), tapi harus berada di
      // dalam quad dan condong ke sisi yang lebih "dekat" (atas, lebih sempit).
      expect(center.dx, greaterThan(100));
      expect(center.dx, lessThan(320));
      expect(center.dy, greaterThan(50));
      expect(center.dy, lessThan(300));
      // Karena bagian atas lebih sempit, pusatnya lebih dekat ke atas.
      expect(center.dy, lessThan(175));
    });
  });

  group('computeVideoQuad', () {
    test('video 16:9 di marker persegi menghasilkan letterbox tepat', () {
      // Marker 20x20 cm (persegi), video 16:9.
      final quad = computeVideoQuad(
        markerCorners: const [
          0.2, 0.2, // TL
          0.8, 0.2, // TR
          0.8, 0.8, // BR
          0.2, 0.8, // BL
        ],
        canvasSize: const Size(1000, 1000),
        markerAspect: 1,
        videoAspect: 16 / 9,
      );
      expect(quad, isNotNull);

      // Marker di layar: x 200..800 (lebar 600), y 200..800 (tinggi 600).
      // Video 16:9 fit lebar penuh, tinggi = 600 * 9/16 = 337.5, terpusat.
      final tl = quad![0];
      final br = quad[2];
      expect(tl.dx, closeTo(200, 1e-6));
      expect(br.dx, closeTo(800, 1e-6));
      final videoHeight = br.dy - tl.dy;
      expect(videoHeight, closeTo(600 * 9 / 16, 1e-6));
      // Vertikal terpusat di dalam marker.
      expect((tl.dy + br.dy) / 2, closeTo(500, 1e-6));
      // Tidak ada gepeng: rasio quad sama dengan rasio video.
      expect((br.dx - tl.dx) / videoHeight, closeTo(16 / 9, 1e-6));
    });

    test('video potret di marker lanskap mem-fitz tinggi penuh', () {
      final quad = computeVideoQuad(
        // Marker 2:1 di layar: 800x400 piksel (searah rasio fisiknya).
        markerCorners: const [
          0.1, 0.3, // TL
          0.9, 0.3, // TR
          0.9, 0.7, // BR
          0.1, 0.7, // BL
        ],
        canvasSize: const Size(1000, 1000),
        markerAspect: 2, // marker lanskap 2:1
        videoAspect: 9 / 16, // video potret
      );
      expect(quad, isNotNull);

      // Video fit tinggi penuh (400), lebar = 400 * 9/16 = 225, terpusat
      // horizontal di tengah marker (x 100..900 -> tengah 500).
      final tl = quad![0];
      final br = quad[2];
      expect(br.dy - tl.dy, closeTo(400, 1e-6));
      expect(br.dx - tl.dx, closeTo(400 * 9 / 16, 1e-6));
      expect((tl.dx + br.dx) / 2, closeTo(500, 1e-6));
    });

    test('input tidak valid mengembalikan null', () {
      expect(
        computeVideoQuad(
          markerCorners: const [0, 0, 1, 0, 1, 1], // kurang dari 8
          canvasSize: const Size(100, 100),
          markerAspect: 1,
          videoAspect: 1,
        ),
        isNull,
      );
      expect(
        computeVideoQuad(
          markerCorners: const [0, 0, 1, 0, 1, 1, 0, 1],
          canvasSize: Size.zero,
          markerAspect: 1,
          videoAspect: 1,
        ),
        isNull,
      );
      expect(
        computeVideoQuad(
          markerCorners: const [0, 0, 1, 0, 1, 1, 0, 1],
          canvasSize: const Size(100, 100),
          markerAspect: 0,
          videoAspect: 1,
        ),
        isNull,
      );
    });
  });

  group('videoWarpMatrix', () {
    test('quad = rect sumber menghasilkan matriks identitas', () {
      const srcSize = Size(200, 100);
      final m = videoWarpMatrix(
        srcSize: srcSize,
        quad: const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ],
      );
      expect(m, isNotNull);
      final out = applyHomography(m!, const Offset(37, 23));
      expect(out.dx, closeTo(37, 1e-6));
      expect(out.dy, closeTo(23, 1e-6));
    });

    test('menolak quad liar (meledak / tak terhingga)', () {
      // Quad dengan w mendekati nol: sudut nyaris sejajar garis pandang.
      const srcSize = Size(200, 100);
      final m = videoWarpMatrix(
        srcSize: srcSize,
        quad: const [
          Offset(0, 0),
          Offset(100000, 0),
          Offset(-100000, 100),
          Offset(0, 100),
        ],
      );
      // Boleh null (ditolak), tapi kalau tidak null hasilnya harus finite.
      if (m != null) {
        final out = applyHomography(m, const Offset(100, 50));
        expect(out.dx.isFinite, isTrue);
        expect(out.dy.isFinite, isTrue);
      }
    });

    test('matriks warp memetakan 4 sudut sumber ke quad persis', () {
      const srcSize = Size(300, 169);
      const quad = [
        Offset(120, 240),
        Offset(760, 200),
        Offset(800, 810),
        Offset(90, 770),
      ];
      final m = videoWarpMatrix(srcSize: srcSize, quad: quad);
      expect(m, isNotNull);

      final srcCorners = [
        Offset.zero,
        Offset(srcSize.width, 0),
        Offset(srcSize.width, srcSize.height),
        Offset(0, srcSize.height),
      ];
      for (var i = 0; i < 4; i++) {
        final out = applyHomography(m!, srcCorners[i]);
        expect(out.dx, closeTo(quad[i].dx, 1e-4));
        expect(out.dy, closeTo(quad[i].dy, 1e-4));
      }
    });
  });
}
