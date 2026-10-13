import 'package:flutter/material.dart';

/// Panel slider volume (0% - 100%) yang muncul di bawah control bar.
///
/// Bersifat presentational sepenuhnya: nilai & perubahan dikendalikan oleh
/// [AstoryaArHud] lewat callback.
class ArVolumePopup extends StatelessWidget {
  const ArVolumePopup({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;

  /// Nilai 0.0 - 1.0.
  final double value;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0).toDouble();
    final percent = (safeValue * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: const Color(0xF20B0E1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: safeValue,
            min: 0,
            max: 1,
            divisions: 100,
            label: '$percent%',
            activeColor: const Color(0xFF7B4BFF),
            inactiveColor: const Color(0x33FFFFFF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
