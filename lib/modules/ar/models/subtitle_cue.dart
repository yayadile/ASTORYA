/// Bahasa subtitle yang didukung modul AR ASTORYA.
enum SubtitleLanguage {
  id('ID'),
  en('EN');

  const SubtitleLanguage(this.code);

  /// Kode singkat yang ditampilkan pada dropdown control bar.
  final String code;

  /// Helper parsing: nilai selain 'EN' dianggap Indonesia.
  static SubtitleLanguage fromCode(String code) =>
      code.trim().toUpperCase() == 'EN' ? SubtitleLanguage.en : SubtitleLanguage.id;
}

/// Satu potongan subtitle yang di-sync ke timestamp Voiceover.
///
/// [start] dan [end] dalam **detik** relatif ke awal pemutaran Voiceover,
/// sehingga tetap akurat walau user pause / seek.
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.id,
    required this.en,
  });

  /// Detik mulai (inklusif).
  final double start;

  /// Detik selesai (eksklusif).
  final double end;

  /// Teks bahasa Indonesia.
  final String id;

  /// Teks bahasa Inggris.
  final String en;

  /// True bila [seconds] berada di dalam rentang cue ini.
  bool contains(double seconds) => seconds >= start && seconds < end;

  /// Ambil teks sesuai [language].
  String text(SubtitleLanguage language) =>
      language == SubtitleLanguage.id ? id : en;

  @override
  String toString() => 'SubtitleCue($start-$end, id: $id, en: $en)';
}
