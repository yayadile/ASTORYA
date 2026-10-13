import 'package:flutter/material.dart';

import 'features/story/story_list_page.dart';

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
      home: const StoryListPage(),
    );
  }
}
