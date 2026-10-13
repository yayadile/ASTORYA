import 'package:flutter/material.dart';

import '../models/subtitle_cue.dart';

/// Floating subtitle di bagian bawah layar AR.
///
/// Tampil/animasi fade berdasarkan cue yang diberikan; bila [text] `null`
/// maka subtitle disembunyikan.
class ArSubtitleOverlay extends StatelessWidget {
  const ArSubtitleOverlay({
    super.key,
    required this.text,
    required this.language,
  });

  /// Teks yang sedang aktif, atau `null` untuk menyembunyikan subtitle.
  final String? text;

  /// Bahasa terpilih - dipakai sebagai bagian key agar ganti bahasa
  /// memicu animasi fade yang memberi feedback visual ke user.
  final SubtitleLanguage language;

  @override
  Widget build(BuildContext context) {
    final visible = text != null && text!.isNotEmpty;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: visible
              ? Container(
                  key: ValueKey<String>('subtitle-${language.code}'),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xF20B0E1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    text!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey<String>('subtitle-none')),
        ),
      ),
    );
  }
}
