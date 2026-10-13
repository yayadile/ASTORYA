import 'package:flutter/material.dart';

import '../controllers/astorya_ar_controller.dart';
import '../models/subtitle_cue.dart';
import 'ar_volume_popup.dart';

/// Popup volume yang sedang terbuka pada control bar.
enum ArControlPopup { none, voiceover, bgm }

/// Floating control bar di bagian atas layar AR.
///
/// Berisi: play/pause, tombol volume Voiceover, tombol volume BGM,
/// dropdown bahasa subtitle, dan (opsional) tombol tutup.
///
/// Bersifat **presentational** - semua state dan aksi di-inject lewat
/// parameter, sehingga widget ini bisa dipakai ulang di layar mana pun.
class ArControlBar extends StatelessWidget {
  const ArControlBar({
    super.key,
    required this.state,
    required this.voiceoverVolume,
    required this.bgmVolume,
    required this.language,
    required this.activePopup,
    required this.onActivePopupChanged,
    required this.onTogglePlay,
    required this.onVoiceoverVolumeChanged,
    required this.onBgmVolumeChanged,
    required this.onLanguageChanged,
    this.onClose,
  });

  final ArStoryState state;
  final double voiceoverVolume;
  final double bgmVolume;
  final SubtitleLanguage language;
  final ArControlPopup activePopup;

  final ValueChanged<ArControlPopup> onActivePopupChanged;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onVoiceoverVolumeChanged;
  final ValueChanged<double> onBgmVolumeChanged;
  final ValueChanged<SubtitleLanguage> onLanguageChanged;

  /// Tombol tutup. Bila `null`, tombol tidak ditampilkan
  /// (mis. saat modul di-embed, bukan di-push).
  final VoidCallback? onClose;

  bool get _isPlaying => state == ArStoryState.playing;

  void _openPopup(ArControlPopup target) {
    onActivePopupChanged(
      activePopup == target ? ArControlPopup.none : target,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ------------------------------------------------------------- BAR --
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF20B0E1A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIconButton(
                icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: _isPlaying ? 'Jeda' : 'Putar',
                onTap: () {
                  onActivePopupChanged(ArControlPopup.none);
                  onTogglePlay();
                },
              ),
              const SizedBox(width: 4),
              _CircleIconButton(
                icon: Icons.record_voice_over_rounded,
                tooltip: 'Volume Voiceover',
                active: activePopup == ArControlPopup.voiceover,
                onTap: () => _openPopup(ArControlPopup.voiceover),
              ),
              const SizedBox(width: 4),
              _CircleIconButton(
                icon: Icons.music_note_rounded,
                tooltip: 'Volume BGM',
                active: activePopup == ArControlPopup.bgm,
                onTap: () => _openPopup(ArControlPopup.bgm),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 22,
                color: const Color(0x33FFFFFF),
              ),
              const SizedBox(width: 6),
              _LanguageDropdown(
                value: language,
                onChanged: (lang) {
                  onActivePopupChanged(ArControlPopup.none);
                  onLanguageChanged(lang);
                },
              ),
              if (onClose != null) ...[
                const SizedBox(width: 2),
                _CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Tutup',
                  onTap: () {
                    onActivePopupChanged(ArControlPopup.none);
                    onClose!();
                  },
                ),
              ],
            ],
          ),
        ),

        // ---------------------------------------------------------- POPUP --
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: activePopup == ArControlPopup.none
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: activePopup == ArControlPopup.voiceover
                      ? ArVolumePopup(
                          icon: Icons.record_voice_over_rounded,
                          title: 'Volume Voiceover',
                          value: voiceoverVolume,
                          onChanged: onVoiceoverVolumeChanged,
                        )
                      : ArVolumePopup(
                          icon: Icons.music_note_rounded,
                          title: 'Volume BGM',
                          value: bgmVolume,
                          onChanged: onBgmVolumeChanged,
                        ),
                ),
        ),
      ],
    );
  }
}

/// Tombol ikon bulat pada control bar.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget child = Material(
      color: active ? const Color(0xFF7B4BFF) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

/// Dropdown pemilih bahasa subtitle ("ID" / "EN").
class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.value, required this.onChanged});

  final SubtitleLanguage value;
  final ValueChanged<SubtitleLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SubtitleLanguage>(
        value: value,
        isDense: true,
        dropdownColor: const Color(0xFF141830),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white70,
          size: 20,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        items: SubtitleLanguage.values
            .map(
              (lang) => DropdownMenuItem<SubtitleLanguage>(
                value: lang,
                child: Text(lang.code),
              ),
            )
            .toList(),
        onChanged: (lang) {
          if (lang != null) onChanged(lang);
        },
      ),
    );
  }
}
