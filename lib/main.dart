import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';

/// Set to true at build time to skip Splash and preview Home directly:
///   flutter run -d chrome --dart-define=ASTORYA_PREVIEW_HOME=true
const bool _previewHome = bool.fromEnvironment(
  'ASTORYA_PREVIEW_HOME',
  defaultValue: false,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstoryaApp());
}

class AstoryaApp extends StatelessWidget {
  const AstoryaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASTORYA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B4BFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
        useMaterial3: true,
      ),
      home: _previewHome ? const HomeScreen() : const SplashScreen(),
    );
  }
}
