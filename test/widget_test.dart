// Smoke test sederhana: pastikan aplikasi ASTORYA bisa di-build dan halaman
// daftar cerita menampilkan kartu-kartu ceritanya.

import 'package:flutter_test/flutter_test.dart';

import 'package:astorya/main.dart';

void main() {
  testWidgets('AstoryaApp menampilkan daftar cerita', (WidgetTester tester) async {
    await tester.pumpWidget(const AstoryaApp());

    // Judul utama tampil.
    expect(find.text('ASTORYA'), findsWidgets);

    // Kartu cerita contoh tampil.
    expect(find.text('Video + Audio'), findsOneWidget);
    expect(find.text('Video Saja (Tanpa Audio)'), findsOneWidget);
    expect(find.text('Model 3D'), findsOneWidget);
  });
}
